// Supabase Edge Function for Receipt Data Extraction
// Using Google Gemini Pro Vision for intelligent structured extraction
// Supports both single image (backward compatible) and multi-image batch processing
// Deploy: supabase functions deploy extract-receipt-data --project-ref bnkpaikzslmwdcdmonoa --no-verify-jwt

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// CORS headers for cross-origin requests
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Rate limit delay between API calls (milliseconds)
const RATE_LIMIT_DELAY_MS = 1000

// Similarity threshold for item deduplication (80%)
const SIMILARITY_THRESHOLD = 0.8

// Request body types
interface RequestBody {
    image?: string        // Legacy single image (backward compatible)
    images?: string[]     // NEW: Multiple images for batch processing
}

// Structured response types
interface ExtractedItem {
    name: string
    quantity: number
    price: number
    sourcePageIndex?: number  // NEW: Tracks which page the item came from
}

interface Fee {
    type: string
    amount: number
}

interface ReceiptData {
    items: ExtractedItem[]
    fees: Fee[]
    subtotal: number | null
    total: number | null
    storeName: string | null
    receiptDateISO?: string | null
    rawText?: string
    warnings?: string[]  // NEW: Partial failure warnings
}

// Result from processing a single image
interface SingleImageResult {
    success: boolean
    data?: ReceiptData
    error?: string
    pageIndex: number
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Parse JSON request body
        const body: RequestBody = await req.json()
        const { image, images } = body

        // Validate input
        if (!image && (!images || images.length === 0)) {
            return new Response(
                JSON.stringify({ error: 'No image provided. Supply either "image" (string) or "images" (string[])' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        let receiptData: ReceiptData

        if (images && images.length > 0) {
            // NEW: Multi-image batch processing
            console.log(`Processing ${images.length} images in batch mode`)
            receiptData = await processMultipleImages(images)
        } else if (image) {
            // Legacy: Single image processing (backward compatible)
            receiptData = await extractReceiptData(image)
        } else {
            throw new Error('Invalid request body')
        }

        // Return structured receipt data
        return new Response(
            JSON.stringify(receiptData),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error: unknown) {
        const errorMessage = error instanceof Error ? error.message : 'Receipt extraction failed'
        console.error('Receipt Extraction Error:', error)

        // Surface upstream rate limits as 429 so the iOS retry path can back off
        // properly instead of treating it like a generic outage.
        const upstreamStatus = (error as Error & { upstreamStatus?: number }).upstreamStatus
        const status = upstreamStatus === 429 ? 429 : 500

        return new Response(
            JSON.stringify({ error: errorMessage }),
            { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})

// Main extraction function
async function extractReceiptData(base64Image: string): Promise<ReceiptData> {
    const geminiApiKey = Deno.env.get('GOOGLE_GEMINI_API_KEY')

    if (geminiApiKey) {
        return await callGeminiVision(base64Image, geminiApiKey)
    }

    // Fallback to legacy Vision API if Gemini key not set
    const visionApiKey = Deno.env.get('GOOGLE_VISION_API_KEY')
    if (visionApiKey) {
        console.warn('Using legacy Vision API - consider switching to Gemini for better accuracy')
        return await callLegacyVisionAPI(base64Image, visionApiKey)
    }

    // Fallback: Return mock data for testing
    console.warn('No API key configured, returning mock data')
    return getMockReceiptData()
}

// Google Gemini Pro Vision API - Intelligent structured extraction
async function callGeminiVision(base64Image: string, apiKey: string): Promise<ReceiptData> {
    const prompt = `Analyze this receipt or shopping cart image. Extract ONLY the actual purchased items.

CRITICAL RULES:
1. Include ONLY products being purchased (food items, goods, etc.)
2. Use the FINAL/CURRENT price (ignore crossed-out/original prices)
3. The "price" field MUST be the LINE TOTAL shown on the receipt for that item
   - Example: If receipt shows "2 x $7.05 = $14.10", return price: 14.10 (NOT 7.05)
   - Example: If receipt shows "SWAD MALAYSIAN  14.10", return price: 14.10
   - The price is ALWAYS the final amount the customer pays for that line, regardless of quantity
4. PROMOTIONAL DISCOUNTS = SUBTRACT FROM PRICE: If a line shows "promo", "discount",
   "save", "off", "BOGO", "X for $Y", or any per-quantity price reduction, SUBTRACT
   the discount from the listed price BEFORE computing the line total.
   - Apply discount per unit, then multiply by quantity for the final price.
   - Example A: "SWAD MALAYSIAN  $8.99  promo $2 per qty" with quantity 2
     -> effective unit price = 8.99 - 2.00 = 6.99
     -> return { quantity: 2, price: 13.98 }   (NOT 8.99, NOT 17.98)
   - Example B: "MILK 2%  $5.00  $1 off each" with quantity 3
     -> effective unit price = 4.00
     -> return { quantity: 3, price: 12.00 }
   - Example C: "BOGO" / "Buy 1 Get 1 Free" at $10 each with quantity 2
     -> effective total = $10.00 (one is free)
     -> return { quantity: 2, price: 10.00 }
   - Do NOT add the promotion as a separate item or as an entry in "fees".
     The discount is already baked into the price field.
5. EXCLUDE all UI elements (buttons, "Remove", "Save for later", navigation)
6. EXCLUDE promotional banners and marketing text (the BANNER, not the per-line discount handled in rule 4)
7. EXCLUDE dates, order numbers, and metadata unless it's the store name
8. Identify delivery fees, service fees, tips separately from items
9. Identify subtotal and total amounts
10. If a receipt date is visible, return it as ISO-8601 in receiptDateISO

Return ONLY valid JSON in this exact format (no markdown, no explanation):
{
  "items": [{"name": "Product Name", "quantity": 1, "price": 10.99}],
  "fees": [{"type": "delivery", "amount": 4.95}],
  "subtotal": 24.97,
  "total": 29.92,
  "storeName": "Store Name or null",
  "receiptDateISO": "2026-01-15T19:30:00Z or null"
}

IMPORTANT: "price" = total amount for that line item (what customer pays), NOT per-unit price.

If you cannot identify any items, return: {"items": [], "fees": [], "subtotal": null, "total": null, "storeName": null, "receiptDateISO": null}`

    // Model fallback order (April 2026): try the fastest GA model first,
    // then the more accurate Pro tier, then legacy 2.0 as a last resort.
    // Gemini 2.5 Flash is GA and Vision-capable; 2.0 is being throttled.
    const models = [
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'gemini-2.0-flash'
    ]

    // Track whether we hit upstream rate limits so we can surface a 429 to the client
    // instead of a generic 500.
    let sawRateLimit = false

    for (const model of models) {
        try {
            console.log(`Trying model: ${model}`)

            const response = await fetch(
                `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        contents: [{
                            parts: [
                                { text: prompt },
                                {
                                    inline_data: {
                                        mime_type: "image/jpeg",
                                        data: base64Image
                                    }
                                }
                            ]
                        }],
                        generationConfig: {
                            temperature: 0.1,
                            // 1024 was truncating JSON for receipts with many items, which
                            // caused JSON.parse to throw and the request to bubble up as 500.
                            // 2048 gives headroom for ~25 line items + fees + totals.
                            maxOutputTokens: 2048,
                            // Force strict JSON output so Gemini does not wrap the payload
                            // in markdown fences or commentary.
                            responseMimeType: "application/json"
                        }
                    })
                }
            )

            if (!response.ok) {
                const errorText = await response.text()
                console.error(`Model ${model} failed:`, response.status, errorText)
                if (response.status === 429) {
                    sawRateLimit = true
                }
                continue // Try next model
            }

            const result = await response.json()
            const generatedText = result.candidates?.[0]?.content?.parts?.[0]?.text

            if (!generatedText) {
                console.error(`Model ${model} returned no text`)
                continue
            }

            console.log(`Model ${model} succeeded, parsing response...`)

            // Clean up the response (remove markdown code blocks if present)
            let cleanedText = generatedText.trim()
            if (cleanedText.startsWith('```json')) {
                cleanedText = cleanedText.slice(7)
            }
            if (cleanedText.startsWith('```')) {
                cleanedText = cleanedText.slice(3)
            }
            if (cleanedText.endsWith('```')) {
                cleanedText = cleanedText.slice(0, -3)
            }
            cleanedText = cleanedText.trim()

            const parsed = JSON.parse(cleanedText) as ReceiptData

            // Validate and sanitize the response
            return {
                items: Array.isArray(parsed.items) ? parsed.items.map(item => ({
                    name: String(item.name || ''),
                    quantity: Number(item.quantity) || 1,
                    price: Number(item.price) || 0
                })) : [],
                fees: Array.isArray(parsed.fees) ? parsed.fees.map(fee => ({
                    type: String(fee.type || 'other'),
                    amount: Number(fee.amount) || 0
                })) : [],
                subtotal: parsed.subtotal ? Number(parsed.subtotal) : null,
                total: parsed.total ? Number(parsed.total) : null,
                storeName: parsed.storeName || null,
                receiptDateISO: typeof parsed.receiptDateISO === 'string' ? parsed.receiptDateISO : null
            }

        } catch (err) {
            console.error(`Error with model ${model}:`, err)
            continue
        }
    }

    if (sawRateLimit) {
        // Throw a typed error so the top-level handler can return 429 instead of 500.
        const err = new Error('All Gemini models hit rate limits. Try again in a few seconds.') as Error & { upstreamStatus?: number }
        err.upstreamStatus = 429
        throw err
    }
    throw new Error('All Gemini models failed. Check your API key and ensure Generative Language API is enabled.')
}

// Legacy Google Cloud Vision API (fallback)
async function callLegacyVisionAPI(base64Image: string, apiKey: string): Promise<ReceiptData> {
    const response = await fetch(
        `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`,
        {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                requests: [{
                    image: { content: base64Image },
                    features: [{ type: 'TEXT_DETECTION', maxResults: 1 }]
                }]
            })
        }
    )

    const result = await response.json()
    const rawText = result.responses?.[0]?.textAnnotations?.[0]?.description || ''

    if (!rawText) {
        throw new Error('No text detected in image')
    }

    return {
        items: [],
        fees: [],
        subtotal: null,
        total: null,
        storeName: null,
        receiptDateISO: null,
        rawText: rawText
    }
}

// Mock receipt data for testing
function getMockReceiptData(): ReceiptData {
    return {
        items: [
            { name: "Caesar Salad", quantity: 1, price: 12.99 },
            { name: "Burger", quantity: 2, price: 15.99 },
            { name: "Pizza Large", quantity: 1, price: 24.99 },
            { name: "Coke", quantity: 3, price: 2.99 },
            { name: "Fries", quantity: 2, price: 4.99 }
        ],
        fees: [
            { type: "tax", amount: 4.01 }
        ],
        subtotal: 61.95,
        total: 65.96,
        storeName: "WALMART SUPERCENTER",
        receiptDateISO: null
    }
}

// =============================================================================
// MULTI-IMAGE PROCESSING
// =============================================================================

/**
 * Processes multiple receipt images sequentially, merges results, and handles partial failures
 * @param images - Array of base64-encoded images
 * @returns Merged ReceiptData with items from all pages
 */
async function processMultipleImages(images: string[]): Promise<ReceiptData> {
    const results: SingleImageResult[] = []
    const warnings: string[] = []

    // Process each image sequentially with rate limiting
    for (let i = 0; i < images.length; i++) {
        // Add rate limit delay between API calls (skip first image)
        if (i > 0) {
            await sleep(RATE_LIMIT_DELAY_MS)
        }

        console.log(`Processing image ${i + 1}/${images.length}`)

        try {
            const data = await extractReceiptData(images[i])
            
            // Add sourcePageIndex to each item
            const itemsWithSource: ExtractedItem[] = data.items.map(item => ({
                ...item,
                sourcePageIndex: i
            }))
            
            results.push({
                success: true,
                data: { ...data, items: itemsWithSource },
                pageIndex: i
            })
        } catch (error: unknown) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown error'
            console.error(`Page ${i + 1} failed:`, errorMessage)
            
            warnings.push(`Page ${i + 1} failed: ${errorMessage}`)
            results.push({
                success: false,
                error: errorMessage,
                pageIndex: i
            })
        }
    }

    // Check if ALL images failed
    const successfulResults = results.filter(r => r.success && r.data)
    if (successfulResults.length === 0) {
        throw new Error(`All ${images.length} images failed to process. ${warnings.join('; ')}`)
    }

    // Merge successful results
    return mergeReceiptData(successfulResults, warnings)
}

/**
 * Merges receipt data from multiple pages into a single result
 * @param results - Array of successful processing results
 * @param warnings - Array of warning messages from failed pages
 * @returns Merged ReceiptData
 */
function mergeReceiptData(results: SingleImageResult[], warnings: string[]): ReceiptData {
    let allItems: ExtractedItem[] = []
    let allFees: Fee[] = []
    let storeName: string | null = null
    let subtotal: number | null = null
    let total: number | null = null
    let receiptDateISO: string | null = null
    let rawTexts: string[] = []

    for (const result of results) {
        if (!result.success || !result.data) continue

        const data = result.data

        // Collect all items (already have sourcePageIndex)
        allItems.push(...data.items)

        // Collect all fees (will deduplicate later)
        allFees.push(...data.fees)

        // Use first non-null store name
        if (storeName === null && data.storeName) {
            storeName = data.storeName
        }

        // Use first non-null receipt date
        if (receiptDateISO === null && data.receiptDateISO) {
            receiptDateISO = data.receiptDateISO
        }

        // Use last non-null total (receipt totals typically on last page)
        if (data.total !== null) {
            total = data.total
        }

        // Use last non-null subtotal
        if (data.subtotal !== null) {
            subtotal = data.subtotal
        }

        // Collect raw text if present
        if (data.rawText) {
            rawTexts.push(data.rawText)
        }
    }

    // Deduplicate items using Levenshtein similarity
    const deduplicatedItems = deduplicateItems(allItems)

    // Deduplicate fees by type (keep highest amount)
    const deduplicatedFees = deduplicateFees(allFees)

    // Build final result
    const mergedData: ReceiptData = {
        items: deduplicatedItems,
        fees: deduplicatedFees,
        subtotal,
        total,
        storeName,
        receiptDateISO,
    }

    // Add raw text if present
    if (rawTexts.length > 0) {
        mergedData.rawText = rawTexts.join('\n\n--- Page Break ---\n\n')
    }

    // Add warnings if any pages failed
    if (warnings.length > 0) {
        mergedData.warnings = warnings
    }

    return mergedData
}

// =============================================================================
// DEDUPLICATION FUNCTIONS
// =============================================================================

/**
 * Deduplicates items using Levenshtein distance for name similarity
 * Items with >80% name similarity are considered duplicates
 * @param items - Array of extracted items (may contain duplicates)
 * @returns Deduplicated array keeping items with higher prices
 */
function deduplicateItems(items: ExtractedItem[]): ExtractedItem[] {
    if (items.length <= 1) return items

    const uniqueItems: ExtractedItem[] = []
    const processedIndices = new Set<number>()

    for (let i = 0; i < items.length; i++) {
        if (processedIndices.has(i)) continue

        let bestItem = items[i]
        processedIndices.add(i)

        // Look for duplicates in remaining items
        for (let j = i + 1; j < items.length; j++) {
            if (processedIndices.has(j)) continue

            const similarity = calculateSimilarity(items[i].name, items[j].name)

            if (similarity > SIMILARITY_THRESHOLD) {
                // Mark as duplicate
                processedIndices.add(j)

                // Keep the one with higher price (more complete line item)
                if (items[j].price > bestItem.price) {
                    bestItem = items[j]
                }
            }
        }

        uniqueItems.push(bestItem)
    }

    return uniqueItems
}

/**
 * Deduplicates fees by type, keeping the highest amount for each type
 * @param fees - Array of fees (may contain duplicates)
 * @returns Deduplicated array with one fee per type
 */
function deduplicateFees(fees: Fee[]): Fee[] {
    const feesByType = new Map<string, Fee>()

    for (const fee of fees) {
        const key = fee.type.toLowerCase()
        const existing = feesByType.get(key)

        if (!existing || fee.amount > existing.amount) {
            feesByType.set(key, fee)
        }
    }

    return Array.from(feesByType.values())
}

/**
 * Calculates similarity between two strings (0.0 to 1.0) using Levenshtein distance
 * @param s1 - First string
 * @param s2 - Second string
 * @returns Similarity ratio (1.0 = identical, 0.0 = completely different)
 */
function calculateSimilarity(s1: string, s2: string): number {
    const str1 = s1.toLowerCase().trim()
    const str2 = s2.toLowerCase().trim()

    // Exact match
    if (str1 === str2) return 1.0

    // Empty string handling
    if (str1.length === 0 || str2.length === 0) return 0.0

    const distance = levenshteinDistance(str1, str2)
    const maxLength = Math.max(str1.length, str2.length)

    return 1.0 - (distance / maxLength)
}

/**
 * Calculates Levenshtein (edit) distance between two strings
 * @param s1 - First string
 * @param s2 - Second string
 * @returns Number of single-character edits needed to transform s1 into s2
 */
function levenshteinDistance(s1: string, s2: string): number {
    const m = s1.length
    const n = s2.length

    if (m === 0) return n
    if (n === 0) return m

    // Create distance matrix
    const matrix: number[][] = []
    
    for (let i = 0; i <= m; i++) {
        matrix[i] = [i]
    }
    
    for (let j = 0; j <= n; j++) {
        matrix[0][j] = j
    }

    // Fill in the rest of the matrix
    for (let i = 1; i <= m; i++) {
        for (let j = 1; j <= n; j++) {
            const cost = s1[i - 1] === s2[j - 1] ? 0 : 1
            matrix[i][j] = Math.min(
                matrix[i - 1][j] + 1,      // deletion
                matrix[i][j - 1] + 1,      // insertion
                matrix[i - 1][j - 1] + cost // substitution
            )
        }
    }

    return matrix[m][n]
}

/**
 * Helper function to sleep for specified milliseconds
 * @param ms - Milliseconds to sleep
 */
function sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms))
}

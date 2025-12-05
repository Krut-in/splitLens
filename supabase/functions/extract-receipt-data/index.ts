// Supabase Edge Function for Receipt Data Extraction
// Using Google Gemini Pro Vision for intelligent structured extraction
// Deploy: supabase functions deploy extract-receipt-data --project-ref bnkpaikzslmwdcdmonoa --no-verify-jwt

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// CORS headers for cross-origin requests
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Structured response types
interface ExtractedItem {
    name: string
    quantity: number
    price: number
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
    rawText?: string
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Parse JSON request body
        const { image } = await req.json()

        if (!image) {
            return new Response(
                JSON.stringify({ error: 'No image provided' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Process with Gemini Vision API
        const receiptData = await extractReceiptData(image)

        // Return structured receipt data
        return new Response(
            JSON.stringify(receiptData),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error: any) {
        console.error('Receipt Extraction Error:', error)
        return new Response(
            JSON.stringify({ error: error.message || 'Receipt extraction failed' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
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
3. EXCLUDE all UI elements (buttons, "Remove", "Save for later", navigation)
4. EXCLUDE promotional banners and marketing text
5. EXCLUDE dates, order numbers, and metadata unless it's the store name
6. Identify delivery fees, service fees, tips separately from items
7. Identify subtotal and total amounts

Return ONLY valid JSON in this exact format (no markdown, no explanation):
{
  "items": [{"name": "Product Name", "quantity": 1, "price": 10.99}],
  "fees": [{"type": "delivery", "amount": 4.95}],
  "subtotal": 24.97,
  "total": 29.92,
  "storeName": "Store Name or null"
}

If you cannot identify any items, return: {"items": [], "fees": [], "subtotal": null, "total": null, "storeName": null}`

    // Use stable Gemini 2.0 Flash model (confirmed working)
    const models = [
        'gemini-2.0-flash',
        'gemini-2.5-flash'
    ]

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
                            maxOutputTokens: 1024
                        }
                    })
                }
            )

            if (!response.ok) {
                const errorText = await response.text()
                console.error(`Model ${model} failed:`, response.status, errorText)
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
                storeName: parsed.storeName || null
            }

        } catch (err) {
            console.error(`Error with model ${model}:`, err)
            continue
        }
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
        storeName: "WALMART SUPERCENTER"
    }
}

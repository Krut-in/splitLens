// Supabase Edge Function for OCR Processing
// Deploy this to: https://bnkpaikzslmwdcdmonoa.supabase.co/functions/v1/extract-receipt-data

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { decode as decodeBase64, encode as encodeBase64 } from "https://deno.land/std@0.168.0/encoding/base64.ts"

// CORS headers for cross-origin  requests
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

        // Convert base64 to binary
        const imageData = decodeBase64(image)

        // Call Google Cloud Vision API (or other OCR service)
        // For this example, we'll use a mock response
        // In production, replace this with actual OCR API call

        const ocrResult = await performOCR(imageData)

        // Return extracted text
        return new Response(
            JSON.stringify({ text: ocrResult }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('OCR Error:', error)
        return new Response(
            JSON.stringify({ error: error.message || 'OCR processing failed' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})

// OCR Processing Function
async function performOCR(imageData: Uint8Array): Promise<string> {
    // Option 1: Google Cloud Vision API (recommended)
    const visionApiKey = Deno.env.get('GOOGLE_VISION_API_KEY')

    if (visionApiKey) {
        return await callGoogleVisionAPI(imageData, visionApiKey)
    }

    // Option 2: Tesseract.js (lightweight, runs in Deno)
    // return await callTesseractOCR(imageData)

    // Option 3: OpenAI Vision API (most accurate)
    // return await callOpenAIVision(imageData)

    // Fallback: Return mock data for testing
    console.warn('No OCR API configured, returning mock data')
    return getMockReceiptText()
}

// Google Cloud Vision API Integration
async function callGoogleVisionAPI(imageData: Uint8Array, apiKey: string): Promise<string> {
    const base64Image = encodeBase64(imageData)

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

    if (result.responses && result.responses[0].textAnnotations) {
        return result.responses[0].textAnnotations[0].description || ''
    }

    throw new Error('No text detected in image')
}

// Mock receipt text for testing
function getMockReceiptText(): string {
    return `WALMART SUPERCENTER
Store #1234
123 Main St

Caesar Salad        $12.99
2x Burger           $15.99
Pizza Large         $24.99
QTY: 3 Coke         $2.99
Fries x2            $4.99

SUBTOTAL            $61.95
TAX                 $4.01
TOTAL               $65.96

Thank you for shopping!`
}

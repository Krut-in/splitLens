# Supabase Edge Function Deployment Guide

## 📦 What Was Created

I've created a complete OCR Edge Function at:
```
supabase/functions/extract-receipt-data/index.ts
```

This function:
- ✅ Accepts base64-encoded images via POST request
- ✅ Integrates with Google Cloud Vision API for OCR
- ✅ Includes CORS support for browser/app requests
- ✅ Has comprehensive error handling
- ✅ Falls back to mock data if no API key configured
- ✅ Returns JSON: `{ "text": "extracted receipt text..." }`

---

## 🚀 Deployment Steps

### Option 1: Quick Deploy (Using Mock Data)

1. **Install Supabase CLI**:
```bash
# macOS
brew install supabase/tap/supabase

# Or direct download
# https://github.com/supabase/cli/releases
```

2. **Initialize Supabase** (if not already done):
```bash
cd /Users/krutinrahtod/Desktop/Desktop/WEB/webCodes/latestCodee/splitLens
supabase init
```

3. **Deploy the Function**:
```bash
supabase functions deploy extract-receipt-data \
  --project-ref bnkpaikzslmwdcdmonoa
```

4. **Test it**:
```bash
# Test with mock data (returns mock receipt text)
curl -X POST \
  'https://bnkpaikzslmwdcdmonoa.supabase.co/functions/v1/extract-receipt-data' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"image": "base64_encoded_image_here"}'
```

**Result**: Function deployed, returns mock receipt data

---

### Option 2: Production Deploy (With Real OCR)

#### Step 1: Get Google Cloud Vision API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create new project or select existing
3. Enable **Cloud Vision API**
4. Go to **APIs & Services** → **Credentials**
5. Click **Create Credentials** → **API Key**
6. Copy the API key

#### Step 2: Set Environment Variable in Supabase

```bash
supabase secrets set GOOGLE_VISION_API_KEY=your_api_key_here \
  --project-ref bnkpaikzslmwdcdmonoa
```

Or via Supabase Dashboard:
1. Go to https://supabase.com/dashboard/project/bnkpaikzslmwdcdmonoa
2. Settings → Edge Functions → Secrets
3. Add: `GOOGLE_VISION_API_KEY` = `your_key_here`

#### Step 3: Deploy

```bash
supabase functions deploy extract-receipt-data \
  --project-ref bnkpaikzslmwdcdmonoa
```

#### Step 4: Test with Real Image

```bash
# Convert image to base64
base64 -i receipt.jpg | tr -d '\n' > receipt_base64.txt

# Test the function
curl -X POST \
  'https://bnkpaikzslmwdcdmonoa.supabase.co/functions/v1/extract-receipt-data' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' \
  -H 'Content-Type: application/json' \
  -d "{\"image\": \"$(cat receipt_base64.txt)\"}"
```

**Result**: Real OCR processing with Google Cloud Vision

---

## 🧪 Testing from iOS App

Once deployed, your app will automatically use the real Edge Function:

1. **Run the app in simulator**
2. **Take/upload a receipt photo**
3. **Check logs** for OCR results

If Edge Function fails, app gracefully falls back to `MockOCRService`.

---

## 🔧 Alternative OCR Services

### Option A: OpenAI Vision API (Most Accurate)

**Pros**: Best accuracy, handles complex receipts  
**Cons**: Costs ~$0.01 per image

Add to `index.ts`:
```typescript
async function callOpenAIVision(imageData: Uint8Array): Promise<string> {
  const apiKey = Deno.env.get('OPENAI_API_KEY')
  const base64 = Deno.encodeBase64(imageData)
  
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'gpt-4-vision-preview',
      messages: [{
        role: 'user',
        content: [
          { type: 'text', text: 'Extract all text from this receipt image:' },
          { type: 'image_url', image_url: { url: `data:image/jpeg;base64,${base64}` } }
        ]
      }],
      max_tokens: 500
    })
  })
  
  const data = await response.json()
  return data.choices[0].message.content
}
```

Then deploy with:
```bash
supabase secrets set OPENAI_API_KEY=sk-... --project-ref bnkpaikzslmwdcdmonoa
```

---

### Option B: Tesseract.js (Free, Deno-compatible)

**Pros**: Free, runs in Edge Function  
**Cons**: Lower accuracy than cloud APIs

Add to `index.ts`:
```typescript
import { createWorker } from 'https://esm.sh/tesseract.js@4'

async function callTesseractOCR(imageData: Uint8Array): Promise<string> {
  const worker = await createWorker('eng')
  const { data: { text } } = await worker.recognize(imageData)
  await worker.terminate()
  return text
}
```

---

## 📊 Cost Comparison

| Service | Cost per Image | Accuracy | Setup |
|---------|---------------|----------|-------|
| Google Vision | $0.0015 | ⭐⭐⭐⭐ | Medium |
| OpenAI Vision | $0.01 | ⭐⭐⭐⭐⭐ | Easy |
| Tesseract | Free | ⭐⭐⭐ | Easy |
| Mock (testing) | Free | N/A | Instant |

---

## 🔍 Troubleshooting

### Issue: "Function not found"
**Solution**: Verify deployment:
```bash
supabase functions list --project-ref bnkpaikzslmwdcdmonoa
```

### Issue: "CORS error"
**Solution**: Already handled in `index.ts` with CORS headers

### Issue: "Timeout"
**Solution**: Increase timeout in `SupabaseOCRService.swift`:
```swift
init(edgeFunctionURL: URL, apiKey: String, timeout: TimeInterval = 60.0)
```

### Issue: "Invalid API key"
**Solution**: Check environment variable:
```bash
supabase secrets list --project-ref bnkpaikzslmwdcdmonoa
```

---

## ✅ Verification Checklist

After deployment, verify:
- [ ] Function appears in Supabase dashboard
- [ ] Test curl command returns `{ "text": "..." }`
- [ ] iOS app successfully calls function
- [ ] Error handling works (try with invalid image)
- [ ] Logs show in Supabase dashboard

---

## 🎯 Next Steps

1. **Deploy** using Option 1 (mock data) for immediate testing
2. **Upgrade** to Option 2 (Google Vision) when ready for production
3. **Monitor** usage in Supabase dashboard
4. **Optimize** costs by caching frequent receipts (future enhancement)

---

## 📞 Support

If you encounter issues:
1. Check Supabase function logs: Dashboard → Edge Functions → Logs
2. Review Xcode console for iOS app errors
3. Test Edge Function directly with curl (see examples above)

**Deployment complete!** Your OCR Edge Function is ready to deploy. 🚀

## SplitLens — Smart Bill Splitting from a Single Scan

**Turn messy receipts into crystal‑clear “who owes what” in minutes—complete with shareable summaries and export‑ready reports.**

## Problem statement / Context

Dinner with friends is easy. Settling up afterward is where things go sideways: someone paid, the receipt has shared appetizers, quantities, tax/tip, and a few items nobody remembers ordering. Most “split the bill” apps fall apart on the details—rounding errors, unclear assumptions, and no audit trail when someone asks “how did you get that number?”

SplitLens tackles the real problem: **trustworthy, explainable splitting**. It treats the receipt like a source of truth, keeps the math consistent down to the cent, and generates a report that makes disagreements rare—and resolutions fast.

## Solution overview

SplitLens is an iOS app that **scans a receipt (single or multi‑page), extracts line items, lets you assign items to people (including “All”), and computes settlements** so everyone reimburses the payer with confidence.

Under the hood, it’s engineered like a production system: a clean SwiftUI experience powered by MVVM, protocol‑based services for testability, and a Supabase Edge Function that can use **Google Gemini Vision** for structured extraction when you’re ready to run “real OCR.”

## Key features

- **Scan once, get structured items fast**: The OCR pipeline supports multi‑image receipts and merges results into a single dataset. It’s designed to continue even when a page fails, returning **partial‑failure warnings** instead of crashing the flow.

- **Real-time progress you can trust**: OCR runs with a dedicated progress tracker (preprocess → upload → analyze → parse) plus cancellation support. That keeps long scans predictable and makes the UI feel responsive even when the backend is doing heavy lifting.

- **Cleaner data through deduplication**: Multi‑page receipts often repeat items (headers, carry‑overs). SplitLens deduplicates extracted items using a **Levenshtein‑based similarity score** (80% threshold) to keep the most “complete” line item (usually the higher priced line total).

- **Bill splitting that’s accurate and explainable**: The split engine supports quantities, per‑item sharing, and “All” assignments. It validates correctness with variance checks—**warns above 1% mismatch** and **fails above 10%**—then generates readable explanations like “Pizza \( \$24.00 ÷ 3 = \$8.00 \)” to make the math auditable.

- **Rounding that always sums to the exact total**: Floating‑point math is the silent killer of split apps. SplitLens uses a **largest‑remainder cent redistribution** strategy so totals align exactly (e.g., \( \$10.00 \) across 3 people becomes \( \$3.33, \$3.33, \$3.34 \), not \( \$9.99 \)).

- **Export‑grade reporting (not just screenshots)**: Every session produces a detailed report and shareable summary, and can export to **PDF, CSV, and JSON**. The PDF generator creates a professional report with tables and embedded visualizations, suitable for saving, sharing, or record‑keeping.

- **Mock‑first development for rapid iteration**: Services are defined by protocols and wired through a dependency container. That enables offline development with mock OCR/database layers and a smooth transition to Supabase when you flip the configuration.

- **Polished UX built for real usage**: SwiftUI screens (Home → Upload → Edit → Assign → Report) are designed as a guided flow, with progress tracking for OCR, haptics for key actions, and a modern “liquid glass” aesthetic that still keeps the data front‑and‑center.

## Technical implementation / Tech stack

- **Client**: Swift, SwiftUI, MVVM (`@MainActor` ViewModels), async/await, PDFKit for export, custom chart rendering for PDF embedding.
- **Architecture**: Protocol‑based service layer + dependency injection (`DependencyContainer`) to isolate business logic, enable mocking, and keep views thin.
- **Core algorithms**:
  - Split computation with item sharing + quantity handling
  - Variance validation (warn/error thresholds)
  - Cent‑level reconciliation via largest‑remainder redistribution
  - OCR result merging with Levenshtein similarity deduplication
- **Backend (optional)**: Supabase REST (sessions), Supabase Storage (images), Supabase Edge Functions (Deno) for OCR extraction with **Gemini Vision** (and fallback paths).

Reliability is treated as a feature: network calls run with timeouts and retry logic where it matters, uploads use adaptive JPEG compression to avoid “too large” failures, and errors are captured with contextual logging so you can debug real-world receipts—not just happy-path demos.

## Project setup / Installation

1. **Prerequisites**
   - macOS 14+
   - Xcode 15.3+
   - iOS 18+ Simulator or device

2. **Open and run**

```bash
cd "/Users/krutinrahtod/Desktop/Desktop/WEB/webCodes/latestCodee/splitLens"
open SplitLens.xcodeproj
```

3. In Xcode, select an iOS 18+ simulator (e.g., iPhone 16 Pro) and press **⌘R**.

4. **(Optional) Enable Supabase + real OCR**
   - Set `SUPABASE_PROJECT_URL`, `SUPABASE_API_KEY`, and `SUPABASE_OCR_FUNCTION_URL` in `Info.plist` (read by `SplitLens/Configuration/SupabaseConfig.swift`).
   - Deploy the Edge Function and set an API key (e.g., `GOOGLE_GEMINI_API_KEY`) in your Supabase project:

```bash
supabase functions deploy extract-receipt-data
```

## Future scope / Roadmap

- **Authentication + per-user history**: Supabase Auth + tighter RLS policies so sessions sync safely across devices.
- **Smarter item parsing and fee handling**: Auto-detect taxes/tips/fees, then apply configurable allocation strategies (equal, proportional, manual).
- **Multi-page OCR “best of both worlds”**: Adaptive batching (single request vs sequential) to balance speed, cost, and rate limits.
- **Advanced settlement optimization**: Reduce the number of transfers (min-cost flow style simplification) while keeping explanations transparent.
- **Production telemetry**: Lightweight analytics and crash reporting to measure OCR accuracy, failure modes, and time-to-split improvements.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

**Prerequisites:** macOS 14+, Xcode 15.3+, iOS 18+ simulator or device.

```bash
open SplitLens.xcodeproj
# Then select an iOS 18+ simulator and press ⌘R
```

**Run tests (all):**
```bash
xcodebuild test -project SplitLens.xcodeproj -scheme SplitLens -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

**Run a single test class:**
```bash
xcodebuild test -project SplitLens.xcodeproj -scheme SplitLens \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:SplitLensTests/OCRServiceTests
```

**Deploy Supabase Edge Function:**
```bash
supabase functions deploy extract-receipt-data --project-ref bnkpaikzslmwdcdmonoa
```

## Configuration

Supabase credentials live in `Config.xcconfig` (gitignored), which are injected into `Info.plist` and read at runtime by `SplitLens/Configuration/SupabaseConfig.swift`. The keys are `SUPABASE_PROJECT_URL`, `SUPABASE_API_KEY`, and `SUPABASE_OCR_FUNCTION_URL`.

When credentials are absent or `useMockServices = true`, the app automatically falls back to `MockOCRService` and `MockSupabaseService` — no code changes needed for offline development.

## Architecture

### Dependency Injection

`DependencyContainer` (singleton at `DependencyContainer.shared`) wires all services at startup and is injected into the SwiftUI view hierarchy via a custom environment key (`\.dependencies`). Views access it with `.withDependencies(dependencies)` at the root `ContentView`.

Services are defined as protocols, enabling mock/real swapping:
- `OCRServiceProtocol` → `MockOCRService` / `SupabaseOCRService`
- `SupabaseServiceProtocol` → `MockSupabaseService` / `RealSupabaseService`
- `SessionStoreProtocol` → `SwiftDataSessionStore` (primary) / `InMemorySessionStore` (fallback)
- `ReceiptImageStoreProtocol` → `LocalReceiptImageStore`
- `BillSplitEngineProtocol` → `AdvancedBillSplitEngine` (wraps `BillSplitEngine`)
- `ReportGenerationEngineProtocol` → `ReportGenerationEngine`

### Navigation Flow

All routes are typed in `Navigation/Route.swift` as `enum Route: Hashable` and passed through a `NavigationStack`. The user flow is strictly linear, with each screen receiving its data directly via the route case's associated values:

```
HomeView
  → ImageUploadView          (scan/upload receipt images)
  → ItemsEditorView          ([ReceiptItem], [Fee], ScanMetadata)
  → ParticipantsEntryView    ([ReceiptItem], [Fee], ScanMetadata)
  → TaxTipAllocationView     ([ReceiptItem], [Fee], [String], String, Double, ScanMetadata)
  → ItemAssignmentView       ([ReceiptItem], [String], String, Double, [FeeAllocation], ScanMetadata)
  → FinalReportView          (ReceiptSession, ScanMetadata)

HomeView → HistoryView → SessionDetailView (read-only history browser)
```

Data is not stored in shared state between screens; each route case carries everything the next screen needs.

### Core Data Model

`ReceiptSession` is the central domain model (codable, stored via SwiftData). It contains: participants, paidBy, totalAmount, items (`[ReceiptItem]`), computedSplits (`[SplitLog]`), feeAllocations (`[FeeAllocation]`), and receipt image paths.

`ReceiptSession` uses snake_case `CodingKeys` to match the Supabase schema (e.g., `total_amount`, `paid_by`).

Local persistence uses **SwiftData** (`StoredSession` model wrapping JSON-encoded `ReceiptSession`) via `SwiftDataSessionStore`. Sessions are wrapped in a `StoredSessionEnvelope` with a `schemaVersion` field for future migrations.

Receipt images are stored locally on-device via `LocalReceiptImageStore` and paths are stored on `ReceiptSession.receiptImagePaths`.

### Key Algorithms

**OCR pipeline** (`SupabaseOCRService`): Multi-image receipts are processed sequentially. Results are merged using Levenshtein-based deduplication — items with >80% name similarity are merged, keeping the higher-priced entry. Fees are deduplicated by type (case-insensitive), keeping the highest amount. The last page's total is used as the authoritative total.

**Bill split engine** (`AdvancedBillSplitEngine` / `BillSplitEngine`):
- "Payer reimbursement" model: everyone reimburses the single payer.
- Items assigned to `"All"` split equally among all participants; otherwise split among `assignedTo` members.
- Cent-level reconciliation uses the **largest-remainder method**: convert to integer cents, compute shortfall/excess, distribute one cent at a time alphabetically to participants.
- Variance checks: warn (non-fatal) at >1% mismatch between calculated and entered total; hard-fail at >10%.
- `FeeAllocation` supports three strategies: `.proportional` (by spending ratio), `.equal` (per-head), `.manual` (specified assignees).

**Report & export**: `ReportGenerationEngine` produces `ReportData`. `PDFGenerator` renders a multi-page PDF with tables and embedded `ChartRenderer` visuals (pie/bar charts drawn via CoreGraphics into off-screen contexts). Export formats: PDF, CSV, JSON.

### ViewModels

All ViewModels are `@MainActor` classes. `ImageUploadViewModel` has its OCR logic factored into an extension file (`ImageUploadViewModel+OCR.swift`). Progress during OCR is tracked via `OCRProgressTracker` with states: `.preprocessing`, `.uploading`, `.analyzing`, `.parsing`.

### Backend (Supabase Edge Function)

Located at `supabase/functions/extract-receipt-data/index.ts` (Deno/TypeScript). Accepts a POST with `{ "image": "<base64>" }` or `{ "images": ["<base64>", ...] }` for batch processing. Uses **Google Gemini Vision** API (key set via `supabase secrets set GOOGLE_GEMINI_API_KEY=...`). Falls back to mock data when no API key is configured.

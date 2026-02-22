# Feature Prompt: Enhanced History with Receipt Photos & Per-Person Split Breakdowns

## Overview

Redesign the **History** flow (`HistoryView` → `SessionDetailView`) so that every past split session displays the original receipt photos alongside a comprehensive per-person financial breakdown. Each person's total contribution must be fully sourced — the user should be able to see *exactly* which items, shared costs, and fees contributed to every cent a person owes, for every participant in the session.

---

## Why This Matters

The existing `SessionDetailView` shows a flat list of items and a settlements section ("Alice → Bob: $24.50") but **never answers the question**: *"Why does Alice owe $24.50?"* Users need to tap into any session and instantly see the receipt photos they scanned plus a structured, auditable breakdown per person — not just a text blob in `SplitLog.explanation`, but a visual, expandable UI with categorised line items.

---

## Existing Architecture Reference

Read and understand these files before implementing:

| Layer | File(s) | What It Does |
|---|---|---|
| **Data model** | `SplitLens/Models/ReceiptSession.swift` | Central domain model. Stores `items`, `computedSplits`, `feeAllocations`, `receiptImagePaths`, `participants`, `paidBy`, `totalAmount`. |
| **Data model** | `SplitLens/Models/SplitLog.swift` | Settlement record — `from`, `to`, `amount`, `explanation` (freeform string). |
| **Data model** | `SplitLens/Models/FeeAllocation.swift` | Fee + strategy (`.proportional`, `.equal`, `.manual`) + optional `manualAssignments`. Also contains `Fee` struct with `type`, `amount`, `displayName`, `feeType`. |
| **Data model** | `SplitLens/Models/ReceiptItem.swift` | Line item — `name`, `quantity`, `price`, `assignedTo: [String]`, `sourcePageIndex`. |
| **Engine** | `SplitLens/Services/BillSplitEngine.swift` | `AdvancedBillSplitEngine.computeSplitsWithFees()` already computes `itemBreakdowns: [String: [(item, amount)]]` and `feeBreakdowns: [String: [(fee, amount)]]` per person **internally** — but discards them after generating the explanation string. This is the key data to persist. |
| **Persistence** | `SplitLens/Persistence/SessionStore.swift` | `SwiftDataSessionStore` saves/loads `ReceiptSession` as JSON via `StoredSessionEnvelope` with `schemaVersion`. |
| **Persistence** | `SplitLens/Persistence/ReceiptImageStore.swift` | `LocalReceiptImageStore` — saves compressed JPEGs to `ApplicationSupport/ReceiptImages/<sessionId>/page-01.jpg`, loads by absolute path. |
| **Persistence** | `SplitLens/Persistence/StoredSession.swift` | SwiftData `@Model` class wrapping the JSON payload. |
| **ViewModel** | `SplitLens/ViewModels/HistoryViewModel.swift` | Loads sessions, supports search/sort/delete. Uses `SessionStoreProtocol` and `ReceiptImageStoreProtocol`. |
| **ViewModel** | `SplitLens/ViewModels/ReportViewModel.swift` | `saveSession()` persists images + session data. `computeSplits()` runs the engine. |
| **View** | `SplitLens/Views/HistoryView.swift` | List of `HistoryRow` cells → navigates to `SessionDetailView` via `Route.sessionDetail(session)`. |
| **View** | `SplitLens/Views/SessionDetailView.swift` | Read-only detail. Currently shows: metadata, summary cards, receipt image carousel, items list, settlements list. **Missing**: per-person breakdown. |
| **View** | `SplitLens/Views/FinalReportView.swift` | Post-split report. Has `perPersonBreakdownSection` that shows totals but **not** itemised sources. |
| **Navigation** | `Navigation/Route.swift` | `Route.sessionDetail(ReceiptSession)` — the route for opening a saved session. |
| **DI** | `SplitLens/Services/DependencyContainer.swift` | Singleton wiring all protocols. Injected via SwiftUI environment. |

---

## Detailed Requirements

### 1. Structured Per-Person Breakdown Model

**Problem**: The engine (`AdvancedBillSplitEngine`) currently computes per-person item and fee breakdowns as local variables inside `computeSplitsWithFees()`, then flattens them into a freeform `explanation: String` on `SplitLog`. This string is fine for sharing/export but unusable for structured UI rendering in history.

**Solution**: Introduce a new `PersonBreakdown` model (or similar name) and persist it on `ReceiptSession`.

```swift
/// Detailed cost breakdown for a single participant
struct PersonBreakdown: Identifiable, Codable, Equatable {
    var id: UUID = UUID()

    /// Participant name
    var person: String

    /// Individual item charges attributed to this person
    var itemCharges: [ItemCharge]

    /// Fee charges attributed to this person
    var feeCharges: [FeeCharge]

    /// Total amount this person is responsible for (items + fees)
    var totalAmount: Double {
        itemCharges.reduce(0) { $0 + $1.amount } +
        feeCharges.reduce(0) { $0 + $1.amount }
    }

    /// Net settlement amount (positive = owes payer, negative = is owed)
    var settlementAmount: Double
}

struct ItemCharge: Identifiable, Codable, Equatable {
    var id: UUID = UUID()

    /// Name of the receipt item
    var itemName: String

    /// Full price of the item on the receipt
    var itemFullPrice: Double

    /// Number of people this item was split among
    var splitAmong: Int

    /// This person's share
    var amount: Double
}

struct FeeCharge: Identifiable, Codable, Equatable {
    var id: UUID = UUID()

    /// Fee display name (e.g. "Tax", "Tip", "Delivery Fee")
    var feeName: String

    /// Total fee amount
    var feeFullAmount: Double

    /// Allocation strategy used
    var strategy: FeeAllocationStrategy

    /// This person's share of the fee
    var amount: Double
}
```

Add a new property on `ReceiptSession`:

```swift
/// Per-person itemised breakdowns for history display
var personBreakdowns: [PersonBreakdown]
```

Update `CodingKeys` with `person_breakdowns`, bump `StoredSessionEnvelope.schemaVersion` to `2`, and ensure the custom `init(from:)` / `encode(to:)` handles the new field with a fallback to `[]` for v1 sessions.

### 2. Engine Changes — Persist Breakdown Data

Modify `AdvancedBillSplitEngine.computeSplitsWithFees()` (and the basic `BillSplitEngine.computeSplits()` for non-fee sessions) so that instead of discarding the per-person item/fee breakdown maps, they return them as part of the result.

**Option A (preferred)**: Extend `BillSplitResult` to include `personBreakdowns: [PersonBreakdown]`.

```swift
struct BillSplitResult {
    let splits: [SplitLog]
    let warnings: [BillSplitWarning]
    let personBreakdowns: [PersonBreakdown]   // NEW
}
```

Then in `ReportViewModel.computeSplits()`, set `session.personBreakdowns = result.personBreakdowns` alongside `session.computedSplits = result.splits`.

This ensures the structured data is available both at report time (in `FinalReportView`) and after save (in `SessionDetailView`).

### 3. History List — Receipt Photo Thumbnails

**Current `HistoryRow`**: Shows a date badge, payer name, amount, date, participant count, item count.

**Enhanced `HistoryRow`**: Add a small receipt thumbnail to the left of the date badge area, replacing or supplementing the date badge.

**Design spec:**

```
┌─────────────────────────────────────────────────────────┐
│  ┌──────┐                                               │
│  │ IMG  │   Alice paid                        $65.96    │
│  │ thumb│   Feb 22  ·  3 people  ·  8 items             │
│  └──────┘                                               │
│                                                         │
│  👤 Alice: $0.00  ·  Bob: $24.50  ·  Charlie: $21.46   │
└─────────────────────────────────────────────────────────┘
```

- **Thumbnail**: 50×60 rounded rect. Load the first image from `session.receiptImagePaths` using `receiptImageStore.loadImage(atPath:)`. If no image available, show the existing date badge as fallback.
- **Quick-glance split line**: Below the date/people/items row, add a single condensed line showing each person's total contribution (from `personBreakdowns`). Use `CurrencyFormatter.shared.format()`. If more than 3 people, show first 3 + "+ N more". Truncate with `lineLimit(1)` and `.truncationMode(.tail)`.

### 4. Session Detail View — Full Redesign

Redesign `SessionDetailView` to be the **definitive** history detail screen with three logical sections:

#### Section A: Receipt Photo Gallery (top)

- Horizontal `ScrollView` of receipt images (already exists — keep the current `receiptImagesSection` implementation).
- **Add**: Tap-to-zoom. Wrap each image in a `Button` that presents a full-screen `sheet` or `fullScreenCover` with pinch-to-zoom (`MagnificationGesture` + `DragGesture` on an `Image`). Include a close button and page indicator.
- **Add**: If multiple images, show a page indicator (`Text("1 of 3")` badge overlaid on each card).

#### Section B: Per-Person Breakdown Cards (main content)

This is the **centrepiece** of the redesign. For each participant, render an expandable card:

```
┌──────────────────────────────────────────────────────┐
│  🔵 A   Alice (Paid the bill)            Total $22.00│
│         ▼ Tap to see breakdown                       │
├──────────────────────────────────────────────────────┤
│  Items                                               │
│    Margherita Pizza    $18.00 ÷ 3 = $6.00           │
│    Caesar Salad        $12.00 ÷ 2 = $6.00           │
│    Garlic Bread (All)  $8.00 ÷ 4  = $2.00           │
│    Coke                $4.00 ÷ 1  = $4.00           │
│                                     ─────           │
│                          Items subtotal: $18.00      │
│                                                      │
│  Fees                                                │
│    Tax (proportional)  $6.00 × 40% = $2.40          │
│    Tip (equal)         $8.00 ÷ 4   = $2.00          │
│                                     ─────           │
│                           Fees subtotal: $4.40       │
│                                                      │
│                                  ━━━━━               │
│  💰 Alice's total: $22.00                            │
│  ✅ Alice paid — is owed $43.96 from others          │
└──────────────────────────────────────────────────────┘
```

**Implementation detail:**

- Use `DisclosureGroup` or a custom expandable view with animation (`.spring()` transition on content height).
- Default state: **collapsed** showing just the person's name, avatar circle (first letter), role tag ("Paid" / "Participant"), and total amount.
- Expanded state: Full breakdown with items, fees, subtotals, and settlement status.
- **Item rows**: Show `itemName`, `itemFullPrice ÷ splitAmong = amount` format. Right-align the amount.
- **Fee rows**: Show `feeName (strategy label)`, then the calculation (`feeFullAmount × ratio` for proportional, `feeFullAmount ÷ count` for equal, or `feeFullAmount ÷ assigneeCount` for manual), then the amount.
- **Settlement row**: At the bottom of each card, show:
  - If person is the payer: "Paid the bill — is owed [sum of incoming splits] from others"
  - If person owes: "Owes [payer name] [amount]"
  - If person owes nothing (e.g. they only had items that round to $0): "All settled!"
- Color coding: Green for the payer (they're owed money), warm orange/red for people who owe.
- The avatar circle colour should be deterministic based on the person's name (hash the name into a hue).

#### Section C: Summary & Settlement (bottom)

Keep the existing summary cards (`SummaryCard` grid) and settlements list (`SplitLogRow`), but move them below the per-person section. Add a "Total Accounted" footer showing the sum of all `personBreakdown.totalAmount` values, which should match `session.totalAmount`.

### 5. Backward Compatibility for Existing Sessions

Sessions saved before this feature will have `personBreakdowns = []`. When `SessionDetailView` detects an empty `personBreakdowns` array for a session that *does* have items and participants:

1. **Recompute on the fly**: Instantiate `AdvancedBillSplitEngine` (or `BillSplitEngine` for sessions with no fee allocations), call `computeSplits(session:)`, and use the returned `personBreakdowns` for display. Do NOT re-save automatically — this is a read-only view.
2. Show a subtle info banner: "Breakdown reconstructed from saved items" (since the data wasn't originally persisted, cent-level rounding could theoretically differ from the original split if the engine changes in the future).

### 6. Image Full-Screen Viewer

Create a new reusable component:

**File**: `SplitLens/Views/Components/FullScreenImageViewer.swift`

- Presented as `.fullScreenCover`.
- Accepts `images: [UIImage]` and `initialIndex: Int`.
- Horizontal `TabView` with `.page` style for swiping between images.
- Pinch-to-zoom via `MagnificationGesture` (min 1×, max 5×).
- Double-tap to toggle between 1× and 2.5×.
- Drag-to-pan when zoomed in.
- Page indicator ("1 of 3") at the bottom.
- "✕" close button at top-leading.
- Dark background for contrast.

### 7. Empty & Edge States

| Scenario | Expected Behaviour |
|---|---|
| Session has no receipt images | Hide the photo gallery section entirely. Show the date badge in `HistoryRow` instead of thumbnail. |
| Session has images but files are missing from disk | Show placeholder cards with "Image unavailable" (already partially handled — keep existing `missingImageCount` logic). |
| Session has only 1 participant | Show the single person's breakdown. Settlement row says "Solo bill — no split needed." |
| Session has 0 `personBreakdowns` (legacy) | Recompute from existing session data (see §5). |
| Session has no fee allocations | Hide the "Fees" sub-section in the breakdown card. Show only item charges. |
| Person has 0 item charges (edge: only fees assigned via manual) | Show "No items" in items sub-section; show fees normally. |
| Very long item names | Truncate with `lineLimit(2)` and ellipsis. Full name visible on expansion. |

### 8. Performance Considerations

- **Image loading**: Receipt images can be 500KB–1.5MB each. In `HistoryView`, load thumbnails lazily. Use `UIImage` downsampling (e.g. `prepareThumbnail(of:)` on iOS 15+) to generate ~100px thumbnails for the list. Do NOT load full-res images in `HistoryRow`.
- **Session list**: Continue using the existing `List` + `ForEach` pattern. The `personBreakdowns` data is small (few KB per session) and is already part of the JSON payload — no extra fetch needed.
- **Full-screen viewer**: Load full-res images only when the viewer is presented. Release them on dismiss.

### 9. File Change Summary

| Action | File | What Changes |
|---|---|---|
| **CREATE** | `SplitLens/Models/PersonBreakdown.swift` | New model file with `PersonBreakdown`, `ItemCharge`, `FeeCharge` structs. |
| **CREATE** | `SplitLens/Views/Components/FullScreenImageViewer.swift` | Reusable pinch-to-zoom multi-image viewer. |
| **MODIFY** | `SplitLens/Models/ReceiptSession.swift` | Add `personBreakdowns: [PersonBreakdown]` property, update `CodingKeys`, update `init(from:)`/`encode(to:)`, update `init()` default, update sample data. |
| **MODIFY** | `SplitLens/Services/BillSplitEngine.swift` | Update `BillSplitResult` to include `personBreakdowns`. Update both `BillSplitEngine.computeSplits()` and `AdvancedBillSplitEngine.computeSplitsWithFees()` to build and return `PersonBreakdown` arrays. |
| **MODIFY** | `SplitLens/ViewModels/ReportViewModel.swift` | In `computeSplits()`, assign `session.personBreakdowns = result.personBreakdowns`. |
| **MODIFY** | `SplitLens/Views/HistoryView.swift` | Update `HistoryRow` to show receipt thumbnail + quick-glance per-person totals. |
| **MODIFY** | `SplitLens/Views/SessionDetailView.swift` | Major redesign — add per-person expandable breakdown cards, tap-to-zoom on images, backward-compatibility recomputation. |
| **MODIFY** | `SplitLens/Views/FinalReportView.swift` | Enhance `perPersonBreakdownSection` to use structured `personBreakdowns` data instead of just `totalOwed(by:)`. |
| **MODIFY** | `SplitLens/Persistence/StoredSession.swift` | Bump `schemaVersion` to 2 (no structural change needed — the JSON payload auto-includes the new field). |
| **MODIFY** | `SplitLens/Persistence/SessionStore.swift` | Update `currentSchemaVersion` constant to `2`. |
| **MODIFY** | `SplitLensTests/BillSplitEngineTests.swift` | Add tests verifying `personBreakdowns` accuracy in `BillSplitResult`. |
| **ADD TO PROJECT** | `SplitLens.xcodeproj/project.pbxproj` | Register new `.swift` files in the Xcode project. |

### 10. Testing Requirements

#### Unit Tests (in `SplitLensTests/`)

1. **`PersonBreakdownTests`** (new file):
   - `testItemChargeCalculation` — verify `amount = itemFullPrice / splitAmong`
   - `testFeeChargeProportional` — verify proportional fee distribution sums to fee total
   - `testFeeChargeEqual` — verify equal fee distribution
   - `testTotalAmountComputed` — verify `totalAmount` = sum of item charges + fee charges
   - `testCodableRoundTrip` — encode → decode → assert equality

2. **`BillSplitEngineTests`** (modify existing):
   - `testPersonBreakdownsReturned` — verify `BillSplitResult.personBreakdowns` is non-empty for a valid session
   - `testPersonBreakdownsMatchSplitTotals` — verify each person's `totalAmount` in breakdowns matches the corresponding computed split amount (± 1 cent for rounding)
   - `testPersonBreakdownsIncludeAllParticipants` — verify every participant has a breakdown entry
   - `testPersonBreakdownsWithFees` — verify fee charges appear when `feeAllocations` are present
   - `testLegacySessionRecomputation` — create a session with empty `personBreakdowns`, run engine, verify breakdowns are generated

3. **`SessionStoreTests`** (new or extend existing):
   - `testSaveAndFetchWithBreakdowns` — save a session with `personBreakdowns`, fetch it back, verify data integrity
   - `testBackwardCompatibilityV1Session` — decode a v1 JSON payload (no `person_breakdowns` key), verify it decodes with empty array

### 11. Acceptance Criteria

- [ ] Opening any saved session shows receipt photos at the top (if available) with tap-to-zoom.
- [ ] Each participant has an expandable card showing their total and full item-by-item + fee-by-fee breakdown.
- [ ] Every `ItemCharge.amount` shows the formula (`$X ÷ N = $Y`) so users understand the math.
- [ ] Every `FeeCharge.amount` shows the strategy and calculation.
- [ ] The sum of all `PersonBreakdown.totalAmount` values equals `session.totalAmount` (within ±$0.01).
- [ ] `HistoryRow` shows a receipt thumbnail (first image) when available.
- [ ] `HistoryRow` shows a condensed per-person total line.
- [ ] Legacy sessions (saved before this feature) display recomputed breakdowns with an info banner.
- [ ] Full-screen image viewer supports pinch-to-zoom, double-tap zoom, swipe between pages.
- [ ] All new code follows existing patterns: `@MainActor` ViewModels, protocol-based DI, `Codable` models with snake_case `CodingKeys`, liquid glass / ultra-thin material design language.
- [ ] Schema version bumped to 2; v1 sessions still decode without error.
- [ ] All new and modified unit tests pass.

### 12. Design Language

Match the existing app aesthetic throughout:

- **Backgrounds**: `.ultraThinMaterial` layered over `Color(.secondarySystemBackground)`.
- **Cards**: `RoundedRectangle(cornerRadius: 12–14)` with `.shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)`.
- **Typography**: SF Pro — `.system(size:weight:design:)`. Titles at 20pt bold, body at 16pt medium, captions at 13pt, amounts in `.rounded` design.
- **Colours**: Green for positive/payer amounts, red/orange for amounts owed, blue for item assignment chips, purple for fee chips.
- **Animations**: `.spring()` for expand/collapse, `.easeInOut` for transitions.
- **Icons**: SF Symbols throughout. Use `person.fill` for avatar, `list.bullet` for items, `percent` for fees, `arrow.right` for settlements.

### 13. Implementation Order (Suggested)

1. **Phase 1 — Data layer**: Create `PersonBreakdown` model → modify `BillSplitResult` → update both engines → update `ReceiptSession` → write unit tests → verify all existing tests still pass.
2. **Phase 2 — Persistence**: Bump schema version → verify encoding/decoding round-trip → test backward compat.
3. **Phase 3 — SessionDetailView redesign**: Build per-person breakdown cards → integrate backward-compat recomputation → add full-screen image viewer.
4. **Phase 4 — HistoryRow enhancements**: Add thumbnail + per-person summary line.
5. **Phase 5 — FinalReportView enhancement**: Use structured breakdowns in the post-split screen.
6. **Phase 6 — Polish**: Animations, edge states, performance (thumbnail downsampling), manual QA on device.

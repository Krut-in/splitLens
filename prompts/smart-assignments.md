# Feature Prompt: Smart Assignments — Intelligent Pattern-Based Item-to-Person Auto-Assignment

## Overview

Introduce **Smart Assignments** — a learning engine that observes how items are assigned to participants across past bill-splitting sessions and uses those patterns to **automatically pre-assign items** on future bills. When a user scans a new receipt, items that have been consistently assigned to the same person in previous sessions are pre-populated with that person's name — ready to go. The user retains full control to accept, modify, or reject every suggestion.

---

## Why This Matters

Today, every bill-splitting session in SplitLens requires the user to manually tap each item and assign it to the right person on the `ItemAssignmentView` screen. For users who regularly split bills with the same group — roommates grocery shopping, friends ordering the same dishes — this is tedious and repetitive. If Krutin always buys the Cookies and Rohan always buys the Milk from Walmart, the user shouldn't have to re-assign those items every single time.

**Concrete example**: Krutin, Rohan, and Nihar split their weekly Walmart grocery bill. Every week, Krutin gets "Cookies" and "Orange Juice", Rohan gets "Milk" and "Bread", and Nihar gets "Chips". After two consecutive weeks of the same assignments, on the third week the app should **automatically suggest** these assignments — pre-selecting each item to its historical owner before the user even touches anything. The user glances at the screen, confirms the suggestions look correct (or tweaks a couple), and moves on. A process that used to take 30+ taps now takes 2–3 seconds.

**Key principle**: The user is the **sole decision-maker**. Smart Assignments are intelligent suggestions, never forced decisions. Every auto-assigned item is visually distinguishable from a manually-assigned one, and the user can override any suggestion with a single tap.

---

## Existing Architecture Reference

Read and understand these files before implementing:

| Layer | File(s) | What It Does |
|---|---|---|
| **Data model** | `SplitLens/Models/ReceiptItem.swift` | Line item — `name`, `quantity`, `price`, `assignedTo: [String]`, `sourcePageIndex`. Has `assign(to:)`, `unassign(from:)`, `toggleAssignment(for:)`, `isAssigned(to:)` methods. |
| **Data model** | `SplitLens/Models/ReceiptSession.swift` | Central domain model. Stores `items: [ReceiptItem]`, `participants: [String]`, `paidBy`, `totalAmount`. Items carry final `assignedTo` data after splitting. Uses snake_case `CodingKeys` for Supabase compatibility. |
| **Data model** | `SplitLens/Models/StructuredReceiptData.swift` | OCR output. Contains `storeName: String?` — the store/vendor name extracted from the receipt. Also `ExtractedItem` with `name`, `quantity`, `price`. |
| **Data model** | `SplitLens/Models/ScanMetadata.swift` | Metadata carried through the scan flow. Contains `id`, `scanCapturedAt`, `ocrReceiptDate`, `selectedImages`. Currently **does not carry `storeName`** — this will need to change. |
| **View** | `SplitLens/Views/ItemAssignmentView.swift` | The screen where users assign items to participants via `ParticipantChip` toggles. Uses `ItemAssignmentCard` for each item. This is the **primary screen affected** — suggestions will be pre-applied here. |
| **ViewModel** | `SplitLens/ViewModels/AssignmentViewModel.swift` | Manages item assignments. Has `items: [ReceiptItem]`, `participants: [String]`, `toggleAssignment()`, `assignItem()`, `splitEquallyAllItems()`, `clearAllAssignments()`. Already has a basic `autoAssign()` method (round-robin — to be replaced/enhanced by smart assignments). |
| **ViewModel** | `SplitLens/ViewModels/ImageUploadViewModel.swift` | Processes OCR results. Extracts `storeName` from `StructuredReceiptData` but currently **discards it** — it's not passed forward through the navigation flow. |
| **ViewModel** | `SplitLens/ViewModels/ReportViewModel.swift` | `saveSession()` persists images + session data to `SessionStore`. This is where learned patterns should be **extracted and saved** after a successful split. |
| **Navigation** | `Navigation/Route.swift` | Routes carry all data between screens. `Route.itemAssignment([ReceiptItem], [String], String, Double, [FeeAllocation], ScanMetadata)` — the route to the assignment screen. `ScanMetadata` is already passed through — it should carry `storeName`. |
| **Persistence** | `SplitLens/Persistence/SessionStore.swift` | `SwiftDataSessionStore` — saves/loads `ReceiptSession` as JSON via `StoredSessionEnvelope`. History data lives here and is the source for pattern extraction. |
| **Persistence** | `SplitLens/Persistence/StoredSession.swift` | SwiftData `@Model` with `payloadData: Data` blob for the full JSON-encoded `ReceiptSession`. |
| **Persistence** | `SplitLens/Persistence/GroupStore.swift` | `SwiftDataGroupStore` — follows the same SwiftData pattern with protocol, implementation, and in-memory fallback. Model for the new `PatternStore`. |
| **DI** | `SplitLens/Services/DependencyContainer.swift` | Singleton wiring all services. Uses a shared `ModelContainer` for `StoredSession` and `StoredGroup`. A new `StoredPattern` model must be registered in this same container. |
| **Engine** | `SplitLens/Services/BillSplitEngine.swift` | `AdvancedBillSplitEngine` computes splits. Not directly affected — pattern learning is separate from split calculation. |
| **Utilities** | `SplitLens/Utilities/Constants.swift` | `AppConstants` enum with nested enums per feature area. Add a `SmartAssignment` section here. |
| **Utilities** | `SplitLens/Utilities/HapticFeedback.swift` | `HapticFeedback.shared` with `.mediumImpact()`, `.lightImpact()`, `.success()`. Use for suggestion application feedback. |
| **OCR** | `SplitLens/Services/OCRService.swift` | `SupabaseOCRService` processes images and returns `StructuredReceiptData`. The `storeName` is already extracted here — it just needs to be threaded forward. |

---

## Detailed Requirements

### 1. Core Concept — The Pattern Learning Algorithm

The system observes item assignments across completed sessions and identifies **recurring patterns**: if the same item is assigned to the same person in **two or more consecutive sessions**, the system considers this a learned pattern and will auto-suggest that assignment on the next matching bill.

#### 1a. Pattern Definition

A **pattern** is a tuple of:

```
(normalizedItemName, storeName?, assignedParticipants, consecutiveHits)
```

- **`normalizedItemName`**: The item name, lowercased, trimmed, and simplified (see §1c for normalisation rules).
- **`storeName`** (optional): The store/vendor name from OCR, lowercased and trimmed. When present, patterns are **store-specific** (higher confidence). When absent, patterns are **global** (lower confidence, broader applicability).
- **`assignedParticipants`**: The `[String]` from `ReceiptItem.assignedTo` — the people this item was assigned to. This supports both single-owner items ("Milk" → ["Rohan"]) and shared items ("Large Pizza" → ["Krutin", "Rohan", "Nihar"]).
- **`consecutiveHits`**: How many consecutive sessions this exact pattern has occurred. Starts at 1 after the first occurrence, increments each time the same item→person(s) assignment is seen again, and **resets to 0** if the item appears but is assigned differently.

#### 1b. Confidence Threshold

A pattern is eligible for auto-suggestion when `consecutiveHits >= 2` — meaning the same assignment must be observed in at least **two consecutive sessions** before the app suggests it on a third.

**Why 2?** One-time assignments are noise (someone tried a new dish). Two consecutive identical assignments establish a habit. This threshold is conservative enough to avoid annoying wrong suggestions while being responsive enough to learn quickly.

Confidence levels for UI presentation:

| `consecutiveHits` | Confidence Label | Visual Treatment |
|---|---|---|
| 0–1 | No suggestion | Item is unassigned (default behaviour) |
| 2 | Likely | Suggestion applied with a subtle indicator |
| 3–4 | Strong | Suggestion applied with a confident indicator |
| 5+ | Very Strong | Suggestion applied with a strong indicator |

#### 1c. Item Name Normalisation

Receipt OCR is imperfect — the same product may appear with slight variations across scans:

- "MILK 2% GAL" vs "Milk 2% Gal" vs "MILK 2%GAL"
- "Cookies Choc Chip" vs "COOKIES CHOC CHIP" vs "Cookies-Choc Chip"

**Normalisation rules** (applied before pattern matching):

1. Lowercase the entire name.
2. Trim leading/trailing whitespace.
3. Collapse multiple spaces into a single space.
4. Remove common filler characters: `*`, `#`, `@`, leading/trailing dashes.
5. Normalise punctuation: replace `-` and `_` between words with a space.

**Fuzzy matching**: When looking up patterns for a new item, use **Levenshtein-based similarity** (already used in `SupabaseOCRService` for deduplication) with a threshold of **80% similarity**. If an incoming item name is >80% similar to a stored pattern's `normalizedItemName`, it's considered a match.

```swift
/// Normalises an item name for pattern storage and matching
static func normalizeItemName(_ name: String) -> String {
    var normalized = name.lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    // Remove filler chars
    normalized = normalized.replacingOccurrences(of: "[*#@]", with: "", options: .regularExpression)
    // Normalise separators
    normalized = normalized.replacingOccurrences(of: "[-_]", with: " ", options: .regularExpression)
    // Collapse whitespace
    normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

#### 1d. Store Name Normalisation

Store names should also be normalised to handle OCR variations:

- "WALMART SUPERCENTER #4523" → "walmart"
- "Walmart Inc." → "walmart"
- "WAL-MART" → "walmart"

**Normalisation rules**:

1. Lowercase.
2. Trim whitespace.
3. Remove store number suffixes: `#\d+`, `No.\d+`, `Store \d+`.
4. Remove common legal suffixes: "inc.", "llc", "corp.", "ltd.".
5. Remove trailing punctuation.
6. Collapse whitespace.

```swift
/// Normalises a store name for pattern matching
static func normalizeStoreName(_ name: String) -> String {
    var normalized = name.lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    // Remove store numbers
    normalized = normalized.replacingOccurrences(of: "#\\d+", with: "", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: "\\b(no\\.?|store)\\s*\\d+", with: "", options: .regularExpression)
    // Remove legal suffixes
    normalized = normalized.replacingOccurrences(of: "\\b(inc\\.?|llc\\.?|corp\\.?|ltd\\.?)\\b", with: "", options: .regularExpression)
    // Remove separators and collapse
    normalized = normalized.replacingOccurrences(of: "[-_]", with: " ", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

#### 1e. Pattern Matching Priority

When suggesting assignments, patterns are ranked by priority:

1. **Store-specific + high confidence**: Item matches a pattern with the same store name and `consecutiveHits >= 3`. Highest priority.
2. **Store-specific + moderate confidence**: Same store, `consecutiveHits == 2`.
3. **Global + high confidence**: No store filtering, `consecutiveHits >= 3`.
4. **Global + moderate confidence**: No store filtering, `consecutiveHits == 2`.

If multiple patterns match the same item (e.g. same item at two different stores with different assignees), use the pattern with the highest `consecutiveHits`. If tied, prefer the store-specific match. If still tied, prefer the most recently updated pattern.

#### 1f. Pattern Lifecycle — When Patterns Are Learned

Patterns are **extracted and persisted immediately after a session is saved** — i.e. in `ReportViewModel.saveSession()`, after the session data and images are stored. This ensures patterns are only learned from completed, confirmed splits (not abandoned or incomplete sessions).

**Learning flow:**

1. User completes item assignment and navigates to `FinalReportView`.
2. User confirms and saves the session (`ReportViewModel.saveSession()`).
3. After successful session save, the `PatternLearningEngine` is called with the saved `ReceiptSession` and `storeName` (from `ScanMetadata`).
4. For each item in the session:
   - Compute `normalizedItemName`.
   - Look up existing patterns for this item (fuzzy match by name, optionally filtered by store).
   - If a matching pattern exists **and** the `assignedParticipants` are identical (same people, order-independent): increment `consecutiveHits`, update `lastSeenAt`.
   - If a matching pattern exists **but** the `assignedParticipants` differ: reset `consecutiveHits` to 1 with the new participants (the old habit is broken).
   - If no matching pattern exists: create a new pattern with `consecutiveHits = 1`.
5. Patterns are persisted to the `PatternStore`.

#### 1g. Pattern Decay & Cleanup

To keep the pattern database manageable and avoid stale suggestions:

- **Staleness threshold**: Patterns not seen in the last **90 days** (`lastSeenAt` older than 90 days) are considered stale and excluded from suggestions during lookup. They remain in storage but are not surfaced.
- **Cleanup**: On app launch (or lazily on first pattern query), delete patterns where `lastSeenAt` is older than **180 days** (6 months). This happens silently in the background.
- **Max patterns**: Cap at **500 patterns** total. If the cap is reached, delete the oldest (by `lastSeenAt`) patterns to make room. This limit is generous — most users won't approach it.

---

### 2. Data Model — `AssignmentPattern`

**File**: `SplitLens/Models/AssignmentPattern.swift`

```swift
/// A learned pattern recording which person(s) are typically assigned to a specific item
struct AssignmentPattern: Identifiable, Codable, Equatable {
    /// Unique identifier
    var id: UUID = UUID()

    /// Normalised item name (lowercased, trimmed, simplified)
    var normalizedItemName: String

    /// Original item name as it last appeared on a receipt (for display purposes)
    var displayItemName: String

    /// Normalised store name, if known (nil for store-agnostic patterns)
    var normalizedStoreName: String?

    /// Original store name as it last appeared (for display purposes)
    var displayStoreName: String?

    /// The participant(s) this item is typically assigned to.
    /// Sorted alphabetically for consistent comparison.
    var assignedParticipants: [String]

    /// Number of consecutive sessions where this exact item→person(s) pattern was observed
    var consecutiveHits: Int

    /// When this pattern was first observed
    var createdAt: Date = Date()

    /// When this pattern was last confirmed (last session where the pattern held)
    var lastSeenAt: Date = Date()

    /// Total number of times this pattern has been observed (cumulative, not just consecutive)
    var totalOccurrences: Int = 1
}
```

**Computed properties:**

```swift
extension AssignmentPattern {
    /// Whether this pattern meets the minimum threshold for auto-suggestion
    var isSuggestable: Bool {
        consecutiveHits >= 2
    }

    /// Confidence level based on consecutive hits
    var confidence: PatternConfidence {
        switch consecutiveHits {
        case 0...1: return .none
        case 2: return .likely
        case 3...4: return .strong
        default: return .veryStrong
        }
    }

    /// Whether this pattern is stale (not seen in the staleness window)
    var isStale: Bool {
        let stalenessThreshold: TimeInterval = 90 * 24 * 60 * 60 // 90 days
        return Date().timeIntervalSince(lastSeenAt) > stalenessThreshold
    }

    /// Whether this pattern is store-specific
    var isStoreSpecific: Bool {
        normalizedStoreName != nil && !normalizedStoreName!.isEmpty
    }

    /// Formatted participant list for display (e.g., "Krutin" or "Krutin, Rohan")
    var participantLabel: String {
        if assignedParticipants.count <= 2 {
            return assignedParticipants.joined(separator: ", ")
        } else {
            let first2 = assignedParticipants.prefix(2).joined(separator: ", ")
            return "\(first2) + \(assignedParticipants.count - 2) more"
        }
    }
}

/// Confidence level of a learned assignment pattern
enum PatternConfidence: String, Codable, Comparable {
    case none = "none"
    case likely = "likely"
    case strong = "strong"
    case veryStrong = "very_strong"

    /// Comparable conformance for priority ranking
    static func < (lhs: PatternConfidence, rhs: PatternConfidence) -> Bool {
        let order: [PatternConfidence] = [.none, .likely, .strong, .veryStrong]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }

    /// User-facing label
    var displayLabel: String {
        switch self {
        case .none: return ""
        case .likely: return "Suggested"
        case .strong: return "Usually"
        case .veryStrong: return "Always"
        }
    }

    /// SF Symbol for the confidence badge
    var iconName: String {
        switch self {
        case .none: return ""
        case .likely: return "lightbulb.fill"
        case .strong: return "brain.fill"
        case .veryStrong: return "brain.head.profile.fill"
        }
    }
}
```

**CodingKeys** (snake_case for consistency):

```swift
extension AssignmentPattern {
    enum CodingKeys: String, CodingKey {
        case id
        case normalizedItemName = "normalized_item_name"
        case displayItemName = "display_item_name"
        case normalizedStoreName = "normalized_store_name"
        case displayStoreName = "display_store_name"
        case assignedParticipants = "assigned_participants"
        case consecutiveHits = "consecutive_hits"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case totalOccurrences = "total_occurrences"
    }
}
```

---

### 3. Persistence — `PatternStore`

Follow the exact same persistence pattern as `SessionStore` / `GroupStore`.

#### 3a. SwiftData Model

**File**: `SplitLens/Persistence/StoredPattern.swift`

```swift
@Model
final class StoredPattern {
    @Attribute(.unique) var id: UUID

    /// Normalised item name — indexed for fast lookup
    var normalizedItemName: String

    /// Normalised store name — indexed for store-specific queries
    var normalizedStoreName: String?

    /// Number of consecutive hits — used for filtering suggestable patterns
    var consecutiveHits: Int

    /// Last seen date — used for staleness checks and cleanup
    var lastSeenAt: Date

    /// Full JSON payload
    var payloadData: Data

    init(
        id: UUID,
        normalizedItemName: String,
        normalizedStoreName: String?,
        consecutiveHits: Int,
        lastSeenAt: Date,
        payloadData: Data
    ) {
        self.id = id
        self.normalizedItemName = normalizedItemName
        self.normalizedStoreName = normalizedStoreName
        self.consecutiveHits = consecutiveHits
        self.lastSeenAt = lastSeenAt
        self.payloadData = payloadData
    }
}
```

Indexed fields (`normalizedItemName`, `normalizedStoreName`, `consecutiveHits`, `lastSeenAt`) are stored as top-level properties for efficient querying. The full `AssignmentPattern` is JSON-encoded in `payloadData`.

#### 3b. Store Protocol & Implementation

**File**: `SplitLens/Persistence/PatternStore.swift`

```swift
protocol PatternStoreProtocol {
    /// Save or update a pattern (upsert by id)
    func savePattern(_ pattern: AssignmentPattern) async throws

    /// Save multiple patterns in a single batch (used after session save)
    func savePatterns(_ patterns: [AssignmentPattern]) async throws

    /// Fetch all suggestable patterns (consecutiveHits >= 2, not stale)
    /// Optionally filtered by store name
    func fetchSuggestablePatterns(storeName: String?) async throws -> [AssignmentPattern]

    /// Fetch a specific pattern matching an item name and optional store name
    /// Uses exact match on normalizedItemName (fuzzy matching is done at the engine layer)
    func fetchPattern(normalizedItemName: String, normalizedStoreName: String?) async throws -> AssignmentPattern?

    /// Fetch all patterns for a given normalised item name (across all stores)
    func fetchPatterns(forItem normalizedItemName: String) async throws -> [AssignmentPattern]

    /// Delete a specific pattern
    func deletePattern(id: UUID) async throws

    /// Delete all stale patterns (lastSeenAt > 180 days)
    func cleanupStalePatterns() async throws -> Int

    /// Total number of stored patterns
    func patternCount() async throws -> Int

    /// Delete all patterns (for testing or user-initiated reset)
    func deleteAllPatterns() async throws
}
```

**Implementation**: `SwiftDataPatternStore` — mirrors `SwiftDataGroupStore` pattern. Use the same `ModelContainer` instance (register `StoredPattern.self` alongside `StoredSession.self` and `StoredGroup.self` in the container schema).

**Fallback**: `InMemoryPatternStore` — same pattern as `InMemorySessionStore` / `InMemoryGroupStore`, for when SwiftData fails to initialise.

**Error handling**: `PatternStoreError` enum:

```swift
enum PatternStoreError: Error, LocalizedError {
    case notFound
    case persistenceFailed(String)
    case decodeFailed(String)
    case storageLimitReached

    var errorDescription: String? {
        switch self {
        case .notFound: return "Pattern not found."
        case .persistenceFailed(let msg): return "Could not persist pattern: \(msg)"
        case .decodeFailed(let msg): return "Could not decode pattern data: \(msg)"
        case .storageLimitReached: return "Pattern storage limit reached."
        }
    }
}
```

---

### 4. Pattern Learning Engine

**File**: `SplitLens/Services/PatternLearningEngine.swift`

This is the **core intelligence** — a stateless service that reads historical patterns from the store, compares them against new session data, and updates the pattern database.

```swift
protocol PatternLearningEngineProtocol {
    /// Learn patterns from a completed session. Called after session save.
    func learnPatterns(
        from session: ReceiptSession,
        storeName: String?
    ) async throws

    /// Suggest assignments for a list of items, given the current participants and optional store context.
    /// Returns a mapping from item ID → suggested [String] assignees.
    func suggestAssignments(
        for items: [ReceiptItem],
        participants: [String],
        storeName: String?
    ) async throws -> [UUID: SuggestedAssignment]
}

/// A suggestion for a single item's assignment
struct SuggestedAssignment: Equatable {
    /// The suggested participants to assign this item to
    let participants: [String]

    /// Confidence level of the suggestion
    let confidence: PatternConfidence

    /// The pattern that generated this suggestion (for debugging/display)
    let sourcePatternId: UUID

    /// Whether the suggestion is store-specific (vs global)
    let isStoreSpecific: Bool
}
```

#### 4a. `learnPatterns(from:storeName:)` — Learning Logic

```
For each item in session.items where item.isAssigned:
  1. normalizedName = normalizeItemName(item.name)
  2. normalizedStore = storeName != nil ? normalizeStoreName(storeName!) : nil
  3. sortedAssignees = item.assignedTo.sorted()
  4. existingPattern = patternStore.fetchPattern(
       normalizedItemName: normalizedName,
       normalizedStoreName: normalizedStore
     )
  5. If existingPattern exists:
       a. If existingPattern.assignedParticipants == sortedAssignees:
            // Pattern continues — increment
            existingPattern.consecutiveHits += 1
            existingPattern.totalOccurrences += 1
            existingPattern.lastSeenAt = Date()
            existingPattern.displayItemName = item.name  // keep latest display name
            patternStore.savePattern(existingPattern)
       b. Else:
            // Assignment changed — reset streak with new assignees
            existingPattern.assignedParticipants = sortedAssignees
            existingPattern.consecutiveHits = 1
            existingPattern.totalOccurrences += 1
            existingPattern.lastSeenAt = Date()
            existingPattern.displayItemName = item.name
            patternStore.savePattern(existingPattern)
  6. Else (no existing pattern):
       Create new AssignmentPattern(
         normalizedItemName: normalizedName,
         displayItemName: item.name,
         normalizedStoreName: normalizedStore,
         displayStoreName: storeName,
         assignedParticipants: sortedAssignees,
         consecutiveHits: 1,
         totalOccurrences: 1
       )
       patternStore.savePattern(newPattern)
```

**Important**: If the item is assigned to "All" (i.e. `assignedTo` contains all participants), do **not** learn a pattern from it — shared items assigned to everyone are not meaningful personalisation signals.

#### 4b. `suggestAssignments(for:participants:storeName:)` — Suggestion Logic

```
suggestions: [UUID: SuggestedAssignment] = [:]

allPatterns = patternStore.fetchSuggestablePatterns(storeName: normalizedStore)

For each item in items where !item.isAssigned:
  1. normalizedName = normalizeItemName(item.name)
  2. bestMatch: AssignmentPattern? = nil
     bestSimilarity: Double = 0.0
  3. For each pattern in allPatterns:
       similarity = levenshteinSimilarity(normalizedName, pattern.normalizedItemName)
       if similarity >= 0.80:
         if bestMatch == nil OR pattern has higher priority than bestMatch:
           // Priority: store-specific > global, higher consecutiveHits > lower,
           // more recent lastSeenAt > older
           bestMatch = pattern
           bestSimilarity = similarity
  4. If bestMatch found AND bestMatch.isSuggestable:
       // Validate: all suggested participants must exist in the current session's participants
       validParticipants = bestMatch.assignedParticipants.filter { participants.contains($0) }
       if validParticipants == bestMatch.assignedParticipants:
         suggestions[item.id] = SuggestedAssignment(
           participants: bestMatch.assignedParticipants,
           confidence: bestMatch.confidence,
           sourcePatternId: bestMatch.id,
           isStoreSpecific: bestMatch.isStoreSpecific
         )
       // If some participants are missing (not in this session), skip the suggestion —
       // partial suggestions would be confusing

Return suggestions
```

**Critical constraint**: A pattern's suggested participants must **all** be present in the current session's participant list. If Rohan normally buys "Milk" but isn't part of this session, the suggestion is suppressed entirely — not partially applied.

---

### 5. Threading `storeName` Through the Navigation Flow

Currently, `StructuredReceiptData.storeName` is extracted by OCR but **discarded** before reaching `ItemAssignmentView`. The store name must be threaded through the entire flow so the pattern engine can use it for store-specific matching.

#### 5a. Extend `ScanMetadata`

**File**: `SplitLens/Models/ScanMetadata.swift`

Add a new property:

```swift
/// Store/vendor name extracted from the receipt by OCR (nil if not detected)
let storeName: String?
```

Update the `init()` to accept `storeName`:

```swift
init(
    id: UUID = UUID(),
    scanCapturedAt: Date,
    ocrReceiptDate: Date?,
    ocrReceiptDateHasTime: Bool,
    selectedImages: [UIImage],
    storeName: String? = nil       // NEW
) { ... }
```

Update `ScanMetadata.empty` to include `storeName: nil`.

#### 5b. Populate `storeName` in `ImageUploadViewModel`

**File**: `SplitLens/ViewModels/ImageUploadViewModel.swift` (and `ImageUploadViewModel+OCR.swift`)

When building `ScanMetadata` after OCR completes, pass the `storeName` from the `StructuredReceiptData`:

```swift
let metadata = ScanMetadata(
    scanCapturedAt: Date(),
    ocrReceiptDate: parsedDate,
    ocrReceiptDateHasTime: hasTime,
    selectedImages: selectedImages,
    storeName: ocrResult.storeName    // NEW — thread store name forward
)
```

#### 5c. Add `storeName` to `ReceiptSession`

**File**: `SplitLens/Models/ReceiptSession.swift`

Add a new optional property:

```swift
/// Store/vendor name from OCR (nil if not detected or manually entered)
var storeName: String?
```

Update `CodingKeys`:

```swift
case storeName = "store_name"
```

Update `init(from:)`:

```swift
storeName = try container.decodeIfPresent(String.self, forKey: .storeName)
```

Update `encode(to:)`:

```swift
try container.encodeIfPresent(storeName, forKey: .storeName)
```

Update the `init()` parameter list to include `storeName: String? = nil`.

This ensures the store name is persisted with the session — vital for pattern learning from historical data and for display in the history view.

#### 5d. Set `storeName` on Session Construction

**File**: `SplitLens/Views/ItemAssignmentView.swift` — in `calculateSplits()`:

```swift
let session = ReceiptSession(
    participants: viewModel.participants,
    totalAmount: totalWithFees,
    paidBy: viewModel.paidBy,
    items: viewModel.items,
    computedSplits: [],
    feeAllocations: feeAllocations,
    storeName: scanMetadata.storeName    // NEW
)
```

---

### 6. Dependency Injection

**File**: `SplitLens/Services/DependencyContainer.swift`

Add new properties:

```swift
/// Learned assignment pattern store
let patternStore: PatternStoreProtocol

/// Pattern learning engine
let patternLearningEngine: PatternLearningEngineProtocol
```

Update the `ModelContainer` registration to include `StoredPattern`:

```swift
do {
    let container = try ModelContainer(for: StoredSession.self, StoredGroup.self, StoredPattern.self)
    self.sessionStore = try SwiftDataSessionStore(modelContainer: container)
    self.groupStore = try SwiftDataGroupStore(modelContainer: container)
    let patternStore = try SwiftDataPatternStore(modelContainer: container)
    self.patternStore = patternStore
    self.patternLearningEngine = PatternLearningEngine(patternStore: patternStore)
} catch {
    ErrorHandler.shared.log(error, context: "DependencyContainer.SwiftData")
    self.sessionStore = InMemorySessionStore()
    self.groupStore = InMemoryGroupStore()
    let patternStore = InMemoryPatternStore()
    self.patternStore = patternStore
    self.patternLearningEngine = PatternLearningEngine(patternStore: patternStore)
}
```

---

### 7. Constants

**File**: `SplitLens/Utilities/Constants.swift`

Add a new nested enum:

```swift
// MARK: - Smart Assignment Configuration

/// Constants for pattern-based smart item assignment
enum SmartAssignment {
    /// Minimum consecutive hits before a pattern qualifies for suggestion
    static let minimumConsecutiveHits: Int = 2

    /// Levenshtein similarity threshold for fuzzy item name matching (0.0–1.0)
    static let nameSimilarityThreshold: Double = 0.80

    /// Maximum number of stored patterns
    static let maxPatterns: Int = 500

    /// Patterns not seen in this many days are excluded from suggestions
    static let stalenessDays: Int = 90

    /// Patterns not seen in this many days are deleted on cleanup
    static let cleanupDays: Int = 180

    /// Maximum item name length to consider for pattern learning (skip absurdly long names)
    static let maxItemNameLength: Int = 100
}
```

---

### 8. Integration — Learning After Session Save

**File**: `SplitLens/ViewModels/ReportViewModel.swift`

After `saveSession()` successfully persists the session and images, trigger pattern learning:

```swift
func saveSession() async {
    // ... existing session save logic ...

    // After successful save — learn patterns from this session
    do {
        try await dependencies.patternLearningEngine.learnPatterns(
            from: session,
            storeName: scanMetadata.storeName
        )
    } catch {
        // Pattern learning failure is non-critical — log and continue
        ErrorHandler.shared.log(error, context: "ReportViewModel.learnPatterns")
    }

    // ... existing post-save logic ...
}
```

**Important**: Pattern learning must never block or fail the session save. It's a secondary, best-effort operation. Wrap it in its own do/catch and log failures silently.

---

### 9. Integration — Applying Suggestions on Item Assignment Screen

This is the **user-facing centrepiece** — when the user arrives at `ItemAssignmentView`, items should already have smart suggestions pre-applied.

#### 9a. ViewModel Changes

**File**: `SplitLens/ViewModels/AssignmentViewModel.swift`

Add new properties:

```swift
// MARK: - Smart Assignment

/// Suggestions generated by the pattern learning engine, keyed by item ID
@Published var suggestions: [UUID: SuggestedAssignment] = [:]

/// Whether suggestions have been loaded
@Published var suggestionsLoaded: Bool = false

/// Items whose assignments came from smart suggestions (for visual distinction)
@Published var smartAssignedItemIds: Set<UUID> = []

/// Whether smart suggestions are enabled (user toggle)
@Published var smartSuggestionsEnabled: Bool = true

/// Dependencies
private let patternLearningEngine: PatternLearningEngineProtocol?
```

Update the `init()` to accept the pattern engine and store name:

```swift
init(
    items: [ReceiptItem],
    participants: [String],
    paidBy: String,
    storeName: String? = nil,
    billSplitEngine: BillSplitEngineProtocol = DependencyContainer.shared.billSplitEngine,
    patternLearningEngine: PatternLearningEngineProtocol? = DependencyContainer.shared.patternLearningEngine
) {
    self.items = items
    self.participants = participants
    self.paidBy = paidBy
    self.storeName = storeName
    self.billSplitEngine = billSplitEngine
    self.patternLearningEngine = patternLearningEngine
}
```

Add the method to load and apply suggestions:

```swift
/// Loads smart suggestions from the pattern engine and pre-applies them to unassigned items
func loadSmartSuggestions() async {
    guard smartSuggestionsEnabled,
          let engine = patternLearningEngine else { return }

    do {
        let suggested = try await engine.suggestAssignments(
            for: items,
            participants: participants,
            storeName: storeName
        )

        suggestions = suggested

        // Pre-apply suggestions to unassigned items
        for (itemId, suggestion) in suggested {
            guard let index = items.firstIndex(where: { $0.id == itemId }),
                  !items[index].isAssigned else { continue }

            // Apply the suggested assignment
            items[index].assignedTo = suggestion.participants
            smartAssignedItemIds.insert(itemId)
        }

        suggestionsLoaded = true

        if !suggested.isEmpty {
            HapticFeedback.shared.lightImpact()
        }
    } catch {
        // Non-critical — silently fail, user assigns manually
        suggestionsLoaded = true
    }
}

/// Checks if a specific item was smart-assigned (for UI badge display)
func isSmartAssigned(_ itemId: UUID) -> Bool {
    smartAssignedItemIds.contains(itemId)
}

/// Gets the suggestion for a specific item (for confidence badge display)
func suggestion(for itemId: UUID) -> SuggestedAssignment? {
    suggestions[itemId]
}

/// Clears all smart suggestions and resets items to unassigned state
func clearSmartSuggestions() {
    for itemId in smartAssignedItemIds {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].assignedTo = []
        }
    }
    smartAssignedItemIds.removeAll()
    suggestions.removeAll()
}
```

Also, update the existing `toggleAssignment(itemId:participant:)` method to remove the item from `smartAssignedItemIds` when the user manually changes an assignment:

```swift
func toggleAssignment(itemId: UUID, participant: String) {
    guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
    var item = items[index]
    item.toggleAssignment(for: participant)
    items[index] = item

    // Once the user manually modifies, it's no longer a "smart" assignment
    smartAssignedItemIds.remove(itemId)
}
```

#### 9b. View Changes — Visual Indicators

**File**: `SplitLens/Views/ItemAssignmentView.swift`

**On appear**, trigger suggestion loading:

```swift
.task {
    await viewModel.loadSmartSuggestions()
}
```

**Smart suggestion banner**: When suggestions were applied, show a brief, dismissible banner at the top of the item list:

```
┌──────────────────────────────────────────────────────────┐
│  💡 Smart Suggestions Applied                    ✕       │
│  N items auto-assigned based on your past splits         │
└──────────────────────────────────────────────────────────┘
```

This banner appears with a `.spring()` animation when `viewModel.suggestionsLoaded && !viewModel.smartAssignedItemIds.isEmpty`. Tapping ✕ dismisses it. An "Undo All" button within the banner calls `viewModel.clearSmartSuggestions()`.

**Smart assignment badge on `ItemAssignmentCard`**: When an item is smart-assigned, show a small confidence badge next to the item name:

```
┌──────────────────────────────────────────────────────────┐
│  Milk 2%                        💡 Suggested      $4.29 │
│  ─────────────────────────────────────────────────────── │
│  Assign to                                               │
│  [ ✅ Rohan ] [ Krutin ] [ Nihar ]                       │
│                                                          │
│  Per person:                                      $4.29  │
└──────────────────────────────────────────────────────────┘
```

The badge shows the `PatternConfidence.displayLabel` ("Suggested", "Usually", "Always") with the corresponding `PatternConfidence.iconName` SF Symbol. The badge colour:

- **Likely** (💡): `Color.orange.opacity(0.8)` — subtle, tentative
- **Strong** (🧠): `Color.blue.opacity(0.8)` — confident
- **Very Strong** (🧠): `Color.green.opacity(0.8)` — highly confident

The badge is purely informational — it doesn't affect functionality. When the user manually modifies the assignment (toggling any participant), the badge disappears (item removed from `smartAssignedItemIds`).

**Toolbar toggle**: Add a toggle in the toolbar menu to enable/disable smart suggestions:

```swift
Menu {
    // ... existing menu items ...

    Divider()

    Toggle("Smart Suggestions", isOn: $viewModel.smartSuggestionsEnabled)

    if !viewModel.smartAssignedItemIds.isEmpty {
        Button("Clear All Suggestions") {
            viewModel.clearSmartSuggestions()
        }
    }
} label: {
    Image(systemName: "ellipsis.circle")
}
```

When toggled off, `viewModel.clearSmartSuggestions()` is called and no further suggestions are loaded. Re-enabling triggers `viewModel.loadSmartSuggestions()`.

---

### 10. Bootstrapping — Learning from Existing History

When the feature is first deployed, users already have historical sessions with completed assignments. To avoid a cold start where zero patterns exist, implement a **one-time bootstrap** that retroactively learns patterns from existing history.

**File**: `SplitLens/Services/PatternLearningEngine.swift`

```swift
/// One-time bootstrap: retroactively learn patterns from all existing saved sessions.
/// Should be called once when the feature first activates (tracked via UserDefaults flag).
func bootstrapFromHistory(sessions: [ReceiptSession]) async throws {
    // Sort sessions by receiptDate ascending (oldest first) so patterns build chronologically
    let sorted = sessions.sorted { $0.receiptDate < $1.receiptDate }

    for session in sorted {
        try await learnPatterns(from: session, storeName: session.storeName)
    }
}
```

**Trigger**: In `DependencyContainer.init()` or on the first launch of `ItemAssignmentView`, check a `UserDefaults` flag:

```swift
private static let bootstrapKey = "smartAssignment.bootstrapCompleted"

func bootstrapIfNeeded() async {
    guard !UserDefaults.standard.bool(forKey: Self.bootstrapKey) else { return }

    do {
        let sessions = try await sessionStore.fetchAllSessions(limit: nil)
        try await patternLearningEngine.bootstrapFromHistory(sessions: sessions)
        UserDefaults.standard.set(true, forKey: Self.bootstrapKey)
    } catch {
        ErrorHandler.shared.log(error, context: "PatternLearningEngine.bootstrap")
        // Don't set the flag — retry on next launch
    }
}
```

**Edge case**: Existing sessions have `storeName == nil` (the field didn't exist before). Bootstrap learns these as global patterns (store-agnostic). Once the user scans new receipts with store names, store-specific patterns will take priority.

---

### 11. Retroactive Pattern Learning from History Detail

Since sessions saved before this feature will lack `storeName`, and the user may view history sessions in `SessionDetailView`, do **not** attempt to retrofit `storeName` onto existing sessions. The field will naturally populate as users create new sessions.

---

### 12. Edge Cases & Behaviour Details

| Scenario | Expected Behaviour |
|---|---|
| **First ever session (no history)** | No patterns exist → no suggestions → normal manual assignment. After this session is saved, patterns are created with `consecutiveHits = 1`. |
| **Second session, same items + same people** | Patterns are updated to `consecutiveHits = 2` → now suggestable. |
| **Third session, same items + same people** | Suggestions appear! Items are pre-assigned. User confirms and moves on. |
| **Item assigned to different person than pattern** | Pattern's `consecutiveHits` resets to 1 with the new assignee. The old streak is broken. |
| **Item assigned to "All" (all participants)** | Pattern is **not** learned — shared-by-everyone items are not meaningful signals. |
| **Item appears but is left unassigned** | Session isn't saved unless all items are assigned, so this can't happen in practice. The `validate()` check ensures all items are assigned before proceeding. |
| **Same item at two different stores** | Two separate patterns are created (store-specific). If Krutin buys "Milk" at Walmart and Rohan buys "Milk" at Costco, both patterns coexist. The correct one is suggested based on `storeName`. |
| **Same item, no store name** | A global (store-agnostic) pattern is created. It applies everywhere unless a store-specific pattern with higher confidence exists. |
| **Pattern suggests a person not in this session** | Suggestion is suppressed entirely. If "Milk" → "Rohan" but Rohan isn't a participant in this session, no suggestion is shown. |
| **Pattern suggests multiple people, one is missing** | Suggestion is suppressed (partial suggestions are confusing). The item remains unassigned for manual handling. |
| **OCR produces a slightly different item name** | Fuzzy matching (Levenshtein ≥ 80%) accounts for OCR variations. "MILK 2%" matches "Milk 2% Gal" if similarity exceeds threshold. |
| **User disables smart suggestions** | All pre-applied suggestions are cleared. Items revert to unassigned. No suggestions are loaded until re-enabled. |
| **User taps "Undo All" on the suggestion banner** | Same as disabling — all smart assignments are cleared, items revert to unassigned. The toggle remains on for future sessions. |
| **User manually changes one smart-assigned item** | Only that item loses its "smart" badge. Other smart assignments are unaffected. |
| **500 pattern cap reached** | Oldest patterns (by `lastSeenAt`) are evicted first. A background cleanup task runs during `learnPatterns()`. |
| **Pattern data becomes corrupted (decode failure)** | Individual corrupted patterns are logged and skipped. Other patterns continue to function. |
| **No `PatternStore` available (SwiftData failure)** | `InMemoryPatternStore` is used. Patterns are not persisted across app launches but work within the session. Smart Suggestions section is still shown — it just won't have historical data on cold start. |
| **Very large bill (50+ items)** | Pattern matching is O(items × patterns). With 500 max patterns and 50 items, this is 25,000 Levenshtein comparisons — fast enough on-device (< 50ms). |
| **Multiple items with same name on one bill** | Each item has a unique `UUID`. Patterns are keyed by normalised name, not UUID. Both items receive the same suggestion. |

---

### 13. Settings & User Control

While the primary interaction is the toggle in `ItemAssignmentView`'s toolbar menu, consider adding a small section in the app's settings (if one exists) or in `HomeView` for power users:

#### 13a. Smart Assignment Settings (Future / Optional)

A lightweight settings section accessible from `HomeView` or a new `SettingsView`:

- **Toggle**: "Smart Suggestions" — master on/off (persisted in `UserDefaults`).
- **Info text**: "SplitLens learns who usually buys which items and suggests assignments automatically."
- **"Clear All Learned Patterns"**: Red destructive button that calls `patternStore.deleteAllPatterns()`. Confirmation alert: "This will erase all learned assignment patterns. SplitLens will start learning from scratch."
- **Pattern count**: Small footnote — "12 patterns learned" (from `patternStore.patternCount()`).

This is **optional** for the initial implementation. The toolbar toggle on `ItemAssignmentView` is sufficient for v1. The settings screen is a polish item for a later iteration.

---

### 14. File Change Summary

| Action | File | What Changes |
|---|---|---|
| **CREATE** | `SplitLens/Models/AssignmentPattern.swift` | New model: `AssignmentPattern`, `PatternConfidence`, `SuggestedAssignment` structs/enums. |
| **CREATE** | `SplitLens/Persistence/StoredPattern.swift` | New SwiftData `@Model`: `StoredPattern`. |
| **CREATE** | `SplitLens/Persistence/PatternStore.swift` | New protocol `PatternStoreProtocol`, implementations `SwiftDataPatternStore` and `InMemoryPatternStore`, error enum `PatternStoreError`. |
| **CREATE** | `SplitLens/Services/PatternLearningEngine.swift` | New service: `PatternLearningEngineProtocol` protocol + `PatternLearningEngine` implementation with `learnPatterns()`, `suggestAssignments()`, `bootstrapFromHistory()`, and normalisation utilities. |
| **MODIFY** | `SplitLens/Models/ScanMetadata.swift` | Add `storeName: String?` property to carry store name through the nav flow. |
| **MODIFY** | `SplitLens/Models/ReceiptSession.swift` | Add `storeName: String?` property, update `CodingKeys` (`store_name`), update `init(from:)`/`encode(to:)`, update `init()` default, update sample data. |
| **MODIFY** | `SplitLens/ViewModels/ImageUploadViewModel+OCR.swift` | Pass `storeName` from `StructuredReceiptData` into `ScanMetadata` when building post-OCR metadata. |
| **MODIFY** | `SplitLens/ViewModels/AssignmentViewModel.swift` | Add `suggestions`, `suggestionsLoaded`, `smartAssignedItemIds`, `smartSuggestionsEnabled` properties. Add `loadSmartSuggestions()`, `clearSmartSuggestions()`, `isSmartAssigned()`, `suggestion(for:)` methods. Update `toggleAssignment()` to remove smart badge on manual change. Update `init()` to accept pattern engine + store name. |
| **MODIFY** | `SplitLens/ViewModels/ReportViewModel.swift` | After `saveSession()`, call `patternLearningEngine.learnPatterns()`. Add bootstrap check on first launch. |
| **MODIFY** | `SplitLens/Views/ItemAssignmentView.swift` | Add `.task` for loading suggestions. Add suggestion banner (dismissible, with "Undo All"). Pass `storeName` from `ScanMetadata` to `AssignmentViewModel`. Add smart suggestion toggle + "Clear All Suggestions" to toolbar menu. Pass `scanMetadata.storeName` to `ReceiptSession` in `calculateSplits()`. |
| **MODIFY** | `SplitLens/Views/ItemAssignmentView.swift` (`ItemAssignmentCard`) | Add confidence badge next to item name for smart-assigned items. |
| **MODIFY** | `SplitLens/Services/DependencyContainer.swift` | Add `patternStore` and `patternLearningEngine` properties. Register `StoredPattern.self` in `ModelContainer`. Wire up `PatternLearningEngine`. |
| **MODIFY** | `SplitLens/Utilities/Constants.swift` | Add `AppConstants.SmartAssignment` enum with thresholds and limits. |
| **ADD TO PROJECT** | `SplitLens.xcodeproj/project.pbxproj` | Register all new `.swift` files in the Xcode project. |

---

### 15. Testing Requirements

#### Unit Tests

**File**: `SplitLensTests/AssignmentPatternTests.swift` (new)

1. **`testPatternCreation`** — create pattern with valid data; verify all properties.
2. **`testIsSuggestable`** — verify `isSuggestable` returns `false` for `consecutiveHits < 2`, `true` for `>= 2`.
3. **`testConfidenceLevels`** — verify `confidence` maps correctly: 0–1 → `.none`, 2 → `.likely`, 3–4 → `.strong`, 5+ → `.veryStrong`.
4. **`testIsStale`** — pattern with `lastSeenAt` 91 days ago → `isStale == true`; 89 days ago → `false`.
5. **`testCodableRoundTrip`** — encode → decode → assert equality, including optional `storeName`.
6. **`testPatternEquality`** — same id → equal; different id → not equal.
7. **`testParticipantLabel`** — verify formatting for 1, 2, 3+ participants.

**File**: `SplitLensTests/PatternStoreTests.swift` (new)

1. **`testSaveAndFetchPattern`** — save a pattern, fetch suggestable patterns, verify it appears when `consecutiveHits >= 2`.
2. **`testFetchExcludesLowConfidence`** — save pattern with `consecutiveHits = 1`, verify it's excluded from suggestable results.
3. **`testFetchExcludesStalePatterns`** — save pattern with `lastSeenAt` 91 days ago, verify it's excluded.
4. **`testFetchPatternByItemAndStore`** — save pattern, fetch by exact `normalizedItemName` + `normalizedStoreName`, verify match.
5. **`testDeletePattern`** — save, delete, verify gone.
6. **`testCleanupStalePatterns`** — save patterns with varying `lastSeenAt`, call cleanup, verify only those >180 days are deleted.
7. **`testPatternCountLimit`** — save 501 patterns, verify oldest is evicted or error is raised.
8. **`testDeleteAllPatterns`** — save several, delete all, verify empty.

**File**: `SplitLensTests/PatternLearningEngineTests.swift` (new)

1. **`testLearnNewPattern`** — first session with "Milk" → "Rohan". Verify pattern created with `consecutiveHits = 1`, `isSuggestable == false`.
2. **`testLearnConsecutivePattern`** — two sessions with "Milk" → "Rohan". After second, verify `consecutiveHits = 2`, `isSuggestable == true`.
3. **`testPatternResetsOnDifferentAssignment`** — session 1: "Milk" → "Rohan"; session 2: "Milk" → "Krutin". Verify `consecutiveHits` resets to 1 with new assignee.
4. **`testPatternNotLearnedForAllAssignment`** — item assigned to all participants → verify no pattern is created.
5. **`testSuggestAssignments`** — create suggestable pattern for "Milk" → "Rohan", call `suggestAssignments` with a list containing "Milk". Verify suggestion returned.
6. **`testSuggestionSuppressedWhenParticipantMissing`** — pattern suggests "Rohan", but "Rohan" isn't in the participant list → no suggestion returned.
7. **`testStoreSpecificPriority`** — create a global pattern "Milk" → "Rohan" (`consecutiveHits = 3`) and a store-specific pattern "Milk" → "Krutin" at "Walmart" (`consecutiveHits = 2`). Query with `storeName = "Walmart"` → verify store-specific pattern wins.
8. **`testFuzzyNameMatching`** — create pattern for "milk 2% gal", query with item named "MILK 2%GAL" → verify match (Levenshtein similarity > 80%).
9. **`testNormalizeItemName`** — test various inputs: "  MILK 2% GAL  " → "milk 2% gal", "Cookies—Choc*Chip" → "cookies choc chip", etc.
10. **`testNormalizeStoreName`** — test various inputs: "WALMART SUPERCENTER #4523" → "walmart supercenter", "Walmart Inc." → "walmart", etc.
11. **`testBootstrapFromHistory`** — pass 3 sessions with consistent "Milk" → "Rohan". After bootstrap, verify pattern has `consecutiveHits = 3`.
12. **`testBootstrapChronologicalOrder`** — pass sessions out of order (by date). Verify bootstrap sorts by date and builds patterns correctly.

**File**: `SplitLensTests/AssignmentViewModelSmartTests.swift` (new)

1. **`testLoadSmartSuggestionsAppliesAssignments`** — mock engine returns suggestions, call `loadSmartSuggestions()`, verify items are pre-assigned and `smartAssignedItemIds` is populated.
2. **`testManualToggleRemovesSmartBadge`** — after smart assignment, toggle a participant on the same item → verify item removed from `smartAssignedItemIds`.
3. **`testClearSmartSuggestions`** — apply suggestions, then clear → verify all items reverted to unassigned and `smartAssignedItemIds` is empty.
4. **`testSmartSuggestionsDisabled`** — set `smartSuggestionsEnabled = false`, call `loadSmartSuggestions()` → verify no suggestions applied.
5. **`testSuggestionSkippedForAlreadyAssignedItems`** — manually assign an item before loading suggestions → verify that item is skipped by smart suggestions.
6. **`testHapticFeedbackOnSuggestion`** — verify `HapticFeedback.shared.lightImpact()` is called when suggestions are applied (mock haptic).

---

### 16. Acceptance Criteria

- [ ] After two consecutive sessions where "Milk" is assigned to "Rohan", the third session auto-assigns "Milk" to "Rohan" on the `ItemAssignmentView` screen.
- [ ] Smart-assigned items show a confidence badge ("Suggested", "Usually", or "Always") next to the item name.
- [ ] The user can tap any participant chip to override a smart suggestion; the badge disappears on that item.
- [ ] A dismissible banner shows "N items auto-assigned based on your past splits" when suggestions are applied.
- [ ] The banner includes an "Undo All" action that clears all smart assignments.
- [ ] The toolbar menu includes a "Smart Suggestions" toggle and a "Clear All Suggestions" option.
- [ ] Patterns are only learned from completed, saved sessions (not abandoned flows).
- [ ] Items assigned to all participants ("All") do not generate patterns.
- [ ] Store-specific patterns take priority over global patterns when a store name is available.
- [ ] Fuzzy name matching handles OCR variations (e.g., "MILK 2% GAL" matches "milk 2% gal").
- [ ] Suggestions are suppressed when the suggested participant(s) are not in the current session.
- [ ] `storeName` from OCR is threaded through `ScanMetadata` → `ReceiptSession` and persisted.
- [ ] First-time install with existing history triggers a one-time bootstrap that retroactively learns patterns.
- [ ] Stale patterns (>90 days) are excluded from suggestions; ancient patterns (>180 days) are cleaned up.
- [ ] Pattern storage is capped at 500 entries.
- [ ] New `PatternStore` uses the shared `ModelContainer` (alongside `StoredSession` and `StoredGroup`).
- [ ] Smart suggestions degrade gracefully if SwiftData fails (no crash, no suggestions, manual assignment works normally).
- [ ] All new and modified unit tests pass.
- [ ] All existing tests continue to pass (no regressions).

---

### 17. Design Language

Match the existing app aesthetic throughout:

- **Suggestion banner**: `RoundedRectangle(cornerRadius: 12)`, background `Color.orange.opacity(0.1)` with a `Color.orange.opacity(0.6)` left accent bar (4pt wide). Uses `lightbulb.fill` SF Symbol. Dismiss button is a small `xmark.circle.fill`.
- **Confidence badge on `ItemAssignmentCard`**: Inline capsule — `HStack { Image(systemName: icon) Text(label) }` wrapped in `.padding(.horizontal, 8).padding(.vertical, 4)` with rounded background. Colours vary by confidence level (see §9b).
- **Typography**: SF Pro — badge text at 11pt semibold (`.caption` weight), banner title at 14pt bold, banner subtitle at 12pt regular.
- **Animations**: `.spring(response: 0.35, dampingFraction: 0.7)` for banner appear/dismiss. Confidence badge uses `.easeInOut(duration: 0.2)` on appear.
- **Icons**: SF Symbols — `lightbulb.fill` for likely, `brain.fill` for strong, `brain.head.profile.fill` for very strong, `xmark.circle.fill` for dismiss, `arrow.uturn.backward` for undo.

---

### 18. Implementation Order (Suggested)

1. **Phase 1 — Data layer**: Create `AssignmentPattern` model → `StoredPattern` SwiftData model → `PatternStore` protocol + `SwiftDataPatternStore` + `InMemoryPatternStore` → add `AppConstants.SmartAssignment` → write unit tests for model + store.
2. **Phase 2 — Thread `storeName`**: Add `storeName` to `ScanMetadata` → add `storeName` to `ReceiptSession` (with `CodingKeys`, custom `init(from:)`) → populate from `ImageUploadViewModel+OCR.swift` → pass through to `ItemAssignmentView.calculateSplits()`.
3. **Phase 3 — Pattern learning engine**: Create `PatternLearningEngine` with `learnPatterns()` and `suggestAssignments()` → implement normalisation utilities → implement fuzzy matching → wire into `DependencyContainer` → write engine unit tests.
4. **Phase 4 — Session save integration**: Modify `ReportViewModel.saveSession()` to call `learnPatterns()` after save → implement bootstrap from history → write integration tests.
5. **Phase 5 — Assignment screen integration**: Modify `AssignmentViewModel` with smart suggestion properties/methods → modify `ItemAssignmentView` with `.task`, banner, confidence badges, toolbar toggle → write ViewModel unit tests.
6. **Phase 6 — Polish**: Animations, edge case testing, performance profiling (fuzzy matching speed), stale pattern cleanup, manual QA on device with real receipts.

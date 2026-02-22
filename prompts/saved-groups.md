# Feature Prompt: Saved Groups — Reusable Participant Groups for Faster Bill Splitting

## Overview

Introduce **Saved Groups** — a feature that lets users create, manage, and instantly load named groups of participants (e.g. "Roommates", "Work Lunch Crew", "Travel Squad") so they never have to retype the same names session after session. A group is selected with a single tap on the `ParticipantsEntryView` screen, instantly populating the participants list.

---

## Why This Matters

Every bill-splitting session today requires manually typing each person's name, one at a time. For users who regularly split with the same people — roommates, coworkers, friend circles — this is pure friction that makes the app feel slower than it should. This is **the** most impactful quality-of-life improvement with relatively low implementation effort.

**Concrete example**: Krutin splits bills with roommates Rohan and Nihar multiple times a week. Today, he types "Krutin", taps add, types "Rohan", taps add, types "Nihar", taps add — every single time. With Saved Groups, he creates a group called "Roomies" once, and from then on, a single tap on "Roomies" populates all three names instantly.

---

## Existing Architecture Reference

Read and understand these files before implementing:

| Layer | File(s) | What It Does |
|---|---|---|
| **View** | `SplitLens/Views/ParticipantsEntryView.swift` | The screen where users manually type and add participant names, select a payer, then navigate to tax/tip allocation or item assignment. **This is the primary screen affected.** |
| **ViewModel** | `SplitLens/ViewModels/ParticipantsViewModel.swift` | Manages participant list, payer selection, validation. Has `addParticipant()`, `addMultipleParticipants()`, `removeParticipant()`, duplicate detection (case-insensitive), min 2 participants requirement. |
| **Navigation** | `Navigation/Route.swift` | `Route.participantsEntry([ReceiptItem], [Fee], ScanMetadata)` — the route that opens the participants screen. A new `.groupManagement` route will be needed. |
| **Navigation** | `SplitLens/Views/HomeView.swift` | Home screen with `NavigationStack`. The `routeDestination(for:)` switch maps routes to views. The group management screen should be accessible from here. |
| **Persistence** | `SplitLens/Persistence/SessionStore.swift` | `SwiftDataSessionStore` — uses SwiftData `ModelContainer`/`ModelContext` for JSON-encoded session storage. Follow the same persistence pattern for groups. |
| **Persistence** | `SplitLens/Persistence/StoredSession.swift` | SwiftData `@Model` class. Shows the pattern: `@Attribute(.unique) var id: UUID`, typed stored properties for query/sort, plus a `payloadData: Data` blob for the full JSON. |
| **DI** | `SplitLens/Services/DependencyContainer.swift` | Singleton wiring all services. A new `GroupStoreProtocol` must be registered here. |
| **Models** | `SplitLens/Models/ReceiptSession.swift` | Domain model — stores `participants: [String]`. Groups are a separate concept but produce the same `[String]` output. |
| **Constants** | `SplitLens/Utilities/Constants.swift` | `AppConstants` enum with nested enums per feature area. Add a `Groups` section here. |
| **Components** | `SplitLens/Views/Components/` | Reusable UI components — `EmptyStateView`, `SummaryCard`, `ActionButton`, `ParticipantChip`, etc. New group-related components live here. |
| **Utilities** | `SplitLens/Utilities/HapticFeedback.swift` | Provides `.mediumImpact()`, `.lightImpact()`, `.success()`, `.error()`. Use for group selection feedback. |

---

## Detailed Requirements

### 1. Data Model — `ParticipantGroup`

Create a new model representing a saved group of people.

**File**: `SplitLens/Models/ParticipantGroup.swift`

```swift
/// A named, reusable group of participant names
struct ParticipantGroup: Identifiable, Codable, Equatable {
    /// Unique identifier
    var id: UUID = UUID()

    /// User-chosen group name (e.g. "Roommates", "Work Lunch Crew")
    var name: String

    /// Ordered list of participant names in this group
    var members: [String]

    /// Optional SF Symbol icon name for visual identity
    var iconName: String

    /// When this group was created
    var createdAt: Date = Date()

    /// When this group was last used to populate participants
    var lastUsedAt: Date?

    /// Number of times this group has been used
    var usageCount: Int = 0
}
```

**Constraints:**

- `name`: 1–30 characters, trimmed, unique across all groups (case-insensitive).
- `members`: 2–20 members. Each member name follows the same rules as `ParticipantsViewModel.addParticipant()` — trimmed, 1–50 characters, no duplicates within the group (case-insensitive).
- `iconName`: Defaults to `"person.3.fill"`. Provide a small curated list of ~8 icons the user can choose from (e.g. `"person.3.fill"`, `"house.fill"`, `"briefcase.fill"`, `"fork.knife"`, `"airplane"`, `"heart.fill"`, `"star.fill"`, `"flag.fill"`).

**Computed properties:**

```swift
/// Formatted member count (e.g. "3 members")
var memberCountLabel: String

/// Comma-separated member preview (e.g. "Krutin, Rohan, Nihar")
/// Truncates to first 3 names + "+ N more" if > 3 members
var memberPreview: String

/// First letters of up to 3 members, used for avatar display
var avatarLetters: [String]
```

### 2. Persistence — `GroupStore`

Follow the exact same persistence pattern as `SessionStore` / `StoredSession`.

#### 2a. SwiftData Model

**File**: `SplitLens/Persistence/StoredGroup.swift`

```swift
@Model
final class StoredGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var memberCount: Int
    var createdAt: Date
    var lastUsedAt: Date?
    var usageCount: Int
    var payloadData: Data

    init(
        id: UUID,
        name: String,
        memberCount: Int,
        createdAt: Date,
        lastUsedAt: Date?,
        usageCount: Int,
        payloadData: Data
    ) { ... }
}
```

Indexed fields (`name`, `createdAt`, `lastUsedAt`, `usageCount`) are stored as top-level properties for sorting/filtering. The full `ParticipantGroup` is JSON-encoded in `payloadData`.

#### 2b. Store Protocol & Implementation

**File**: `SplitLens/Persistence/GroupStore.swift`

```swift
protocol GroupStoreProtocol {
    /// Save a new or updated group
    func saveGroup(_ group: ParticipantGroup) async throws

    /// Fetch all groups, sorted by most recently used (then by creation date)
    func fetchAllGroups() async throws -> [ParticipantGroup]

    /// Delete a group by ID
    func deleteGroup(id: UUID) async throws

    /// Update the lastUsedAt and usageCount when a group is selected
    func recordGroupUsage(id: UUID) async throws
}
```

**Implementation**: `SwiftDataGroupStore` — mirrors `SwiftDataSessionStore` pattern. Use the same `ModelContainer` instance (register `StoredGroup.self` alongside `StoredSession.self` in the container schema).

**Fallback**: `InMemoryGroupStore` — same pattern as `InMemorySessionStore`, for when SwiftData fails to initialise.

**Error handling**: `GroupStoreError` enum mirroring `SessionStoreError` — `.notFound`, `.persistenceFailed(String)`, `.decodeFailed(String)`, `.duplicateName(String)`.

### 3. Dependency Injection

**File**: `SplitLens/Services/DependencyContainer.swift`

Add a new property:

```swift
/// Saved participant groups store
let groupStore: GroupStoreProtocol
```

Initialise it alongside `sessionStore`:

```swift
do {
    let container = try ModelContainer(for: StoredSession.self, StoredGroup.self)
    self.sessionStore = try SwiftDataSessionStore(modelContainer: container)
    self.groupStore = try SwiftDataGroupStore(modelContainer: container)
} catch {
    ErrorHandler.shared.log(error, context: "DependencyContainer.SwiftData")
    self.sessionStore = InMemorySessionStore()
    self.groupStore = InMemoryGroupStore()
}
```

**Important**: Both stores must share the same `ModelContainer` to avoid SwiftData conflicts. Refactor `DependencyContainer.init()` so the `ModelContainer` is created once and passed to both stores.

### 4. Constants

**File**: `SplitLens/Utilities/Constants.swift`

Add a new nested enum:

```swift
/// Constants related to saved participant groups
enum Groups {
    /// Maximum number of saved groups allowed
    static let maxGroups: Int = 20

    /// Maximum members per group
    static let maxMembersPerGroup: Int = 20

    /// Minimum members to form a group
    static let minMembersPerGroup: Int = 2

    /// Maximum characters for a group name
    static let maxGroupNameLength: Int = 30

    /// Available icon choices for group customisation
    static let availableIcons: [String] = [
        "person.3.fill",
        "house.fill",
        "briefcase.fill",
        "fork.knife",
        "airplane",
        "heart.fill",
        "star.fill",
        "flag.fill"
    ]
}
```

### 5. Group Management Screen

This is a standalone screen for creating, editing, and deleting groups, accessible from the home screen.

#### 5a. Navigation Route

**File**: `Navigation/Route.swift`

Add a new route case:

```swift
case groupManagement
```

Register it in `HomeView.routeDestination(for:)`:

```swift
case .groupManagement:
    GroupManagementView(navigationPath: $navigationPath)
```

#### 5b. ViewModel

**File**: `SplitLens/ViewModels/GroupManagementViewModel.swift`

```swift
@MainActor
final class GroupManagementViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var groups: [ParticipantGroup] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let groupStore: GroupStoreProtocol

    init(groupStore: GroupStoreProtocol) { ... }

    // MARK: - Actions

    /// Load all groups from store
    func loadGroups() async { ... }

    /// Delete a group
    func deleteGroup(_ group: ParticipantGroup) async { ... }

    /// Delete groups at index set offsets (for swipe-to-delete)
    func deleteGroups(at offsets: IndexSet) async { ... }
}
```

#### 5c. View

**File**: `SplitLens/Views/GroupManagementView.swift`

**Layout:**

```
┌─────────────────────────────────────────────────────────────┐
│  ← Groups                                          + (add) │
│─────────────────────────────────────────────────────────────│
│                                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  👥  Roomies                                    3 ppl  │ │
│  │      Krutin, Rohan, Nihar                        ✏️ 🗑 │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  💼  Work Lunch Crew                            5 ppl  │ │
│  │      Alice, Bob, Charlie + 2 more                ✏️ 🗑 │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┐ │
│  │  (empty state when no groups)                         │ │
│  │  👥 No saved groups yet                               │ │
│  │  Create a group to quickly add people to splits       │ │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Functionality:**

- **Navigation title**: "Groups"
- **Toolbar button** (top-trailing): "+" to present group creation sheet
- **Group row**: Shows icon, name, member count, member preview, edit and delete actions
- **Swipe-to-delete**: Standard swipe gesture on rows
- **Tap on row**: Opens the group editor sheet in edit mode (pre-filled)
- **Empty state**: Use existing `EmptyStateView` component with icon `"person.3.fill"` and appropriate message
- **Max groups enforcement**: When the user has `AppConstants.Groups.maxGroups` groups, the "+" button is disabled and a subtle banner indicates the limit

#### 5d. Group Editor Sheet

**File**: `SplitLens/Views/GroupEditorSheet.swift`

A modal sheet for creating a new group or editing an existing one.

**Layout:**

```
┌─────────────────────────────────────────────────────────────┐
│  Cancel          New Group                          Save    │
│─────────────────────────────────────────────────────────────│
│                                                             │
│  Group Name                                                 │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Roomies                                                ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  Icon                                                       │
│  [ 👥 ] [ 🏠 ] [ 💼 ] [ 🍴 ] [ ✈️ ] [ ❤️ ] [ ⭐ ] [ 🏳️ ] │
│                                                             │
│  Members                                                    │
│  ┌─────────────────────────────────────────┐  ┌──────────┐ │
│  │  Enter name                             │  │  + Add   │ │
│  └─────────────────────────────────────────┘  └──────────┘ │
│                                                             │
│  🔵 K  Krutin                                        ✕     │
│  🔵 R  Rohan                                         ✕     │
│  🔵 N  Nihar                                         ✕     │
│                                                             │
│  ⚠️ Add at least 2 members to create a group               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Functionality:**

- **Mode**: `.create` or `.edit(ParticipantGroup)`. Title adjusts: "New Group" / "Edit Group"
- **Group name field**: Text field with 30-char limit. Validates non-empty and uniqueness on save
- **Icon picker**: Horizontal row of icon bubbles. Tapping one selects it (highlighted ring). Default: `"person.3.fill"`
- **Member entry**: Text field + "Add" button — identical interaction pattern to `ParticipantsEntryView.addParticipantSection`. Re-use the exact same styling (rounded rect, plus-circle button, etc.)
- **Member list**: Same visual treatment as `ParticipantsEntryView.participantsList` — avatar circle with first letter, name, remove (×) button. Same spring animations on add/remove
- **Validation**: 
  - Group name must be 1–30 characters
  - Group name must be unique (case-insensitive) across existing groups (allow same name when editing the same group)
  - At least `AppConstants.Groups.minMembersPerGroup` members required
  - No duplicate member names (case-insensitive) within the group
  - Member names follow same rules as `ParticipantsViewModel.addParticipant()` — trimmed, 1–50 chars
- **Save button**: Disabled until validation passes. On save, calls `groupStore.saveGroup()` and dismisses the sheet
- **Cancel button**: Dismisses without saving. If there are unsaved changes, show a confirmation alert: "Discard changes?"
- **Edit mode**: Pre-populates all fields. Save updates the existing group (same UUID)

#### 5e. Group Editor ViewModel

**File**: `SplitLens/ViewModels/GroupEditorViewModel.swift`

```swift
@MainActor
final class GroupEditorViewModel: ObservableObject {
    enum Mode {
        case create
        case edit(ParticipantGroup)
    }

    // MARK: - Published Properties

    @Published var groupName: String = ""
    @Published var selectedIcon: String = "person.3.fill"
    @Published var members: [String] = []
    @Published var newMemberName: String = ""
    @Published var errorMessage: String?
    @Published var isSaving: Bool = false

    // MARK: - Properties

    let mode: Mode
    private let groupStore: GroupStoreProtocol
    private let existingGroupNames: [String]  // for uniqueness checks

    // MARK: - Computed

    var navigationTitle: String { ... }  // "New Group" or "Edit Group"
    var saveButtonTitle: String { ... }   // "Create" or "Save"
    var isValid: Bool { ... }
    var hasUnsavedChanges: Bool { ... }
    func validate() -> [String] { ... }

    // MARK: - Actions

    func addMember() { ... }          // Same validation logic as ParticipantsViewModel
    func removeMember(_ name: String) { ... }
    func saveGroup() async throws { ... }
}
```

### 6. Home Screen Entry Point

**File**: `SplitLens/Views/HomeView.swift`

Add a third `HomeActionButton` below the existing "History" button:

```swift
// Groups button
HomeActionButton(
    icon: "person.3.fill",
    title: "Groups",
    subtitle: "Manage saved groups",
    gradient: [Color.teal, Color.teal.opacity(0.8)]
) {
    navigationPath.append(Route.groupManagement)
}
```

This sits naturally alongside "New Scan" and "History" as the three primary actions on the home screen.

### 7. ParticipantsEntryView Integration — The Core UX Win

This is the centrepiece of the feature: making groups visible and one-tap-selectable on the participants screen.

#### 7a. Saved Groups Section

**File**: `SplitLens/Views/ParticipantsEntryView.swift`

Add a **"Saved Groups"** section between the `SummaryCard` and the `addParticipantSection`. This section appears only when the user has at least one saved group.

**Layout:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Total Bill: $65.96                        │
│─────────────────────────────────────────────────────────────│
│                                                             │
│  Saved Groups                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ 👥 Roomies   │  │ 💼 Work Crew │  │ + New Group  │      │
│  │ 3 members    │  │ 5 members    │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                             │
│  Add Participants                                           │
│  ┌──────────────────────────────────┐  ┌────┐              │
│  │  Enter name                      │  │ +  │              │
│  └──────────────────────────────────┘  └────┘              │
│                                                             │
│  People (3)                                          ✅     │
│  🔵 K  Krutin                                   ✕          │
│  🔵 R  Rohan                                    ✕          │
│  🔵 N  Nihar                                    ✕          │
│                                                             │
│  Who Paid?                                                  │
│  [ Krutin ] [ Rohan ] [ Nihar ]                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Group Chip Design:**

Each saved group appears as a compact, tappable chip in a horizontal `ScrollView`:

```swift
/// A chip representing a saved group, tappable to load its members
struct GroupChip: View {
    let group: ParticipantGroup
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: group.iconName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(group.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
                Text(group.memberCountLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color.blue.opacity(0.15)
                    : Color(.secondarySystemBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
```

**File**: `SplitLens/Views/Components/GroupChip.swift`

At the end of the horizontal scroll, add a "+ New Group" chip that opens the `GroupEditorSheet` inline — allowing users to create a group without leaving the flow.

#### 7b. Group Selection Behaviour

When a user taps a group chip:

1. **Haptic feedback**: `HapticFeedback.shared.lightImpact()`
2. **Chip highlights**: The tapped chip gets a blue selection ring; previously selected chip de-selects
3. **Participant merge logic**: The group's members are **merged** into the current participant list:
   - Members already in the list (case-insensitive match) are skipped — no duplicates
   - New members are appended in the group's member order
   - existing manually-added participants that are NOT in the group are **kept** (not removed!)
4. **Animation**: Use `.spring()` animation matching the existing participant list transition
5. **Auto-payer**: If the list was empty before selecting the group, auto-select the first member as payer (matching existing `ParticipantsViewModel` logic)

**Why merge, not replace?** The user might have already added some people manually and then tap a group to quickly add the remaining regulars. Replacing would be destructive and frustrating.

**De-selecting a group chip**: Tapping an already-selected chip should de-select it visually but **NOT** remove the participants that were added from it. Once participants are in the list, they are individually managed — removal is always explicit (tap ×). This avoids confusion about which names "belong to" a group vs were manually added.

#### 7c. ViewModel Changes

**File**: `SplitLens/ViewModels/ParticipantsViewModel.swift`

Add the following:

```swift
// MARK: - Group Support

/// Currently loaded groups, set by the view
@Published var savedGroups: [ParticipantGroup] = []

/// ID of the currently selected group (for visual highlighting only)
@Published var selectedGroupId: UUID?

/// Loads a saved group's members into the participant list (merge logic)
func loadGroup(_ group: ParticipantGroup) {
    selectedGroupId = group.id

    for member in group.members {
        let trimmed = member.trimmingCharacters(in: .whitespacesAndNewlines)
        // Skip if already present (case-insensitive)
        guard !participants.contains(where: {
            $0.lowercased() == trimmed.lowercased()
        }) else { continue }

        participants.append(trimmed)
    }

    // Auto-select payer if not yet set
    if paidBy.isEmpty, let first = participants.first {
        paidBy = first
    }

    errorMessage = nil
}

/// Checks if a group is currently selected
func isGroupSelected(_ group: ParticipantGroup) -> Bool {
    selectedGroupId == group.id
}
```

The existing `addParticipant()`, `removeParticipant()`, `addMultipleParticipants()` methods remain unchanged. Group loading is just a convenience wrapper around the same add logic with extra duplicate-skipping.

#### 7d. View Integration

**File**: `SplitLens/Views/ParticipantsEntryView.swift`

Add a `@State` or dependency-injected `groupStore` to load groups on appear:

```swift
@Environment(\.dependencies) private var dependencies
@State private var savedGroups: [ParticipantGroup] = []
@State private var showGroupEditor = false
```

In the `body`, between the `SummaryCard` and `addParticipantSection`:

```swift
// Saved groups section (only if groups exist)
if !savedGroups.isEmpty {
    savedGroupsSection
        .padding(.horizontal)
}
```

On `.task`:

```swift
.task {
    do {
        savedGroups = try await dependencies.groupStore.fetchAllGroups()
    } catch {
        // Silently fail — groups are a convenience, not critical
    }
}
```

The `savedGroupsSection` computed property:

```swift
private var savedGroupsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Saved Groups")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.primary)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(savedGroups) { group in
                    GroupChip(
                        group: group,
                        isSelected: viewModel.isGroupSelected(group)
                    ) {
                        HapticFeedback.shared.lightImpact()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            viewModel.loadGroup(group)
                        }
                        // Record usage for sorting purposes
                        Task {
                            try? await dependencies.groupStore.recordGroupUsage(id: group.id)
                        }
                    }
                }

                // "+ New Group" chip at the end
                Button(action: { showGroupEditor = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("New")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundStyle(.secondary)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    .sheet(isPresented: $showGroupEditor) {
        GroupEditorSheet(mode: .create, groupStore: dependencies.groupStore) {
            // Refresh groups after creation
            Task {
                savedGroups = (try? await dependencies.groupStore.fetchAllGroups()) ?? savedGroups
            }
        }
    }
}
```

If no groups exist yet, show nothing in this section — the user creates groups from `GroupManagementView` on the home screen or from the "+ New" chip that appears after their first group. But to **bootstrap discoverability**, when `savedGroups.isEmpty`, show a minimal one-line hint **above** the "Add Participants" header:

```
💡 Tip: Create a group from the home screen to quickly add regulars
```

This hint should be dismissible (show once, store a `UserDefaults` flag) so it doesn't nag repeat users.

### 8. Edge Cases & Behaviour Details

| Scenario | Expected Behaviour |
|---|---|
| **User taps group, then manually removes a member** | Member is removed from the participants list normally. Group chip remains visually selected (it's a highlight, not a state binding). |
| **User taps group, then adds someone not in the group** | The new person is appended below the group members. Group chip remains selected. |
| **User taps Group A, then taps Group B** | Group B chip highlights, Group A de-highlights. Group B members are merged in — any from Group A already present are kept, new ones added. The result is the union of both groups' members plus any manually added names. |
| **Group has a member named "Alice" and user already added "alice"** | Case-insensitive duplicate detected — "Alice" from the group is skipped, existing "alice" stays. |
| **User creates a group with 0–1 members** | Validation prevents save. Show error: "Groups need at least 2 members." |
| **User tries to create a 21st group** | "+" button disabled. Info message: "You've reached the group limit (20). Delete a group to create a new one." |
| **User deletes a group from GroupManagementView** | Group disappears. If that group was visible on a ParticipantsEntryView that's still in the navigation stack, it gracefully disappears on next appear (re-fetch). Participants already loaded from that group remain in the list. |
| **User edits a group (renames or changes members)** | Existing sessions are NOT retroactively affected — groups are used at selection time only, not as live references. |
| **User navigates back from participants, then returns** | Groups re-fetch on `.task`. If they changed, the new list is shown. `selectedGroupId` resets (no group is pre-selected on fresh entry). |
| **No saved groups, first-time user** | "Saved Groups" section is entirely hidden. The hint about creating groups appears once. |
| **Group store fails (SwiftData error)** | Silent fallback — section hidden, no error shown to user. Groups are a convenience feature, not critical path. |

### 9. Sort Order for Groups

Groups should be sorted by **most recently used first**, then by creation date (newest first) as a tiebreaker. This ensures the groups users rely on most frequently appear at the leftmost position in the horizontal scroll, minimising scroll distance.

On `ParticipantsEntryView`, limit the visible group chips to **6** — additional groups are accessible via `GroupManagementView`. Add a "See all (N)" chip at the end if there are more than 6 groups.

### 10. File Change Summary

| Action | File | What Changes |
|---|---|---|
| **CREATE** | `SplitLens/Models/ParticipantGroup.swift` | New model: `ParticipantGroup` struct. |
| **CREATE** | `SplitLens/Persistence/StoredGroup.swift` | New SwiftData `@Model`: `StoredGroup`. |
| **CREATE** | `SplitLens/Persistence/GroupStore.swift` | New protocol `GroupStoreProtocol`, implementations `SwiftDataGroupStore` and `InMemoryGroupStore`. |
| **CREATE** | `SplitLens/ViewModels/GroupManagementViewModel.swift` | ViewModel for group list screen. |
| **CREATE** | `SplitLens/ViewModels/GroupEditorViewModel.swift` | ViewModel for create/edit group sheet. |
| **CREATE** | `SplitLens/Views/GroupManagementView.swift` | Full-screen group list with CRUD. |
| **CREATE** | `SplitLens/Views/GroupEditorSheet.swift` | Modal sheet for creating/editing a group. |
| **CREATE** | `SplitLens/Views/Components/GroupChip.swift` | Reusable group chip component. |
| **MODIFY** | `Navigation/Route.swift` | Add `.groupManagement` route case + `Hashable`/`Equatable` handling. |
| **MODIFY** | `SplitLens/Views/HomeView.swift` | Add "Groups" `HomeActionButton` + route destination. |
| **MODIFY** | `SplitLens/Views/ParticipantsEntryView.swift` | Add saved groups horizontal section, group loading, sheet for inline creation. |
| **MODIFY** | `SplitLens/ViewModels/ParticipantsViewModel.swift` | Add `savedGroups`, `selectedGroupId`, `loadGroup()`, `isGroupSelected()`. |
| **MODIFY** | `SplitLens/Services/DependencyContainer.swift` | Add `groupStore` property, shared `ModelContainer` for both stores. |
| **MODIFY** | `SplitLens/Utilities/Constants.swift` | Add `AppConstants.Groups` enum with limits and icon list. |
| **ADD TO PROJECT** | `SplitLens.xcodeproj/project.pbxproj` | Register all new `.swift` files. |

### 11. Testing Requirements

#### Unit Tests

**File**: `SplitLensTests/ParticipantGroupTests.swift` (new)

1. **`testGroupCreation`** — create group with valid name, members, icon; verify properties.
2. **`testMemberPreviewTruncation`** — verify `memberPreview` shows max 3 names + "+ N more".
3. **`testMemberCountLabel`** — verify singular ("1 member") vs plural ("3 members") — though min is 2, test the computed property.
4. **`testCodableRoundTrip`** — encode → decode → assert equality.
5. **`testGroupEquality`** — two groups with same id are equal, different ids are not.

**File**: `SplitLensTests/GroupStoreTests.swift` (new)

1. **`testSaveAndFetchGroup`** — save a group, fetch all, verify it appears.
2. **`testFetchSortOrder`** — save 3 groups, use one, verify most recently used is first.
3. **`testDeleteGroup`** — save, delete, verify gone.
4. **`testUpdateGroup`** — save, modify members, save again with same ID, verify update.
5. **`testRecordUsage`** — use a group, verify `lastUsedAt` and `usageCount` updated.

**File**: `SplitLensTests/ParticipantsViewModelTests.swift` (new or extend)

1. **`testLoadGroupMergesMembers`** — add "Alice" manually, load group with ["Bob", "Charlie"], verify all 3 present.
2. **`testLoadGroupSkipsDuplicates`** — add "alice", load group with ["Alice", "Bob"], verify 2 participants (not 3), original "alice" casing preserved.
3. **`testLoadGroupAutoSelectsPayer`** — start empty, load group, verify paidBy is first member.
4. **`testLoadGroupKeepsExistingPayer`** — add "Alice", set payer "Alice", load group with ["Bob", "Charlie"], verify payer still "Alice".
5. **`testLoadMultipleGroupsMerges`** — load Group A, then Group B, verify union of all members with no duplicates.
6. **`testDeselectGroupDoesNotRemoveParticipants`** — load group, deselect, verify participants remain.

**File**: `SplitLensTests/GroupEditorViewModelTests.swift` (new)

1. **`testValidationEmpty`** — empty name → validation error.
2. **`testValidationDuplicateName`** — name matches existing group → error.
3. **`testValidationTooFewMembers`** — only 1 member → error.
4. **`testValidationDuplicateMember`** — adding "Alice" twice → error.
5. **`testEditModePrePopulates`** — init with `.edit(group)` → fields match group data.
6. **`testHasUnsavedChanges`** — modify a field → `hasUnsavedChanges` is true.

### 12. Acceptance Criteria

- [ ] A "Groups" button on `HomeView` navigates to `GroupManagementView`.
- [ ] `GroupManagementView` displays all saved groups sorted by recent usage, supports create, edit, and delete.
- [ ] `GroupEditorSheet` validates group name (unique, 1–30 chars), members (2–20, no duplicates), and icon selection.
- [ ] `ParticipantsEntryView` shows a horizontal "Saved Groups" section when groups exist.
- [ ] Tapping a group chip instantly populates the participants list with the group's members (merged, no duplicates).
- [ ] Existing manually-added participants are preserved when a group is loaded.
- [ ] A "+ New" chip at the end of the groups row opens an inline group creation sheet.
- [ ] A first-time hint is shown when no groups exist, dismissible and shown only once.
- [ ] Group selection records usage for sort ordering.
- [ ] The groups horizontal list shows max 6 chips + "See all" overflow.
- [ ] Navigating away and back re-fetches groups correctly.
- [ ] All validation (name length, member count, duplicates, max groups) works correctly with user-facing error messages.
- [ ] Haptic feedback fires on group selection and group save.
- [ ] Shared `ModelContainer` between `SessionStore` and `GroupStore` works without conflict.
- [ ] All unit tests pass.
- [ ] The feature degrades gracefully if SwiftData fails (groups section hidden, no crash).

### 13. Design Language

Match the existing app aesthetic:

- **Group chips**: `RoundedRectangle(cornerRadius: 12)`, `Color(.secondarySystemBackground)`, selection ring in `Color.blue` with 2pt stroke.
- **Group management rows**: Same card style as `participantsList` in `ParticipantsEntryView` — `.ultraThinMaterial` over `Color(.secondarySystemBackground)`, 12–14pt corner radius.
- **Group editor sheet**: Standard `.sheet` presentation. Form-style layout matching the add-participant UI of `ParticipantsEntryView`.
- **Typography**: SF Pro — titles at 18pt bold, body at 16pt medium, captions at 12–13pt.
- **Colours**: Teal gradient for the home screen "Groups" button. Blue for selected state. Standard system colours elsewhere.
- **Animations**: `.spring(response: 0.35, dampingFraction: 0.7)` for list mutations (matching existing participant list transitions).
- **Icons**: SF Symbols — `person.3.fill` as the default group icon.

### 14. Implementation Order (Suggested)

1. **Phase 1 — Data layer**: Create `ParticipantGroup` model → `StoredGroup` SwiftData model → `GroupStore` protocol + `SwiftDataGroupStore` + `InMemoryGroupStore` → wire into `DependencyContainer` (shared `ModelContainer`) → add `AppConstants.Groups` → write unit tests for model + store.
2. **Phase 2 — Group management screen**: Create `GroupManagementViewModel` → `GroupManagementView` → `GroupEditorViewModel` → `GroupEditorSheet` → add `.groupManagement` route → add home screen button → write unit tests for ViewModels.
3. **Phase 3 — Participants integration**: Add `GroupChip` component → modify `ParticipantsViewModel` with group loading → modify `ParticipantsEntryView` with groups section → write integration unit tests.
4. **Phase 4 — Polish**: First-time hint with UserDefaults → "See all" overflow chip → haptic feedback → animations → edge case testing → manual QA on device.

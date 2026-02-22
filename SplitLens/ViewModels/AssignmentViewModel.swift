//
//  AssignmentViewModel.swift
//  SplitLens
//
//  ViewModel for assigning items to participants
//

import Foundation
import SwiftUI

@MainActor
final class AssignmentViewModel: ObservableObject {

    // MARK: - Published Properties

    /// List of items to assign
    @Published var items: [ReceiptItem]

    /// List of participants
    @Published var participants: [String]

    /// Name of the person who paid the bill
    @Published var paidBy: String

    /// Current item being assigned (for focused editing)
    @Published var currentItemIndex: Int = 0

    /// Error message for display
    @Published var errorMessage: String?

    // MARK: - Smart Assignment Published Properties

    /// Whether smart suggestions have been loaded
    @Published var suggestionsLoaded: Bool = false

    /// Whether smart suggestions feature is enabled
    @Published var smartSuggestionsEnabled: Bool = true

    /// Map from item UUID to its suggested assignment
    @Published var suggestions: [UUID: SuggestedAssignment] = [:]

    /// Set of item IDs that were auto-assigned by smart suggestions (not manually touched)
    @Published var smartAssignedItemIds: Set<UUID> = []

    /// Whether smart suggestions are currently loading
    @Published var isLoadingSuggestions: Bool = false

    // MARK: - Dependencies

    private let billSplitEngine: BillSplitEngineProtocol
    private let patternLearningEngine: PatternLearningEngineProtocol?
    private let storeName: String?

    // MARK: - Computed Properties

    /// Current item being assigned
    var currentItem: ReceiptItem? {
        guard items.indices.contains(currentItemIndex) else { return nil }
        return items[currentItemIndex]
    }

    /// Number of unassigned items
    var unassignedItemCount: Int {
        items.filter { !$0.isAssigned }.count
    }

    /// Whether all items are assigned
    var allItemsAssigned: Bool {
        unassignedItemCount == 0
    }

    /// Progress percentage (0-100)
    var assignmentProgress: Double {
        guard !items.isEmpty else { return 0 }
        let assigned = items.count - unassignedItemCount
        return Double(assigned) / Double(items.count) * 100
    }

    /// Preview of split calculations
    var splitPreview: [String: Double] {
        var totals: [String: Double] = [:]

        for participant in participants {
            totals[participant] = 0.0
        }

        for item in items {
            for person in item.assignedTo {
                totals[person, default: 0.0] += item.pricePerPerson
            }
        }

        return totals
    }

    /// Number of items with active smart suggestions applied
    var smartSuggestedCount: Int {
        smartAssignedItemIds.count
    }

    /// Whether any smart suggestions are currently applied
    var hasSmartSuggestions: Bool {
        !smartAssignedItemIds.isEmpty
    }

    // MARK: - Initialization

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

    // MARK: - Assignment Methods

    /// Assigns current item to a participant
    func assignCurrentItem(to participant: String) {
        guard var item = currentItem else { return }
        item.assign(to: participant)
        updateCurrentItem(with: item)
        errorMessage = nil
    }

    /// Unassigns current item from a participant
    func unassignCurrentItem(from participant: String) {
        guard var item = currentItem else { return }
        item.unassign(from: participant)
        updateCurrentItem(with: item)
    }

    /// Toggles assignment of current item for a participant
    func toggleAssignment(for participant: String) {
        guard var item = currentItem else { return }
        item.toggleAssignment(for: participant)
        updateCurrentItem(with: item)
    }

    /// Toggles assignment for any item — also removes smart badge for that item
    func toggleAssignment(itemId: UUID, participant: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        var item = items[index]
        item.toggleAssignment(for: participant)
        items[index] = item
        // Manual edit invalidates smart badge
        smartAssignedItemIds.remove(itemId)
    }

    /// Assigns an item to a participant
    func assignItem(_ itemId: UUID, to participant: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        var item = items[index]
        item.assign(to: participant)
        items[index] = item
    }

    /// Unassigns an item from a participant
    func unassignItem(_ itemId: UUID, from participant: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        var item = items[index]
        item.unassign(from: participant)
        items[index] = item
    }

    // MARK: - Navigation

    /// Moves to the next item
    func nextItem() {
        if currentItemIndex < items.count - 1 {
            currentItemIndex += 1
        }
    }

    /// Moves to the previous item
    func previousItem() {
        if currentItemIndex > 0 {
            currentItemIndex -= 1
        }
    }

    /// Jumps to a specific item
    func goToItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        currentItemIndex = index
    }

    /// Jumps to the next unassigned item
    func goToNextUnassignedItem() {
        // Start from current + 1
        for index in (currentItemIndex + 1)..<items.count {
            if !items[index].isAssigned {
                currentItemIndex = index
                return
            }
        }

        // Wrap around to beginning
        for index in 0..<currentItemIndex {
            if !items[index].isAssigned {
                currentItemIndex = index
                return
            }
        }
    }

    // MARK: - Bulk Operations

    /// Assigns all items equally to all participants
    func splitEquallyAllItems() {
        for index in items.indices {
            items[index].assignedTo = participants
            smartAssignedItemIds.remove(items[index].id)
        }
    }

    /// Clears all assignments
    func clearAllAssignments() {
        for index in items.indices {
            items[index].assignedTo = []
        }
        smartAssignedItemIds.removeAll()
    }

    /// Assigns all items to a single participant
    func assignAllItems(to participant: String) {
        for index in items.indices {
            items[index].assignedTo = [participant]
            smartAssignedItemIds.remove(items[index].id)
        }
    }

    // MARK: - Smart Assignment Methods

    /// Loads smart suggestions from the pattern learning engine and applies them to unassigned items
    func loadSmartSuggestions() async {
        guard smartSuggestionsEnabled else { return }
        guard let engine = patternLearningEngine else { return }
        guard !suggestionsLoaded else { return }

        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }

        do {
            let rawSuggestions = try await engine.suggestAssignments(
                for: items,
                participants: participants,
                storeName: storeName
            )

            suggestions = rawSuggestions
            suggestionsLoaded = true

            // Apply suggestions only to items that are currently unassigned
            for (itemId, suggestion) in rawSuggestions {
                guard let index = items.firstIndex(where: { $0.id == itemId }) else { continue }
                guard !items[index].isAssigned else { continue }
                items[index].assignedTo = suggestion.participants
                smartAssignedItemIds.insert(itemId)
            }

            if !smartAssignedItemIds.isEmpty {
                HapticFeedback.shared.lightImpact()
            }
        } catch {
            ErrorHandler.shared.log(error, context: "AssignmentViewModel.loadSmartSuggestions")
            suggestionsLoaded = true
        }
    }

    /// Clears all smart suggestions and reverts smart-assigned items to unassigned
    func clearSmartSuggestions() {
        for itemId in smartAssignedItemIds {
            if let index = items.firstIndex(where: { $0.id == itemId }) {
                items[index].assignedTo = []
            }
        }
        smartAssignedItemIds.removeAll()
        suggestions.removeAll()
    }

    /// Returns the suggestion for a given item, if any
    func suggestion(for itemId: UUID) -> SuggestedAssignment? {
        guard smartAssignedItemIds.contains(itemId) else { return nil }
        return suggestions[itemId]
    }

    /// Whether a given item was auto-assigned by smart suggestions
    func isSmartAssigned(_ itemId: UUID) -> Bool {
        smartAssignedItemIds.contains(itemId)
    }

    // MARK: - Validation

    /// Validates assignments
    func validate() -> [String] {
        var errors: [String] = []

        if participants.isEmpty {
            errors.append("No participants available")
        }

        if items.isEmpty {
            errors.append("No items to assign")
        }

        if !allItemsAssigned {
            errors.append("\(unassignedItemCount) item(s) not assigned yet")
        }

        return errors
    }

    /// Whether assignments are valid
    var isValid: Bool {
        validate().isEmpty
    }

    // MARK: - Helper Methods

    private func updateCurrentItem(with item: ReceiptItem) {
        guard items.indices.contains(currentItemIndex) else { return }
        items[currentItemIndex] = item
    }

    /// Gets total owed by a participant
    func totalOwed(by participant: String) -> Double {
        splitPreview[participant] ?? 0.0
    }

    /// Formatted total for participant
    func formattedTotal(for participant: String) -> String {
        CurrencyFormatter.shared.format(totalOwed(by: participant))
    }
}

// MARK: - Quick Fill Support

extension AssignmentViewModel {
    /// Assigns items based on simple heuristics (for quick testing)
    func autoAssign() {
        guard !participants.isEmpty else { return }

        // Distribute items round-robin
        for (index, _) in items.enumerated() {
            let participantIndex = index % participants.count
            items[index].assignedTo = [participants[participantIndex]]
        }
    }
}

//
//  AssignmentViewModelSmartTests.swift
//  SplitLensTests
//

import XCTest
@testable import SplitLens

// MARK: - Mock Pattern Learning Engine

final class MockPatternLearningEngine: PatternLearningEngineProtocol {
    var suggestionsToReturn: [UUID: SuggestedAssignment] = [:]
    var learnCallCount = 0
    var suggestCallCount = 0

    func learnPatterns(from session: ReceiptSession, storeName: String?) async throws {
        learnCallCount += 1
    }

    func suggestAssignments(
        for items: [ReceiptItem],
        participants: [String],
        storeName: String?
    ) async throws -> [UUID: SuggestedAssignment] {
        suggestCallCount += 1
        return suggestionsToReturn
    }

    func bootstrapFromHistory(sessions: [ReceiptSession]) async throws {}
}

// MARK: - Tests

@MainActor
final class AssignmentViewModelSmartTests: XCTestCase {

    private var mockEngine: MockPatternLearningEngine!
    private var viewModel: AssignmentViewModel!
    private let participants = ["Rohan", "Krutin"]

    override func setUp() {
        super.setUp()
        mockEngine = MockPatternLearningEngine()
    }

    // MARK: - testLoadSmartSuggestionsAppliesAssignments

    func testLoadSmartSuggestionsAppliesAssignments() async throws {
        let item = ReceiptItem(id: UUID(), name: "Milk", quantity: 1, price: 4.99, assignedTo: [])
        let suggestion = SuggestedAssignment(
            participants: ["Rohan"],
            confidence: .likely,
            sourcePatternId: UUID(),
            isStoreSpecific: false
        )
        mockEngine.suggestionsToReturn = [item.id: suggestion]

        viewModel = AssignmentViewModel(
            items: [item],
            participants: participants,
            paidBy: "Rohan",
            patternLearningEngine: mockEngine
        )

        await viewModel.loadSmartSuggestions()

        XCTAssertTrue(viewModel.suggestionsLoaded)
        XCTAssertTrue(viewModel.smartAssignedItemIds.contains(item.id))
        XCTAssertEqual(viewModel.items[0].assignedTo, ["Rohan"])
    }

    // MARK: - testManualToggleRemovesSmartBadge

    func testManualToggleRemovesSmartBadge() async throws {
        let item = ReceiptItem(id: UUID(), name: "Milk", quantity: 1, price: 4.99, assignedTo: [])
        let suggestion = SuggestedAssignment(
            participants: ["Rohan"],
            confidence: .likely,
            sourcePatternId: UUID(),
            isStoreSpecific: false
        )
        mockEngine.suggestionsToReturn = [item.id: suggestion]

        viewModel = AssignmentViewModel(
            items: [item],
            participants: participants,
            paidBy: "Rohan",
            patternLearningEngine: mockEngine
        )

        await viewModel.loadSmartSuggestions()
        XCTAssertTrue(viewModel.smartAssignedItemIds.contains(item.id))

        viewModel.toggleAssignment(itemId: item.id, participant: "Krutin")
        XCTAssertFalse(viewModel.smartAssignedItemIds.contains(item.id))
    }

    // MARK: - testClearSmartSuggestions

    func testClearSmartSuggestions() async throws {
        let item = ReceiptItem(id: UUID(), name: "Milk", quantity: 1, price: 4.99, assignedTo: [])
        let suggestion = SuggestedAssignment(
            participants: ["Rohan"],
            confidence: .likely,
            sourcePatternId: UUID(),
            isStoreSpecific: false
        )
        mockEngine.suggestionsToReturn = [item.id: suggestion]

        viewModel = AssignmentViewModel(
            items: [item],
            participants: participants,
            paidBy: "Rohan",
            patternLearningEngine: mockEngine
        )

        await viewModel.loadSmartSuggestions()
        XCTAssertEqual(viewModel.items[0].assignedTo, ["Rohan"])

        viewModel.clearSmartSuggestions()
        XCTAssertTrue(viewModel.smartAssignedItemIds.isEmpty)
        XCTAssertTrue(viewModel.suggestions.isEmpty)
        XCTAssertEqual(viewModel.items[0].assignedTo, [])
    }

    // MARK: - testSmartSuggestionsDisabled

    func testSmartSuggestionsDisabled() async throws {
        let item = ReceiptItem(id: UUID(), name: "Milk", quantity: 1, price: 4.99, assignedTo: [])
        let suggestion = SuggestedAssignment(
            participants: ["Rohan"],
            confidence: .likely,
            sourcePatternId: UUID(),
            isStoreSpecific: false
        )
        mockEngine.suggestionsToReturn = [item.id: suggestion]

        viewModel = AssignmentViewModel(
            items: [item],
            participants: participants,
            paidBy: "Rohan",
            patternLearningEngine: mockEngine
        )
        viewModel.smartSuggestionsEnabled = false

        await viewModel.loadSmartSuggestions()

        XCTAssertTrue(viewModel.smartAssignedItemIds.isEmpty)
        XCTAssertEqual(mockEngine.suggestCallCount, 0)
    }

    // MARK: - testSuggestionSkippedForAlreadyAssignedItems

    func testSuggestionSkippedForAlreadyAssignedItems() async throws {
        let item = ReceiptItem(id: UUID(), name: "Milk", quantity: 1, price: 4.99, assignedTo: ["Krutin"])
        let suggestion = SuggestedAssignment(
            participants: ["Rohan"],
            confidence: .likely,
            sourcePatternId: UUID(),
            isStoreSpecific: false
        )
        mockEngine.suggestionsToReturn = [item.id: suggestion]

        viewModel = AssignmentViewModel(
            items: [item],
            participants: participants,
            paidBy: "Rohan",
            patternLearningEngine: mockEngine
        )

        await viewModel.loadSmartSuggestions()

        // Item was already assigned — smart suggestion should not override it
        XCTAssertFalse(viewModel.smartAssignedItemIds.contains(item.id))
        XCTAssertEqual(viewModel.items[0].assignedTo, ["Krutin"])
    }
}

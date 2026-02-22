//
//  PatternLearningEngineTests.swift
//  SplitLensTests
//

import XCTest
@testable import SplitLens

final class PatternLearningEngineTests: XCTestCase {

    private var store: InMemoryPatternStore!
    private var engine: PatternLearningEngine!

    override func setUp() {
        super.setUp()
        store = InMemoryPatternStore()
        engine = PatternLearningEngine(patternStore: store)
    }

    // MARK: - testLearnNewPattern

    func testLearnNewPattern() async throws {
        let session = makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])])
        try await engine.learnPatterns(from: session, storeName: nil)

        let patterns = try await store.fetchPatterns(forItem: "milk")
        XCTAssertEqual(patterns.count, 1)
        XCTAssertEqual(patterns[0].consecutiveHits, 1)
        XCTAssertFalse(patterns[0].isSuggestable)
    }

    // MARK: - testLearnConsecutivePattern

    func testLearnConsecutivePattern() async throws {
        let session = makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])])
        try await engine.learnPatterns(from: session, storeName: nil)
        try await engine.learnPatterns(from: session, storeName: nil)

        let patterns = try await store.fetchPatterns(forItem: "milk")
        XCTAssertEqual(patterns[0].consecutiveHits, 2)
        XCTAssertTrue(patterns[0].isSuggestable)
    }

    // MARK: - testPatternResetsOnDifferentAssignment

    func testPatternResetsOnDifferentAssignment() async throws {
        let session1 = makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])])
        let session2 = makeSession(items: [makeItem(name: "Milk", assignees: ["Krutin"])])

        try await engine.learnPatterns(from: session1, storeName: nil)
        try await engine.learnPatterns(from: session1, storeName: nil)
        // consecutiveHits is now 2
        try await engine.learnPatterns(from: session2, storeName: nil)
        // Assignment changed — should reset to 1 with new assignee

        let patterns = try await store.fetchPatterns(forItem: "milk")
        XCTAssertEqual(patterns[0].consecutiveHits, 1)
        XCTAssertEqual(patterns[0].assignedParticipants, ["Krutin"])
    }

    // MARK: - testPatternNotLearnedForAllAssignment

    func testPatternNotLearnedForAllAssignment() async throws {
        let participants = ["Rohan", "Krutin", "Nihar"]
        let item = makeItem(name: "Pizza", assignees: participants)
        let session = makeSession(items: [item], participants: participants)

        try await engine.learnPatterns(from: session, storeName: nil)

        let patterns = try await store.fetchPatterns(forItem: "pizza")
        XCTAssertTrue(patterns.isEmpty)
    }

    // MARK: - testSuggestAssignments

    func testSuggestAssignments() async throws {
        let session = makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])])
        try await engine.learnPatterns(from: session, storeName: nil)
        try await engine.learnPatterns(from: session, storeName: nil)

        let unassignedItem = makeItem(name: "Milk", assignees: [])
        let suggestions = try await engine.suggestAssignments(
            for: [unassignedItem],
            participants: ["Rohan", "Krutin"],
            storeName: nil
        )

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[unassignedItem.id]?.participants, ["Rohan"])
    }

    // MARK: - testSuggestionSuppressedWhenParticipantMissing

    func testSuggestionSuppressedWhenParticipantMissing() async throws {
        let session = makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])])
        try await engine.learnPatterns(from: session, storeName: nil)
        try await engine.learnPatterns(from: session, storeName: nil)

        let unassignedItem = makeItem(name: "Milk", assignees: [])
        // "Rohan" is NOT in participants list
        let suggestions = try await engine.suggestAssignments(
            for: [unassignedItem],
            participants: ["Krutin", "Nihar"],
            storeName: nil
        )

        XCTAssertTrue(suggestions.isEmpty)
    }

    // MARK: - testStoreSpecificPriority

    func testStoreSpecificPriority() async throws {
        // Global pattern: Milk → Rohan, hits=3
        let globalSession = makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])])
        for _ in 0..<3 {
            try await engine.learnPatterns(from: globalSession, storeName: nil)
        }

        // Store-specific pattern: Milk → Krutin at Walmart, hits=2
        let walmartSession = makeSession(items: [makeItem(name: "Milk", assignees: ["Krutin"])])
        for _ in 0..<2 {
            try await engine.learnPatterns(from: walmartSession, storeName: "Walmart")
        }

        let unassignedItem = makeItem(name: "Milk", assignees: [])
        let suggestions = try await engine.suggestAssignments(
            for: [unassignedItem],
            participants: ["Rohan", "Krutin"],
            storeName: "Walmart"
        )

        // Store-specific should win
        XCTAssertEqual(suggestions[unassignedItem.id]?.participants, ["Krutin"])
        XCTAssertTrue(suggestions[unassignedItem.id]?.isStoreSpecific == true)
    }

    // MARK: - testFuzzyNameMatching

    func testFuzzyNameMatching() async throws {
        // Store pattern with normalised name
        let session = makeSession(items: [makeItem(name: "milk 2% gal", assignees: ["Rohan"])])
        try await engine.learnPatterns(from: session, storeName: nil)
        try await engine.learnPatterns(from: session, storeName: nil)

        // Query with slightly different OCR output
        let item = makeItem(name: "MILK 2%GAL", assignees: [])
        let similarity = PatternLearningEngine.levenshteinSimilarity(
            PatternLearningEngine.normalizeItemName(item.name),
            "milk 2% gal"
        )
        XCTAssertGreaterThanOrEqual(similarity, AppConstants.SmartAssignment.nameSimilarityThreshold)

        let suggestions = try await engine.suggestAssignments(
            for: [item],
            participants: ["Rohan"],
            storeName: nil
        )
        XCTAssertFalse(suggestions.isEmpty)
    }

    // MARK: - testNormalizeItemName

    func testNormalizeItemName() {
        XCTAssertEqual(PatternLearningEngine.normalizeItemName("  MILK 2% GAL  "), "milk 2% gal")
        XCTAssertEqual(PatternLearningEngine.normalizeItemName("Cookies*Choc Chip"), "cookies choc chip")
        XCTAssertEqual(PatternLearningEngine.normalizeItemName("Cookies-Choc Chip"), "cookies choc chip")
        XCTAssertEqual(PatternLearningEngine.normalizeItemName("MILK_2%"), "milk 2%")
        XCTAssertEqual(PatternLearningEngine.normalizeItemName("Item  With   Extra  Spaces"), "item with extra spaces")
    }

    // MARK: - testNormalizeStoreName

    func testNormalizeStoreName() {
        XCTAssertEqual(PatternLearningEngine.normalizeStoreName("WALMART SUPERCENTER #4523"), "walmart supercenter")
        XCTAssertEqual(PatternLearningEngine.normalizeStoreName("Walmart Inc."), "walmart")
        XCTAssertEqual(PatternLearningEngine.normalizeStoreName("WAL-MART"), "walmart")
    }

    // MARK: - testBootstrapFromHistory

    func testBootstrapFromHistory() async throws {
        let sessions = [
            makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])]),
            makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])]),
            makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])])
        ]

        try await engine.bootstrapFromHistory(sessions: sessions)

        let patterns = try await store.fetchPatterns(forItem: "milk")
        XCTAssertEqual(patterns[0].consecutiveHits, 3)
    }

    // MARK: - testBootstrapChronologicalOrder

    func testBootstrapChronologicalOrder() async throws {
        // Build sessions with different dates (out of order)
        let base = Date()
        var s1 = makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])])
        s1.receiptDate = base.addingTimeInterval(-200)
        var s2 = makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])])
        s2.receiptDate = base.addingTimeInterval(-100)
        var s3 = makeSession(items: [makeItem(name: "Milk", assignees: ["Rohan"])])
        s3.receiptDate = base.addingTimeInterval(-300)

        // Pass out of chronological order
        try await engine.bootstrapFromHistory(sessions: [s2, s1, s3])

        // Should sort by receiptDate and build consecutive hits = 3
        let patterns = try await store.fetchPatterns(forItem: "milk")
        XCTAssertEqual(patterns[0].consecutiveHits, 3)
    }

    // MARK: - Helpers

    private func makeItem(name: String, assignees: [String]) -> ReceiptItem {
        ReceiptItem(id: UUID(), name: name, quantity: 1, price: 4.99, assignedTo: assignees)
    }

    private func makeSession(
        items: [ReceiptItem],
        participants: [String] = ["Rohan", "Krutin"]
    ) -> ReceiptSession {
        ReceiptSession(
            participants: participants,
            totalAmount: 20.0,
            paidBy: "Rohan",
            items: items
        )
    }
}

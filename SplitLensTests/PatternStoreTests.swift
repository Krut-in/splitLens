//
//  PatternStoreTests.swift
//  SplitLensTests
//

import XCTest
@testable import SplitLens

final class PatternStoreTests: XCTestCase {

    private var store: InMemoryPatternStore!

    override func setUp() {
        super.setUp()
        store = InMemoryPatternStore()
    }

    // MARK: - testSaveAndFetchPattern

    func testSaveAndFetchPattern() async throws {
        let pattern = makePattern(name: "milk", hits: 2)
        try await store.savePattern(pattern)

        let suggestable = try await store.fetchSuggestablePatterns(storeName: nil)
        XCTAssertEqual(suggestable.count, 1)
        XCTAssertEqual(suggestable[0].normalizedItemName, "milk")
    }

    // MARK: - testFetchExcludesLowConfidence

    func testFetchExcludesLowConfidence() async throws {
        let pattern = makePattern(name: "milk", hits: 1)
        try await store.savePattern(pattern)

        let suggestable = try await store.fetchSuggestablePatterns(storeName: nil)
        XCTAssertTrue(suggestable.isEmpty)
    }

    // MARK: - testFetchExcludesStalePatterns

    func testFetchExcludesStalePatterns() async throws {
        var pattern = makePattern(name: "milk", hits: 3)
        pattern.lastSeenAt = Date(timeIntervalSinceNow: -(91 * 24 * 60 * 60))
        try await store.savePattern(pattern)

        let suggestable = try await store.fetchSuggestablePatterns(storeName: nil)
        XCTAssertTrue(suggestable.isEmpty)
    }

    // MARK: - testFetchPatternByItemAndStore

    func testFetchPatternByItemAndStore() async throws {
        let pattern = makePattern(name: "milk", hits: 2, storeName: "walmart")
        try await store.savePattern(pattern)

        let found = try await store.fetchPattern(normalizedItemName: "milk", normalizedStoreName: "walmart")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.normalizedStoreName, "walmart")
    }

    // MARK: - testDeletePattern

    func testDeletePattern() async throws {
        let pattern = makePattern(name: "milk", hits: 2)
        try await store.savePattern(pattern)
        try await store.deletePattern(id: pattern.id)

        let count = try await store.patternCount()
        XCTAssertEqual(count, 0)
    }

    // MARK: - testCleanupStalePatterns

    func testCleanupStalePatterns() async throws {
        var stale = makePattern(name: "stale", hits: 3)
        stale.lastSeenAt = Date(timeIntervalSinceNow: -(181 * 24 * 60 * 60))
        let fresh = makePattern(name: "fresh", hits: 3)

        try await store.savePattern(stale)
        try await store.savePattern(fresh)

        let deleted = try await store.cleanupStalePatterns()
        XCTAssertEqual(deleted, 1)

        let count = try await store.patternCount()
        XCTAssertEqual(count, 1)
    }

    // MARK: - testDeleteAllPatterns

    func testDeleteAllPatterns() async throws {
        try await store.savePattern(makePattern(name: "a", hits: 2))
        try await store.savePattern(makePattern(name: "b", hits: 3))
        try await store.savePattern(makePattern(name: "c", hits: 4))

        try await store.deleteAllPatterns()
        let count = try await store.patternCount()
        XCTAssertEqual(count, 0)
    }

    // MARK: - testSavePatterns (batch)

    func testSavePatterns() async throws {
        let patterns = [
            makePattern(name: "a", hits: 2),
            makePattern(name: "b", hits: 3),
            makePattern(name: "c", hits: 5)
        ]
        try await store.savePatterns(patterns)
        let count = try await store.patternCount()
        XCTAssertEqual(count, 3)
    }

    // MARK: - Helpers

    private func makePattern(name: String, hits: Int, storeName: String? = nil) -> AssignmentPattern {
        AssignmentPattern(
            normalizedItemName: name,
            displayItemName: name.capitalized,
            normalizedStoreName: storeName,
            displayStoreName: storeName?.capitalized,
            assignedParticipants: ["Rohan"],
            consecutiveHits: hits
        )
    }
}

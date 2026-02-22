//
//  AssignmentPatternTests.swift
//  SplitLensTests
//

import XCTest
@testable import SplitLens

final class AssignmentPatternTests: XCTestCase {

    // MARK: - testPatternCreation

    func testPatternCreation() {
        let pattern = AssignmentPattern(
            normalizedItemName: "milk",
            displayItemName: "Milk",
            normalizedStoreName: "walmart",
            displayStoreName: "Walmart",
            assignedParticipants: ["Rohan"],
            consecutiveHits: 2
        )
        XCTAssertFalse(pattern.id.uuidString.isEmpty)
        XCTAssertEqual(pattern.normalizedItemName, "milk")
        XCTAssertEqual(pattern.displayItemName, "Milk")
        XCTAssertEqual(pattern.normalizedStoreName, "walmart")
        XCTAssertEqual(pattern.assignedParticipants, ["Rohan"])
        XCTAssertEqual(pattern.consecutiveHits, 2)
        XCTAssertEqual(pattern.totalOccurrences, 1)
    }

    // MARK: - testIsSuggestable

    func testIsSuggestable() {
        var pattern = makePattern(hits: 0)
        XCTAssertFalse(pattern.isSuggestable)

        pattern.consecutiveHits = 1
        XCTAssertFalse(pattern.isSuggestable)

        pattern.consecutiveHits = 2
        XCTAssertTrue(pattern.isSuggestable)

        pattern.consecutiveHits = 10
        XCTAssertTrue(pattern.isSuggestable)
    }

    // MARK: - testConfidenceLevels

    func testConfidenceLevels() {
        XCTAssertEqual(makePattern(hits: 0).confidence, .none)
        XCTAssertEqual(makePattern(hits: 1).confidence, .none)
        XCTAssertEqual(makePattern(hits: 2).confidence, .likely)
        XCTAssertEqual(makePattern(hits: 3).confidence, .strong)
        XCTAssertEqual(makePattern(hits: 4).confidence, .strong)
        XCTAssertEqual(makePattern(hits: 5).confidence, .veryStrong)
        XCTAssertEqual(makePattern(hits: 100).confidence, .veryStrong)
    }

    // MARK: - testIsStale

    func testIsStale() {
        var pattern = makePattern(hits: 2)
        pattern.lastSeenAt = Date(timeIntervalSinceNow: -(91 * 24 * 60 * 60))
        XCTAssertTrue(pattern.isStale)

        pattern.lastSeenAt = Date(timeIntervalSinceNow: -(89 * 24 * 60 * 60))
        XCTAssertFalse(pattern.isStale)
    }

    // MARK: - testCodableRoundTrip

    func testCodableRoundTrip() throws {
        let pattern = AssignmentPattern(
            normalizedItemName: "milk 2%",
            displayItemName: "Milk 2%",
            normalizedStoreName: "walmart",
            displayStoreName: "Walmart",
            assignedParticipants: ["Rohan", "Krutin"],
            consecutiveHits: 3
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(pattern)
        let decoded = try decoder.decode(AssignmentPattern.self, from: data)

        XCTAssertEqual(decoded.id, pattern.id)
        XCTAssertEqual(decoded.normalizedItemName, pattern.normalizedItemName)
        XCTAssertEqual(decoded.normalizedStoreName, pattern.normalizedStoreName)
        XCTAssertEqual(decoded.assignedParticipants, pattern.assignedParticipants)
        XCTAssertEqual(decoded.consecutiveHits, pattern.consecutiveHits)
    }

    // MARK: - testPatternEquality

    func testPatternEquality() {
        let p1 = makePattern(hits: 2)
        var p2 = p1
        XCTAssertEqual(p1, p2)

        p2.consecutiveHits = 5
        XCTAssertNotEqual(p1, p2)
    }

    // MARK: - testParticipantLabel

    func testParticipantLabel() {
        var pattern = makePattern(hits: 2)

        pattern.assignedParticipants = ["Rohan"]
        XCTAssertEqual(pattern.participantLabel, "Rohan")

        pattern.assignedParticipants = ["Rohan", "Krutin"]
        XCTAssertEqual(pattern.participantLabel, "Rohan, Krutin")

        pattern.assignedParticipants = ["Rohan", "Krutin", "Nihar"]
        XCTAssertEqual(pattern.participantLabel, "Rohan, Krutin + 1 more")
    }

    // MARK: - testIsStoreSpecific

    func testIsStoreSpecific() {
        var pattern = makePattern(hits: 2)
        pattern.normalizedStoreName = nil
        XCTAssertFalse(pattern.isStoreSpecific)

        pattern.normalizedStoreName = "walmart"
        XCTAssertTrue(pattern.isStoreSpecific)

        pattern.normalizedStoreName = ""
        XCTAssertFalse(pattern.isStoreSpecific)
    }

    // MARK: - Private Helpers

    private func makePattern(hits: Int) -> AssignmentPattern {
        AssignmentPattern(
            normalizedItemName: "milk",
            displayItemName: "Milk",
            normalizedStoreName: nil,
            displayStoreName: nil,
            assignedParticipants: ["Rohan"],
            consecutiveHits: hits
        )
    }
}

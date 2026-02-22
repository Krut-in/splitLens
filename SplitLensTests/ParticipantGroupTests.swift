//
//  ParticipantGroupTests.swift
//  SplitLensTests
//
//  Unit tests for the ParticipantGroup model.
//

import XCTest
@testable import SplitLens

final class ParticipantGroupTests: XCTestCase {

    // MARK: - testGroupCreation

    func testGroupCreation() {
        let group = ParticipantGroup(
            name: "Roomies",
            members: ["Krutin", "Rohan", "Nihar"],
            iconName: "house.fill"
        )

        XCTAssertEqual(group.name, "Roomies")
        XCTAssertEqual(group.members, ["Krutin", "Rohan", "Nihar"])
        XCTAssertEqual(group.iconName, "house.fill")
        XCTAssertEqual(group.usageCount, 0)
        XCTAssertNil(group.lastUsedAt)
    }

    // MARK: - testMemberPreviewTruncation

    func testMemberPreviewExactlyThree() {
        let group = ParticipantGroup(
            name: "G",
            members: ["A", "B", "C"],
            iconName: "person.3.fill"
        )
        XCTAssertEqual(group.memberPreview, "A, B, C")
    }

    func testMemberPreviewTruncation() {
        let group = ParticipantGroup(
            name: "G",
            members: ["Alice", "Bob", "Charlie", "Dave", "Eve"],
            iconName: "person.3.fill"
        )
        XCTAssertEqual(group.memberPreview, "Alice, Bob, Charlie + 2 more")
    }

    func testMemberPreviewTwoMembers() {
        let group = ParticipantGroup(
            name: "G",
            members: ["Alice", "Bob"],
            iconName: "person.3.fill"
        )
        XCTAssertEqual(group.memberPreview, "Alice, Bob")
    }

    // MARK: - testMemberCountLabel

    func testMemberCountLabelPlural() {
        let group = ParticipantGroup(
            name: "G",
            members: ["A", "B", "C"],
            iconName: "person.3.fill"
        )
        XCTAssertEqual(group.memberCountLabel, "3 members")
    }

    func testMemberCountLabelSingular() {
        // Even though min is 2, we test the computed property directly
        let group = ParticipantGroup(
            name: "G",
            members: ["A"],
            iconName: "person.3.fill"
        )
        XCTAssertEqual(group.memberCountLabel, "1 member")
    }

    // MARK: - testCodableRoundTrip

    func testCodableRoundTrip() throws {
        let original = ParticipantGroup(
            id: UUID(),
            name: "Work Lunch",
            members: ["Alice", "Bob"],
            iconName: "briefcase.fill",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            lastUsedAt: Date(timeIntervalSince1970: 2_000_000),
            usageCount: 5
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ParticipantGroup.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.members, original.members)
        XCTAssertEqual(decoded.iconName, original.iconName)
        XCTAssertEqual(decoded.usageCount, original.usageCount)
        XCTAssertNotNil(decoded.lastUsedAt)
    }

    // MARK: - testGroupEquality

    func testGroupEqualitySameId() {
        let id = UUID()
        let a = ParticipantGroup(id: id, name: "A", members: ["X", "Y"], iconName: "person.3.fill")
        let b = ParticipantGroup(id: id, name: "B", members: ["Z"], iconName: "house.fill")
        XCTAssertEqual(a, b, "Groups with same id should be equal regardless of other fields")
    }

    func testGroupEqualityDifferentId() {
        let a = ParticipantGroup(name: "A", members: ["X", "Y"], iconName: "person.3.fill")
        let b = ParticipantGroup(name: "A", members: ["X", "Y"], iconName: "person.3.fill")
        XCTAssertNotEqual(a, b, "Groups with different ids should not be equal")
    }

    // MARK: - testAvatarLetters

    func testAvatarLettersUpToThree() {
        let group = ParticipantGroup(
            name: "G",
            members: ["Alice", "Bob", "Charlie", "Dave"],
            iconName: "person.3.fill"
        )
        XCTAssertEqual(group.avatarLetters, ["A", "B", "C"])
    }

    func testAvatarLettersTwoMembers() {
        let group = ParticipantGroup(
            name: "G",
            members: ["Krutin", "Rohan"],
            iconName: "person.3.fill"
        )
        XCTAssertEqual(group.avatarLetters, ["K", "R"])
    }
}

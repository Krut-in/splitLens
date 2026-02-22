//
//  GroupStoreTests.swift
//  SplitLensTests
//
//  Unit tests for GroupStore implementations using InMemoryGroupStore.
//

import XCTest
@testable import SplitLens

final class GroupStoreTests: XCTestCase {

    private var store: InMemoryGroupStore!

    override func setUp() {
        super.setUp()
        store = InMemoryGroupStore()
    }

    // MARK: - testSaveAndFetchGroup

    func testSaveAndFetchGroup() async throws {
        let group = ParticipantGroup(
            name: "Roomies",
            members: ["Krutin", "Rohan"],
            iconName: "house.fill"
        )
        try await store.saveGroup(group)
        let groups = try await store.fetchAllGroups()

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].name, "Roomies")
        XCTAssertEqual(groups[0].members, ["Krutin", "Rohan"])
    }

    // MARK: - testFetchSortOrder

    func testFetchSortOrder() async throws {
        var groupA = ParticipantGroup(
            name: "A",
            members: ["X", "Y"],
            iconName: "person.3.fill",
            createdAt: Date(timeIntervalSinceNow: -200)
        )
        var groupB = ParticipantGroup(
            name: "B",
            members: ["X", "Y"],
            iconName: "person.3.fill",
            createdAt: Date(timeIntervalSinceNow: -100)
        )
        var groupC = ParticipantGroup(
            name: "C",
            members: ["X", "Y"],
            iconName: "person.3.fill",
            createdAt: Date(timeIntervalSinceNow: -300)
        )

        // Give groupC a recent lastUsedAt so it should sort first
        groupC.lastUsedAt = Date(timeIntervalSinceNow: -10)

        try await store.saveGroup(groupA)
        try await store.saveGroup(groupB)
        try await store.saveGroup(groupC)

        let groups = try await store.fetchAllGroups()

        XCTAssertEqual(groups.count, 3)
        // groupC was most recently used — must be first
        XCTAssertEqual(groups[0].name, "C")
        // groupA and groupB have nil lastUsedAt, so sort by createdAt desc → B then A
        XCTAssertEqual(groups[1].name, "B")
        XCTAssertEqual(groups[2].name, "A")
    }

    // MARK: - testDeleteGroup

    func testDeleteGroup() async throws {
        let group = ParticipantGroup(
            name: "Temp",
            members: ["A", "B"],
            iconName: "person.3.fill"
        )
        try await store.saveGroup(group)
        try await store.deleteGroup(id: group.id)

        let groups = try await store.fetchAllGroups()
        XCTAssertTrue(groups.isEmpty)
    }

    func testDeleteNonExistentGroupThrows() async {
        let fakeId = UUID()
        do {
            try await store.deleteGroup(id: fakeId)
            XCTFail("Expected GroupStoreError.notFound")
        } catch GroupStoreError.notFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - testUpdateGroup

    func testUpdateGroup() async throws {
        var group = ParticipantGroup(
            name: "Original",
            members: ["A", "B"],
            iconName: "person.3.fill"
        )
        try await store.saveGroup(group)

        group.name = "Updated"
        group.members = ["A", "B", "C"]
        try await store.saveGroup(group)

        let groups = try await store.fetchAllGroups()
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].name, "Updated")
        XCTAssertEqual(groups[0].members.count, 3)
    }

    // MARK: - testRecordUsage

    func testRecordUsage() async throws {
        let group = ParticipantGroup(
            name: "Test",
            members: ["A", "B"],
            iconName: "person.3.fill"
        )
        XCTAssertEqual(group.usageCount, 0)
        XCTAssertNil(group.lastUsedAt)

        try await store.saveGroup(group)
        try await store.recordGroupUsage(id: group.id)

        let groups = try await store.fetchAllGroups()
        XCTAssertEqual(groups[0].usageCount, 1)
        XCTAssertNotNil(groups[0].lastUsedAt)
    }

    func testRecordUsageIncrementsCount() async throws {
        let group = ParticipantGroup(
            name: "Test",
            members: ["A", "B"],
            iconName: "person.3.fill"
        )
        try await store.saveGroup(group)
        try await store.recordGroupUsage(id: group.id)
        try await store.recordGroupUsage(id: group.id)
        try await store.recordGroupUsage(id: group.id)

        let groups = try await store.fetchAllGroups()
        XCTAssertEqual(groups[0].usageCount, 3)
    }
}

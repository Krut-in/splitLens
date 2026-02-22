//
//  ParticipantsViewModelGroupTests.swift
//  SplitLensTests
//
//  Unit tests for ParticipantsViewModel group loading behaviour.
//

import XCTest
@testable import SplitLens

@MainActor
final class ParticipantsViewModelGroupTests: XCTestCase {

    private func makeGroup(name: String, members: [String]) -> ParticipantGroup {
        ParticipantGroup(name: name, members: members, iconName: "person.3.fill")
    }

    // MARK: - testLoadGroupMergesMembers

    func testLoadGroupMergesMembers() {
        let vm = ParticipantsViewModel()
        vm.addParticipant("Alice")

        let group = makeGroup(name: "G", members: ["Bob", "Charlie"])
        vm.loadGroup(group)

        XCTAssertEqual(vm.participants, ["Alice", "Bob", "Charlie"])
    }

    // MARK: - testLoadGroupSkipsDuplicates

    func testLoadGroupSkipsDuplicates() {
        let vm = ParticipantsViewModel()
        vm.addParticipant("alice")  // lowercase

        let group = makeGroup(name: "G", members: ["Alice", "Bob"])  // Alice is duplicate
        vm.loadGroup(group)

        XCTAssertEqual(vm.participants.count, 2)
        XCTAssertTrue(vm.participants.contains("alice"),
                      "Original casing should be preserved")
        XCTAssertTrue(vm.participants.contains("Bob"))
    }

    // MARK: - testLoadGroupAutoSelectsPayer

    func testLoadGroupAutoSelectsPayer() {
        let vm = ParticipantsViewModel()
        XCTAssertTrue(vm.paidBy.isEmpty)

        let group = makeGroup(name: "G", members: ["Krutin", "Rohan"])
        vm.loadGroup(group)

        XCTAssertEqual(vm.paidBy, "Krutin")
    }

    // MARK: - testLoadGroupKeepsExistingPayer

    func testLoadGroupKeepsExistingPayer() {
        let vm = ParticipantsViewModel()
        vm.addParticipant("Alice")
        vm.setPayer("Alice")

        let group = makeGroup(name: "G", members: ["Bob", "Charlie"])
        vm.loadGroup(group)

        XCTAssertEqual(vm.paidBy, "Alice",
                       "Existing payer should not be overwritten")
    }

    // MARK: - testLoadMultipleGroupsMerges

    func testLoadMultipleGroupsMerges() {
        let vm = ParticipantsViewModel()

        let groupA = makeGroup(name: "A", members: ["Alice", "Bob"])
        let groupB = makeGroup(name: "B", members: ["Bob", "Charlie"])  // Bob is duplicate

        vm.loadGroup(groupA)
        vm.loadGroup(groupB)

        let names = vm.participants
        XCTAssertEqual(names.count, 3, "Union of both groups with no duplicates")
        XCTAssertTrue(names.contains("Alice"))
        XCTAssertTrue(names.contains("Bob"))
        XCTAssertTrue(names.contains("Charlie"))
    }

    // MARK: - testDeselectGroupDoesNotRemoveParticipants

    func testDeselectGroupDoesNotRemoveParticipants() {
        let vm = ParticipantsViewModel()

        let group = makeGroup(name: "Roomies", members: ["Krutin", "Rohan"])
        vm.loadGroup(group)

        // Deselect by setting selectedGroupId to nil (simulating a second tap)
        vm.selectedGroupId = nil

        XCTAssertEqual(vm.participants.count, 2,
                       "Deselecting a group should NOT remove participants")
        XCTAssertFalse(vm.isGroupSelected(group))
    }

    // MARK: - testIsGroupSelected

    func testIsGroupSelected() {
        let vm = ParticipantsViewModel()
        let group = makeGroup(name: "G", members: ["A", "B"])

        XCTAssertFalse(vm.isGroupSelected(group))
        vm.loadGroup(group)
        XCTAssertTrue(vm.isGroupSelected(group))
    }

    // MARK: - testLoadGroupClearsErrorMessage

    func testLoadGroupClearsErrorMessage() {
        let vm = ParticipantsViewModel()
        vm.errorMessage = "Some previous error"

        let group = makeGroup(name: "G", members: ["A", "B"])
        vm.loadGroup(group)

        XCTAssertNil(vm.errorMessage)
    }
}

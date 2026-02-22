//
//  GroupEditorViewModelTests.swift
//  SplitLensTests
//
//  Unit tests for GroupEditorViewModel.
//

import XCTest
@testable import SplitLens

@MainActor
final class GroupEditorViewModelTests: XCTestCase {

    private var store: InMemoryGroupStore!

    override func setUp() {
        super.setUp()
        store = InMemoryGroupStore()
    }

    // MARK: - testValidationEmpty

    func testValidationEmpty() {
        let vm = GroupEditorViewModel(
            mode: .create,
            existingGroupNames: [],
            groupStore: store
        )
        // Name and members are empty — should be invalid
        XCTAssertFalse(vm.isValid)
        let errors = vm.validate()
        XCTAssertTrue(errors.contains(where: { $0.contains("empty") }))
    }

    // MARK: - testValidationDuplicateName

    func testValidationDuplicateName() {
        let vm = GroupEditorViewModel(
            mode: .create,
            existingGroupNames: ["Roomies", "Work Crew"],
            groupStore: store
        )
        vm.groupName = "roomies"    // case-insensitive duplicate
        vm.members = ["A", "B"]

        XCTAssertFalse(vm.isValid)
        let errors = vm.validate()
        XCTAssertTrue(errors.contains(where: { $0.contains("already exists") }))
    }

    // MARK: - testValidationTooFewMembers

    func testValidationTooFewMembers() {
        let vm = GroupEditorViewModel(
            mode: .create,
            existingGroupNames: [],
            groupStore: store
        )
        vm.groupName = "Test"
        vm.members = ["Alice"]  // only 1 member — min is 2

        XCTAssertFalse(vm.isValid)
        let errors = vm.validate()
        XCTAssertTrue(errors.contains(where: { $0.contains("at least") }))
    }

    // MARK: - testValidationDuplicateMember

    func testValidationDuplicateMember() {
        let vm = GroupEditorViewModel(
            mode: .create,
            existingGroupNames: [],
            groupStore: store
        )
        vm.groupName = "Test"
        vm.members = ["Alice"]

        vm.newMemberName = "alice"  // case-insensitive duplicate
        vm.addMember()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.errorMessage?.contains("already in this group") == true)
        XCTAssertEqual(vm.members.count, 1)
    }

    // MARK: - testEditModePrePopulates

    func testEditModePrePopulates() {
        let group = ParticipantGroup(
            id: UUID(),
            name: "Roomies",
            members: ["Krutin", "Rohan"],
            iconName: "house.fill"
        )
        let vm = GroupEditorViewModel(
            mode: .edit(group),
            existingGroupNames: ["Roomies", "Work Crew"],
            groupStore: store
        )

        XCTAssertEqual(vm.groupName, "Roomies")
        XCTAssertEqual(vm.selectedIcon, "house.fill")
        XCTAssertEqual(vm.members, ["Krutin", "Rohan"])
    }

    // MARK: - testHasUnsavedChanges

    func testHasUnsavedChangesCreateMode() {
        let vm = GroupEditorViewModel(
            mode: .create,
            existingGroupNames: [],
            groupStore: store
        )
        XCTAssertFalse(vm.hasUnsavedChanges)

        vm.groupName = "Test"
        XCTAssertTrue(vm.hasUnsavedChanges)
    }

    func testHasUnsavedChangesEditModeNameChange() {
        let group = ParticipantGroup(
            name: "Roomies",
            members: ["A", "B"],
            iconName: "house.fill"
        )
        let vm = GroupEditorViewModel(
            mode: .edit(group),
            existingGroupNames: [],
            groupStore: store
        )

        XCTAssertFalse(vm.hasUnsavedChanges)
        vm.groupName = "Roommates"
        XCTAssertTrue(vm.hasUnsavedChanges)
    }

    func testHasUnsavedChangesEditModeIconChange() {
        let group = ParticipantGroup(
            name: "Roomies",
            members: ["A", "B"],
            iconName: "house.fill"
        )
        let vm = GroupEditorViewModel(
            mode: .edit(group),
            existingGroupNames: [],
            groupStore: store
        )

        vm.selectedIcon = "airplane"
        XCTAssertTrue(vm.hasUnsavedChanges)
    }

    // MARK: - testEditModeAllowsSameNameForSelf

    func testEditModeAllowsSameNameForSelf() {
        let group = ParticipantGroup(
            name: "Roomies",
            members: ["A", "B"],
            iconName: "house.fill"
        )
        // existingGroupNames includes "Roomies" (the other groups) — but we pass it
        // The VM must exclude the current group's own name from the duplicate check.
        let vm = GroupEditorViewModel(
            mode: .edit(group),
            existingGroupNames: ["Roomies"],  // parent passes full list including current
            groupStore: store
        )

        // Name matches the group's own name — should NOT be flagged as duplicate
        vm.groupName = "Roomies"
        // VM excludes the current group's name in init, so this is valid if members ok
        vm.members = ["A", "B"]  // already set but ensure state is right
        XCTAssertTrue(vm.isValid, "Editing a group with the same name should be allowed")
    }

    // MARK: - testNavigationTitle

    func testNavigationTitleCreate() {
        let vm = GroupEditorViewModel(mode: .create, existingGroupNames: [], groupStore: store)
        XCTAssertEqual(vm.navigationTitle, "New Group")
    }

    func testNavigationTitleEdit() {
        let group = ParticipantGroup(name: "G", members: ["A", "B"], iconName: "person.3.fill")
        let vm = GroupEditorViewModel(mode: .edit(group), existingGroupNames: [], groupStore: store)
        XCTAssertEqual(vm.navigationTitle, "Edit Group")
    }

    // MARK: - testSaveGroupCreate

    func testSaveGroupCreate() async throws {
        let vm = GroupEditorViewModel(
            mode: .create,
            existingGroupNames: [],
            groupStore: store
        )
        vm.groupName = "New Group"
        vm.members = ["Alice", "Bob"]

        try await vm.saveGroup()

        let groups = try await store.fetchAllGroups()
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].name, "New Group")
    }

    func testSaveGroupEditPreservesId() async throws {
        let original = ParticipantGroup(
            name: "Original",
            members: ["A", "B"],
            iconName: "person.3.fill"
        )
        try await store.saveGroup(original)

        let vm = GroupEditorViewModel(
            mode: .edit(original),
            existingGroupNames: [],
            groupStore: store
        )
        vm.groupName = "Renamed"

        try await vm.saveGroup()

        let groups = try await store.fetchAllGroups()
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].id, original.id)
        XCTAssertEqual(groups[0].name, "Renamed")
    }
}

//
//  GroupEditorViewModel.swift
//  SplitLens
//
//  ViewModel for creating and editing a participant group.
//

import Foundation

@MainActor
final class GroupEditorViewModel: ObservableObject {

    // MARK: - Mode

    enum Mode {
        case create
        case edit(ParticipantGroup)
    }

    // MARK: - Published Properties

    @Published var groupName: String = ""
    @Published var selectedIcon: String = AppConstants.Groups.availableIcons[0]
    @Published var members: [String] = []
    @Published var newMemberName: String = ""
    @Published var errorMessage: String?
    @Published var isSaving: Bool = false

    // MARK: - Properties

    let mode: Mode
    private let groupStore: GroupStoreProtocol
    /// Existing group names to check for uniqueness (current group's name excluded for edit mode)
    private let existingGroupNames: [String]
    /// Original group snapshot used to detect unsaved changes in edit mode
    private let originalGroup: ParticipantGroup?

    // MARK: - Initialization

    init(mode: Mode, existingGroupNames: [String], groupStore: GroupStoreProtocol) {
        self.mode = mode
        self.groupStore = groupStore

        if case .edit(let group) = mode {
            // Exclude the current group's name from uniqueness check
            self.existingGroupNames = existingGroupNames.filter {
                $0.lowercased() != group.name.lowercased()
            }
            self.originalGroup = group
            self.groupName = group.name
            self.selectedIcon = group.iconName
            self.members = group.members
        } else {
            self.existingGroupNames = existingGroupNames
            self.originalGroup = nil
        }
    }

    // MARK: - Computed Properties

    var navigationTitle: String {
        switch mode {
        case .create: return "New Group"
        case .edit:   return "Edit Group"
        }
    }

    var saveButtonTitle: String {
        switch mode {
        case .create: return "Create"
        case .edit:   return "Save"
        }
    }

    var isValid: Bool {
        validate().isEmpty
    }

    var hasUnsavedChanges: Bool {
        switch mode {
        case .create:
            return !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !members.isEmpty
        case .edit(let original):
            return groupName != original.name
                || selectedIcon != original.iconName
                || members != original.members
        }
    }

    // MARK: - Validation

    func validate() -> [String] {
        var errors: [String] = []

        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            errors.append("Group name cannot be empty.")
        } else if trimmedName.count > AppConstants.Groups.maxGroupNameLength {
            errors.append("Group name must be \(AppConstants.Groups.maxGroupNameLength) characters or fewer.")
        } else {
            let isDuplicate = existingGroupNames.contains {
                $0.lowercased() == trimmedName.lowercased()
            }
            if isDuplicate {
                errors.append("A group named '\(trimmedName)' already exists.")
            }
        }

        if members.count < AppConstants.Groups.minMembersPerGroup {
            errors.append("Groups need at least \(AppConstants.Groups.minMembersPerGroup) members.")
        }

        return errors
    }

    // MARK: - Member Actions

    func addMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "Name cannot be empty."
            return
        }
        guard trimmed.count <= AppConstants.Validation.maxParticipantNameLength else {
            errorMessage = "Name is too long (max \(AppConstants.Validation.maxParticipantNameLength) characters)."
            return
        }
        guard !members.contains(where: { $0.lowercased() == trimmed.lowercased() }) else {
            errorMessage = "'\(trimmed)' is already in this group."
            return
        }
        guard members.count < AppConstants.Groups.maxMembersPerGroup else {
            errorMessage = "Groups can have at most \(AppConstants.Groups.maxMembersPerGroup) members."
            return
        }

        members.append(trimmed)
        newMemberName = ""
        errorMessage = nil
    }

    func removeMember(_ name: String) {
        members.removeAll { $0 == name }
    }

    // MARK: - Save

    func saveGroup() async throws {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let errors = validate()
        guard errors.isEmpty else {
            errorMessage = errors.first
            return
        }

        isSaving = true
        defer { isSaving = false }

        let group: ParticipantGroup
        switch mode {
        case .create:
            group = ParticipantGroup(
                name: trimmedName,
                members: members,
                iconName: selectedIcon
            )
        case .edit(let original):
            group = ParticipantGroup(
                id: original.id,
                name: trimmedName,
                members: members,
                iconName: selectedIcon,
                createdAt: original.createdAt,
                lastUsedAt: original.lastUsedAt,
                usageCount: original.usageCount
            )
        }

        try await groupStore.saveGroup(group)
    }
}

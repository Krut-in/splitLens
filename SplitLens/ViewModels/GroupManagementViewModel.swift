//
//  GroupManagementViewModel.swift
//  SplitLens
//
//  ViewModel for the group management list screen.
//

import Foundation

@MainActor
final class GroupManagementViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var groups: [ParticipantGroup] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let groupStore: GroupStoreProtocol

    // MARK: - Initialization

    init(groupStore: GroupStoreProtocol) {
        self.groupStore = groupStore
    }

    // MARK: - Actions

    func loadGroups() async {
        isLoading = true
        errorMessage = nil
        do {
            groups = try await groupStore.fetchAllGroups()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteGroup(_ group: ParticipantGroup) async {
        do {
            try await groupStore.deleteGroup(id: group.id)
            groups.removeAll { $0.id == group.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGroups(at offsets: IndexSet) async {
        let groupsToDelete = offsets.map { groups[$0] }
        for group in groupsToDelete {
            await deleteGroup(group)
        }
    }
}

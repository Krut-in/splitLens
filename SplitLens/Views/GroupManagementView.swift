//
//  GroupManagementView.swift
//  SplitLens
//
//  Full-screen list for managing saved participant groups.
//

import SwiftUI

/// Screen for viewing, creating, editing, and deleting saved groups.
struct GroupManagementView: View {

    // MARK: - Environment

    @Environment(\.dependencies) private var dependencies

    // MARK: - Navigation

    @Binding var navigationPath: NavigationPath

    // MARK: - ViewModel

    @StateObject private var viewModel: GroupManagementViewModel

    // MARK: - State

    private enum ActiveSheet: Identifiable {
        case create
        case edit(ParticipantGroup)

        var id: String {
            switch self {
            case .create:           return "create"
            case .edit(let group):  return group.id.uuidString
            }
        }
    }

    @State private var activeSheet: ActiveSheet?

    // MARK: - Initialization

    init(navigationPath: Binding<NavigationPath>) {
        _navigationPath = navigationPath
        _viewModel = StateObject(
            wrappedValue: GroupManagementViewModel(
                groupStore: DependencyContainer.shared.groupStore
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.groups.isEmpty {
                    EmptyStateView(
                        icon: "person.3.fill",
                        message: "No saved groups yet.\nCreate a group to quickly add regulars.",
                        actionLabel: "New Group"
                    ) {
                        activeSheet = .create
                    }
                } else {
                    groupList
                }
            }
        }
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { activeSheet = .create }) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                }
                .disabled(viewModel.groups.count >= AppConstants.Groups.maxGroups)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.groups.count >= AppConstants.Groups.maxGroups {
                groupLimitBanner
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $activeSheet) { sheet in
            editorSheet(for: sheet)
        }
        .task {
            await viewModel.loadGroups()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var groupList: some View {
        List {
            ForEach(viewModel.groups) { group in
                GroupRowView(group: group) {
                    activeSheet = .edit(group)
                } onDelete: {
                    Task { await viewModel.deleteGroup(group) }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                Task { await viewModel.deleteGroups(at: offsets) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var groupLimitBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            Text("Group limit reached (\(AppConstants.Groups.maxGroups)). Delete a group to create a new one.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func editorSheet(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .create:
            GroupEditorSheet(
                mode: .create,
                existingGroupNames: viewModel.groups.map { $0.name },
                groupStore: dependencies.groupStore
            ) {
                Task { await viewModel.loadGroups() }
            }
        case .edit(let group):
            GroupEditorSheet(
                mode: .edit(group),
                existingGroupNames: viewModel.groups.filter { $0.id != group.id }.map { $0.name },
                groupStore: dependencies.groupStore
            ) {
                Task { await viewModel.loadGroups() }
            }
        }
    }
}

// MARK: - Group Row

private struct GroupRowView: View {
    let group: ParticipantGroup
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: group.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(group.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(group.memberCountLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Text(group.memberPreview)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Actions
            HStack(spacing: 14) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GroupManagementView(navigationPath: .constant(NavigationPath()))
    }
    .withDependencies()
}

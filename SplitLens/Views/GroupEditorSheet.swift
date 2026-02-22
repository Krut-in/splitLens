//
//  GroupEditorSheet.swift
//  SplitLens
//
//  Modal sheet for creating or editing a participant group.
//

import SwiftUI

/// Sheet for creating a new group or editing an existing one.
struct GroupEditorSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - ViewModel

    @StateObject private var viewModel: GroupEditorViewModel

    // MARK: - State

    @FocusState private var isMemberFieldFocused: Bool
    @State private var showDiscardAlert = false

    // MARK: - Callbacks

    let onSave: () -> Void

    // MARK: - Initialization

    init(
        mode: GroupEditorViewModel.Mode,
        existingGroupNames: [String],
        groupStore: GroupStoreProtocol,
        onSave: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: GroupEditorViewModel(
                mode: mode,
                existingGroupNames: existingGroupNames,
                groupStore: groupStore
            )
        )
        self.onSave = onSave
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    groupNameSection
                    iconPickerSection
                    membersSection

                    // Validation hint
                    if !viewModel.isValid && !viewModel.members.isEmpty {
                        validationHint
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel.hasUnsavedChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.saveButtonTitle) {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .alert("Discard changes?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your changes will not be saved.")
            }
        }
    }

    // MARK: - Sections

    private var groupNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Group Name")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextField("e.g. Roommates", text: $viewModel.groupName)
                .font(.system(size: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .onChange(of: viewModel.groupName) { _, newValue in
                    if newValue.count > AppConstants.Groups.maxGroupNameLength {
                        viewModel.groupName = String(newValue.prefix(AppConstants.Groups.maxGroupNameLength))
                    }
                }
        }
    }

    private var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AppConstants.Groups.availableIcons, id: \.self) { icon in
                        Button(action: {
                            HapticFeedback.shared.lightImpact()
                            viewModel.selectedIcon = icon
                        }) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.selectedIcon == icon
                                          ? Color.blue.opacity(0.15)
                                          : Color(.secondarySystemBackground))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle()
                                            .stroke(viewModel.selectedIcon == icon
                                                    ? Color.blue
                                                    : Color.clear, lineWidth: 2)
                                    )

                                Image(systemName: icon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(viewModel.selectedIcon == icon ? .blue : .primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Member entry
            HStack(spacing: 12) {
                TextField("Enter name", text: $viewModel.newMemberName)
                    .font(.system(size: 16))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .focused($isMemberFieldFocused)
                    .onSubmit {
                        viewModel.addMember()
                    }

                Button(action: { viewModel.addMember() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(viewModel.newMemberName.isEmpty ? .gray : .blue)
                }
                .disabled(viewModel.newMemberName.isEmpty)
            }

            // Member error
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }

            // Member list
            if !viewModel.members.isEmpty {
                VStack(spacing: 10) {
                    ForEach(viewModel.members, id: \.self) { member in
                        HStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(member.prefix(1).uppercased())
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                )

                            Text(member)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            Button(action: {
                                HapticFeedback.shared.lightImpact()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    viewModel.removeMember(member)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red.opacity(0.7))
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.members)
            }
        }
    }

    private var validationHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14))
            Text(viewModel.validate().first ?? "")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        Task {
            do {
                try await viewModel.saveGroup()
                HapticFeedback.shared.success()
                onSave()
                dismiss()
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#Preview("Create") {
    GroupEditorSheet(
        mode: .create,
        existingGroupNames: [],
        groupStore: InMemoryGroupStore()
    ) {}
}

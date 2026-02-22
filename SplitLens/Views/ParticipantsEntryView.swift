//
//  ParticipantsEntryView.swift
//  SplitLens
//
//  Participant management and payer selection with liquid glass design
//

import SwiftUI

/// Screen for managing participants and selecting payer
struct ParticipantsEntryView: View {
    // MARK: - Navigation

    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    // MARK: - ViewModels

    @StateObject private var viewModel = ParticipantsViewModel()
    @StateObject private var itemsViewModel: ItemsEditorViewModel

    // MARK: - Properties

    /// Extracted fees from the receipt
    private let extractedFees: [Fee]
    private let scanMetadata: ScanMetadata

    // MARK: - State

    @FocusState private var isNameFieldFocused: Bool
    @State private var savedGroups: [ParticipantGroup] = []
    @State private var showGroupEditor = false
    @AppStorage("hasShownGroupsTip") private var hasShownGroupsTip = false
    
    // MARK: - Initialization
    
    init(
        items: [ReceiptItem],
        fees: [Fee] = [],
        scanMetadata: ScanMetadata,
        navigationPath: Binding<NavigationPath>
    ) {
        _itemsViewModel = StateObject(wrappedValue: ItemsEditorViewModel(items: items, fees: fees))
        self.extractedFees = fees
        self.scanMetadata = scanMetadata
        _navigationPath = navigationPath
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Summary card
                    SummaryCard(
                        title: "Total Bill",
                        value: itemsViewModel.formattedCalculatedTotal,
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )
                    .padding(.horizontal)

                    // Saved groups section (only when groups exist)
                    if !savedGroups.isEmpty {
                        savedGroupsSection
                            .padding(.horizontal)
                    }

                    // First-time tip (shown once when no groups exist)
                    if savedGroups.isEmpty && !hasShownGroupsTip {
                        groupsTipBanner
                            .padding(.horizontal)
                    }

                    // Add participant section
                    addParticipantSection
                        .padding(.horizontal)
                    
                    // Participants list
                    if !viewModel.participants.isEmpty {
                        participantsList
                            .padding(.horizontal)
                    } else {
                        EmptyStateView(
                            icon: "person.3.fill",
                            message: "Add at least 2 people to split the bill"
                        )
                        .padding(.vertical, 40)
                    }
                    
                    // Payer selection
                    if viewModel.hasEnoughParticipants {
                        payerSection
                            .padding(.horizontal)
                    }
                    
                    // Validation errors
                    if !viewModel.isValid {
                        validationSection
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard when tapping outside text field
                isNameFieldFocused = false
            }
        }
        .navigationTitle("Participants")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isValid {
                    Button("Next") {
                        navigateToNextScreen()
                    }
                    .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .task {
            do {
                savedGroups = try await dependencies.groupStore.fetchAllGroups()
            } catch {
                // Groups are a convenience — silently fail, section stays hidden
            }
        }
        .sheet(isPresented: $showGroupEditor) {
            GroupEditorSheet(
                mode: .create,
                existingGroupNames: savedGroups.map { $0.name },
                groupStore: dependencies.groupStore
            ) {
                Task {
                    savedGroups = (try? await dependencies.groupStore.fetchAllGroups()) ?? savedGroups
                }
            }
        }
    }
    
    // MARK: - Navigation
    
    /// Navigates to the appropriate next screen based on whether fees exist
    private func navigateToNextScreen() {
        HapticFeedback.shared.mediumImpact()
        
        // If fees exist, go to TaxTipAllocationView first
        if !extractedFees.isEmpty {
            navigationPath.append(
                Route.taxTipAllocation(
                    itemsViewModel.items,
                    extractedFees,
                    viewModel.participants,
                    viewModel.paidBy,
                    itemsViewModel.grandTotal,
                    scanMetadata
                )
            )
        } else {
            // No fees, go directly to item assignment with empty fee allocations
            navigationPath.append(
                Route.itemAssignment(
                    itemsViewModel.items,
                    viewModel.participants,
                    viewModel.paidBy,
                    itemsViewModel.totalAmount,
                    [],
                    scanMetadata
                )
            )
        }
    }
    
    // MARK: - Sections

    private var savedGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Groups")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Show up to 6 chips; overflow handled by "See all" chip
                    let visibleGroups = Array(savedGroups.prefix(6))
                    let hasMore = savedGroups.count > 6

                    ForEach(visibleGroups) { group in
                        GroupChip(
                            group: group,
                            isSelected: viewModel.isGroupSelected(group)
                        ) {
                            HapticFeedback.shared.lightImpact()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                viewModel.loadGroup(group)
                            }
                            Task {
                                try? await dependencies.groupStore.recordGroupUsage(id: group.id)
                            }
                        }
                    }

                    // "See all" chip if more than 6 groups
                    if hasMore {
                        Button(action: {
                            // Navigate to group management (no navigation needed here, just informational)
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("See all (\(savedGroups.count))")
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    // "+ New Group" chip at the end
                    Button(action: { showGroupEditor = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("New")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundStyle(.secondary)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var groupsTipBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 14))
            Text("Tip: Create a group from the home screen to quickly add regulars")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: { hasShownGroupsTip = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var addParticipantSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Participants")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            
            HStack(spacing: 12) {
                TextField("Enter name", text: $viewModel.newParticipantName)
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
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        viewModel.addNewParticipant()
                    }
                
                Button(action: {
                    viewModel.addNewParticipant()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.newParticipantName.isEmpty ? .gray : .blue
                        )
                }
                .disabled(viewModel.newParticipantName.isEmpty)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var participantsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("People (\(viewModel.participantCount))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if viewModel.hasEnoughParticipants {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            
            VStack(spacing: 10) {
                ForEach(viewModel.participants, id: \.self) { participant in
                    HStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.6),
                                        Color.purple.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(participant.prefix(1).uppercased())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        
                        Text(participant)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.removeParticipant(participant)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red.opacity(0.7))
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .scale.combined(with: .opacity)),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.participants)
        }
    }
    
    private var payerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who Paid?")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            
            Picker("Payer", selection: $viewModel.paidBy) {
                ForEach(viewModel.participants, id: \.self) { participant in
                    Text(participant).tag(participant)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.validate(), id: \.self) { error in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ParticipantsEntryView(
            items: ReceiptItem.samples,
            fees: [Fee(type: "tax", amount: 2.50)],
            scanMetadata: .empty,
            navigationPath: .constant(NavigationPath())
        )
    }
}

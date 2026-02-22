//
//  ItemAssignmentView.swift
//  SplitLens
//
//  Item-to-participant assignment with liquid glass design
//

import SwiftUI

/// Screen for assigning items to participants
struct ItemAssignmentView: View {
    // MARK: - Navigation
    
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel: AssignmentViewModel
    
    // MARK: - Properties
    
    /// Fee allocations from previous screen (may be empty)
    private let feeAllocations: [FeeAllocation]
    private let scanMetadata: ScanMetadata
    
    // MARK: - Initialization
    
    init(
        items: [ReceiptItem],
        participants: [String],
        paidBy: String,
        totalAmount: Double,
        feeAllocations: [FeeAllocation] = [],
        scanMetadata: ScanMetadata,
        navigationPath: Binding<NavigationPath>
    ) {
        _viewModel = StateObject(wrappedValue: AssignmentViewModel(
            items: items,
            participants: participants,
            paidBy: paidBy,
            storeName: scanMetadata.storeName
        ))
        self.feeAllocations = feeAllocations
        self.scanMetadata = scanMetadata
        _navigationPath = navigationPath
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                progressSection
                    .padding()

                // Smart suggestion banner (shown when suggestions are active)
                if viewModel.hasSmartSuggestions {
                    smartSuggestionBanner
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // Items with assignment chips
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach($viewModel.items) { $item in
                            ItemAssignmentCard(
                                item: $item,
                                participants: viewModel.participants,
                                isSmartAssigned: viewModel.isSmartAssigned(item.id),
                                suggestion: viewModel.suggestion(for: item.id),
                                onToggle: { participant in
                                    viewModel.toggleAssignment(itemId: item.id, participant: participant)
                                }
                            )
                        }
                    }
                    .padding()
                }

                // Bottom bar with totals and calculate button
                bottomBar
            }
        }
        .navigationTitle("Assign Items")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Assign All to Everyone", action: {
                        viewModel.splitEquallyAllItems()
                    })

                    Button("Clear All Assignments", action: {
                        viewModel.clearAllAssignments()
                    })

                    if viewModel.hasSmartSuggestions {
                        Button("Clear Smart Suggestions", role: .destructive, action: {
                            viewModel.clearSmartSuggestions()
                        })
                    }

                    Toggle("Smart Suggestions", isOn: Binding(
                        get: { viewModel.smartSuggestionsEnabled },
                        set: { enabled in
                            viewModel.smartSuggestionsEnabled = enabled
                            if enabled {
                                Task { await viewModel.loadSmartSuggestions() }
                            } else {
                                viewModel.clearSmartSuggestions()
                            }
                        }
                    ))
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            }
        }
        .task {
            await viewModel.loadSmartSuggestions()
        }
    }
    
    // MARK: - Sections

    private var smartSuggestionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile.fill")
                .foregroundStyle(.purple)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Suggestions Applied")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("\(viewModel.smartSuggestedCount) item(s) auto-assigned based on past sessions")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.clearSmartSuggestions()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Assignment Progress")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(viewModel.items.count - viewModel.unassignedItemCount)/\(viewModel.items.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (viewModel.assignmentProgress / 100))
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Per-person totals
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.participants, id: \.self) { participant in
                        VStack(spacing: 4) {
                            Text(participant)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            Text(viewModel.formattedTotal(for: participant))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)
            }
            
            // Calculate button
            Button(action: {
                calculateSplits()
            }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Calculate Splits")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            viewModel.allItemsAssigned ? Color.green : Color.gray,
                            viewModel.allItemsAssigned ? Color.green.opacity(0.8) : Color.gray.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(
                    color: viewModel.allItemsAssigned ? Color.green.opacity(0.3) : Color.clear,
                    radius: 10,
                    x: 0,
                    y: 5
                )
            }
            .disabled(!viewModel.allItemsAssigned)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .background(.ultraThinMaterial)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
    }
    
    // MARK: - Methods
    
    private func calculateSplits() {
        // Create session with fee allocations
        let totalWithFees = viewModel.items.reduce(0.0) { $0 + $1.totalPrice } +
                            feeAllocations.reduce(0.0) { $0 + $1.fee.amount }

        let session = ReceiptSession(
            participants: viewModel.participants,
            totalAmount: totalWithFees,
            paidBy: viewModel.paidBy,
            items: viewModel.items,
            computedSplits: [],
            feeAllocations: feeAllocations,
            storeName: scanMetadata.storeName
        )

        navigationPath.append(Route.finalReport(session, scanMetadata))
    }
}

// MARK: - Item Assignment Card

struct ItemAssignmentCard: View {
    @Binding var item: ReceiptItem
    let participants: [String]
    var isSmartAssigned: Bool = false
    var suggestion: SuggestedAssignment? = nil
    let onToggle: (String) -> Void

    private var borderColor: Color {
        if isSmartAssigned {
            return Color.purple.opacity(0.4)
        }
        return item.isAssigned ? Color.blue.opacity(0.3) : Color.clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Item info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)

                        // Smart assignment confidence badge
                        if isSmartAssigned, let suggestion = suggestion, suggestion.confidence != .none {
                            HStack(spacing: 3) {
                                Image(systemName: suggestion.confidence.iconName)
                                    .font(.system(size: 9))
                                Text(suggestion.confidence.displayLabel)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(badgeTextColor(suggestion.confidence))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(badgeBackgroundColor(suggestion.confidence))
                            .clipShape(Capsule())
                        }
                    }

                    if item.quantity > 1 {
                        HStack(spacing: 4) {
                            Text("Qty:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("\(item.quantity)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                }

                Spacer()

                Text(CurrencyFormatter.shared.format(item.totalPrice))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }

            Divider()

            // Assignment chips
            VStack(alignment: .leading, spacing: 8) {
                Text("Assign to")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(participants, id: \.self) { participant in
                        ParticipantChip(
                            name: participant,
                            isSelected: item.isAssigned(to: participant),
                            action: {
                                onToggle(participant)
                            }
                        )
                    }
                }
            }

            // Per-person cost
            if item.isAssigned {
                HStack {
                    Text("Per person:")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(CurrencyFormatter.shared.format(item.pricePerPerson))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 2)
        )
    }

    private func badgeTextColor(_ confidence: PatternConfidence) -> Color {
        switch confidence {
        case .none: return .clear
        case .likely: return .orange
        case .strong: return .blue
        case .veryStrong: return .green
        }
    }

    private func badgeBackgroundColor(_ confidence: PatternConfidence) -> Color {
        switch confidence {
        case .none: return .clear
        case .likely: return Color.orange.opacity(0.12)
        case .strong: return Color.blue.opacity(0.12)
        case .veryStrong: return Color.green.opacity(0.12)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ItemAssignmentView(
            items: ReceiptItem.samples,
            participants: ["Alice", "Bob", "Charlie"],
            paidBy: "Alice",
            totalAmount: 65.96,
            feeAllocations: [],
            scanMetadata: .empty,
            navigationPath: .constant(NavigationPath())
        )
    }
}

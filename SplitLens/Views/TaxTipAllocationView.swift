//
//  TaxTipAllocationView.swift
//  SplitLens
//
//  View for allocating fees (tax, tip, delivery) among participants
//

import SwiftUI

/// Screen for configuring how fees are split among participants
struct TaxTipAllocationView: View {
    // MARK: - Navigation
    
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel: TaxTipAllocationViewModel
    
    // MARK: - State
    
    @State private var expandedAllocationId: UUID?
    @State private var showingPreview = false

    // MARK: - Properties

    private let scanMetadata: ScanMetadata
    
    // MARK: - Initialization
    
    init(
        items: [ReceiptItem],
        fees: [Fee],
        participants: [String],
        paidBy: String,
        totalAmount: Double,
        scanMetadata: ScanMetadata,
        navigationPath: Binding<NavigationPath>
    ) {
        _viewModel = StateObject(wrappedValue: TaxTipAllocationViewModel(
            items: items,
            fees: fees,
            participants: participants,
            paidBy: paidBy,
            totalAmount: totalAmount
        ))
        self.scanMetadata = scanMetadata
        _navigationPath = navigationPath
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Cards
                    summarySection
                        .padding(.horizontal)
                    
                    // Fees Section
                    feesSection
                        .padding(.horizontal)
                    
                    // Quick Actions
                    quickActionsSection
                        .padding(.horizontal)
                    
                    // Preview Section
                    previewSection
                        .padding(.horizontal)
                    
                    // Validation Errors
                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.vertical)
            }
            
            // Bottom Button
            VStack {
                Spacer()
                bottomBar
            }
        }
        .navigationTitle("Allocate Fees")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: "Subtotal",
                value: viewModel.formattedSubtotal,
                icon: "cart.fill",
                color: .blue
            )
            
            SummaryCard(
                title: "Fees",
                value: viewModel.formattedTotalFees,
                icon: "plus.circle.fill",
                color: .orange
            )
        }
    }
    
    // MARK: - Fees Section
    
    private var feesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fees & Charges")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            
            VStack(spacing: 12) {
                ForEach($viewModel.feeAllocations) { $allocation in
                    FeeAllocationRow(
                        allocation: $allocation,
                        participants: viewModel.participants,
                        isExpanded: expandedAllocationId == allocation.id,
                        onToggleExpand: {
                            withAnimation(.spring(response: 0.3)) {
                                if expandedAllocationId == allocation.id {
                                    expandedAllocationId = nil
                                } else {
                                    expandedAllocationId = allocation.id
                                }
                            }
                        },
                        onStrategyChange: { strategy in
                            viewModel.updateStrategy(for: allocation.id, to: strategy)
                        },
                        onToggleParticipant: { participant in
                            viewModel.toggleManualAssignment(
                                for: allocation.id,
                                participant: participant
                            )
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Proportional",
                    icon: "chart.pie.fill",
                    color: .purple
                ) {
                    viewModel.applyStrategyToAll(.proportional)
                }
                
                QuickActionButton(
                    title: "Equal",
                    icon: "equal.circle.fill",
                    color: .green
                ) {
                    viewModel.applyStrategyToAll(.equal)
                }
            }
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    withAnimation {
                        showingPreview.toggle()
                    }
                } label: {
                    Image(systemName: showingPreview ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            
            if showingPreview || viewModel.isValid {
                VStack(spacing: 10) {
                    ForEach(viewModel.participants, id: \.self) { person in
                        PreviewRow(
                            name: person,
                            itemsTotal: viewModel.itemsTotal(for: person),
                            feesTotal: viewModel.feesTotal(for: person),
                            grandTotal: viewModel.formattedGrandTotal(for: person),
                            isPayer: person == viewModel.paidBy
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            showingPreview = true
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                navigateToAssignment()
            } label: {
                HStack {
                    Text("Continue to Assignment")
                        .font(.system(size: 18, weight: .bold))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: viewModel.isValid 
                            ? [Color.blue, Color.blue.opacity(0.8)]
                            : [Color.gray, Color.gray.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!viewModel.isValid)
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Navigation
    
    private func navigateToAssignment() {
        guard viewModel.validate() else { return }
        
        HapticFeedback.shared.mediumImpact()
        
        navigationPath.append(
            Route.itemAssignment(
                viewModel.items,
                viewModel.participants,
                viewModel.paidBy,
                viewModel.totalAmount,
                viewModel.feeAllocations,
                scanMetadata
            )
        )
    }
}

// MARK: - Fee Allocation Row

struct FeeAllocationRow: View {
    @Binding var allocation: FeeAllocation
    let participants: [String]
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onStrategyChange: (FeeAllocationStrategy) -> Void
    let onToggleParticipant: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggleExpand) {
                HStack {
                    // Fee Icon
                    feeIcon
                    
                    // Fee Details
                    VStack(alignment: .leading, spacing: 2) {
                        Text(allocation.fee.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        Text(allocation.assignmentSummary)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Amount
                    Text(allocation.formattedAmount)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 12) {
                    // Strategy Picker
                    strategyPicker
                    
                    // Manual Assignments (if applicable)
                    if allocation.strategy == .manual {
                        manualAssignmentPicker
                    }
                }
                .padding(16)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var feeIcon: some View {
        ZStack {
            Circle()
                .fill(feeColor.opacity(0.15))
                .frame(width: 44, height: 44)
            
            Image(systemName: feeIconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(feeColor)
        }
    }
    
    private var feeColor: Color {
        switch allocation.fee.feeType {
        case .tax: return .orange
        case .tip: return .green
        case .delivery: return .blue
        case .service: return .purple
        case .other: return .gray
        }
    }
    
    private var feeIconName: String {
        switch allocation.fee.feeType {
        case .tax: return "percent"
        case .tip: return "heart.fill"
        case .delivery: return "car.fill"
        case .service: return "wrench.fill"
        case .other: return "dollarsign.circle.fill"
        }
    }
    
    private var strategyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Split Method")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(FeeAllocationStrategy.allCases) { strategy in
                    StrategyChip(
                        strategy: strategy,
                        isSelected: allocation.strategy == strategy,
                        onTap: { onStrategyChange(strategy) }
                    )
                }
            }
        }
    }
    
    private var manualAssignmentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assign to")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(participants, id: \.self) { participant in
                    ParticipantChip(
                        name: participant,
                        isSelected: allocation.manualAssignments?.contains(participant) ?? false,
                        action: { onToggleParticipant(participant) }
                    )
                }
            }
            
            if !allocation.hasValidManualAssignments {
                Text("Select at least one person")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Strategy Chip

struct StrategyChip: View {
    let strategy: FeeAllocationStrategy
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: strategy.icon)
                    .font(.system(size: 12, weight: .semibold))
                
                Text(strategy.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected 
                    ? Color.blue 
                    : Color(.tertiarySystemBackground)
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Row

struct PreviewRow: View {
    let name: String
    let itemsTotal: String
    let feesTotal: String
    let grandTotal: String
    let isPayer: Bool
    
    var body: some View {
        HStack {
            // Avatar
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
                    Text(name.prefix(1).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                )
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 15, weight: .medium))
                    
                    if isPayer {
                        Text("(Paid)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("Items: \(itemsTotal)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Totals
            VStack(alignment: .trailing, spacing: 2) {
                Text(grandTotal)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                
                Text("+ \(feesTotal) fees")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// Note: FlowLayout is defined in Components/ParticipantChip.swift

// MARK: - Preview

#Preview {
    NavigationStack {
        TaxTipAllocationView(
            items: [
                ReceiptItem(name: "Pizza", quantity: 1, price: 20.00, assignedTo: ["Alice", "Bob"]),
                ReceiptItem(name: "Salad", quantity: 1, price: 10.00, assignedTo: ["Alice"])
            ],
            fees: [
                Fee(type: "tax", amount: 2.50),
                Fee(type: "tip", amount: 5.00),
                Fee(type: "delivery", amount: 3.99)
            ],
            participants: ["Alice", "Bob"],
            paidBy: "Alice",
            totalAmount: 41.49,
            scanMetadata: .empty,
            navigationPath: .constant(NavigationPath())
        )
    }
}

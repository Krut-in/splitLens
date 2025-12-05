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
    
    // MARK: - Initialization
    
    init(
        items: [ReceiptItem],
        participants: [String],
        paidBy: String,
        totalAmount: Double,
        navigationPath: Binding<NavigationPath>
    ) {
        _viewModel = StateObject(wrappedValue: AssignmentViewModel(
            items: items,
            participants: participants,
            paidBy: paidBy
        ))
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
                
                // Items with assignment chips
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach($viewModel.items) { $item in
                            ItemAssignmentCard(
                                item: $item,
                                participants: viewModel.participants,
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
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            }
        }
    }
    
    // MARK: - Sections
    
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
        // Create session with the correct paidBy from the view model
        let session = ReceiptSession(
            participants: viewModel.participants,
            totalAmount: viewModel.items.reduce(0.0) { $0 + $1.totalPrice },
            paidBy: viewModel.paidBy,
            items: viewModel.items,
            computedSplits: []
        )
        
        navigationPath.append(Route.finalReport(session))
    }
}

// MARK: - Item Assignment Card

struct ItemAssignmentCard: View {
    @Binding var item: ReceiptItem
    let participants: [String]
    let onToggle: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Item info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    
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
                .stroke(
                    item.isAssigned ? Color.blue.opacity(0.3) : Color.clear,
                    lineWidth: 2
                )
        )
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
            navigationPath: .constant(NavigationPath())
        )
    }
}

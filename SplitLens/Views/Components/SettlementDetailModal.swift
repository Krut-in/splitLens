//
//  SettlementDetailModal.swift
//  SplitLens
//
//  Drill-down modal showing item-by-item breakdown for a settlement
//

import SwiftUI

/// Modal view showing detailed breakdown of a settlement
struct SettlementDetailModal: View {
    // MARK: - Properties
    
    let split: SplitLog
    let session: ReceiptSession
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Computed Properties
    
    private var itemsForPerson: [ReceiptItem] {
        session.items.filter { $0.isAssigned(to: split.from) }
    }
    
    private var subtotal: Double {
        itemsForPerson.reduce(0.0) { total, item in
            total + item.pricePerPerson
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Items breakdown
                    itemsSection
                    
                    // Subtotal
                    subtotalSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Settlement Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticFeedback.shared.lightImpact()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // From → To
            HStack(spacing: 12) {
                personAvatar(split.from, color: .blue)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.secondary)
                
                personAvatar(split.to, color: .green)
                
                Spacer()
            }
            
            // Amount
            VStack(alignment: .leading, spacing: 4) {
                Text("Amount Owed")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(split.formattedAmount)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items Breakdown")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            
            if itemsForPerson.isEmpty {
                Text("No items assigned to \(split.from)")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(itemsForPerson) { item in
                        itemRow(item)
                    }
                }
            }
        }
    }
    
    private func itemRow(_ item: ReceiptItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item name
            Text(item.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
            
            // Formula
            if item.sharingCount > 1 {
                HStack(spacing: 6) {
                    Text("Formula:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text("\(item.formattedTotalPrice) ÷ \(item.sharingCount) = \(item.formattedPricePerPerson)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
            
            // Sharing info
            if item.sharingCount > 1 {
                Text("Shared with: \(item.assignedTo.joined(separator: ", "))")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            // Amount for this person
            HStack {
                Spacer()
                Text(item.formattedPricePerPerson)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var subtotalSection: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                Text("Subtotal for \(split.from)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(CurrencyFormatter.shared.format(subtotal))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 8)
            
            if !split.explanation.isEmpty {
                Text(split.explanation)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helper Views
    
    private func personAvatar(_ name: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.7), color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Text(name.prefix(1).uppercased())
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                )
            
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    SettlementDetailModal(
        split: SplitLog(
            from: "Bob",
            to: "Alice",
            amount: 28.03,
            explanation: "Your share of Burger, Pizza, Tax, and Tip"
        ),
        session: ReceiptSession.sample
    )
}

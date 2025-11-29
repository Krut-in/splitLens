//
//  SummaryCard.swift
//  SplitLens
//
//  Card component for displaying key-value summaries with liquid glass design
//

import SwiftUI

/// A card component for displaying summary information with glassmorphism
struct SummaryCard: View {
    // MARK: - Properties
    
    let title: String
    let value: String
    let icon: String?
    let color: Color
    
    // MARK: - Initialization
    
    init(
        title: String,
        value: String,
        icon: String? = nil,
        color: Color = .blue
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            ZStack {
                // Liquid glass background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.05),
                                color.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.1), lineWidth: 1)
            }
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: color.opacity(0.1), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Preview

#Preview("Single Card") {
    SummaryCard(
        title: "Total Amount",
        value: "$127.50",
        icon: "dollarsign.circle.fill",
        color: .green
    )
    .padding()
}

#Preview("Multiple Cards") {
    ScrollView {
        VStack(spacing: 12) {
            SummaryCard(
                title: "Total Amount",
                value: "$127.50",
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            SummaryCard(
                title: "Participants",
                value: "4 People",
                icon: "person.3.fill",
                color: .blue
            )
            
            SummaryCard(
                title: "Items",
                value: "8 Items",
                icon: "list.bullet.rectangle.fill",
                color: .orange
            )
            
            SummaryCard(
                title: "Paid By",
                value: "Alice",
                icon: "creditcard.fill",
                color: .purple
            )
        }
        .padding()
    }
}

#Preview("Card Grid") {
    LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
    ], spacing: 12) {
        SummaryCard(
            title: "Total",
            value: "$127.50",
            icon: "dollarsign.circle.fill",
            color: .green
        )
        
        SummaryCard(
            title: "People",
            value: "4",
            icon: "person.3.fill",
            color: .blue
        )
        
        SummaryCard(
            title: "Items",
            value: "8",
            icon: "list.bullet",
            color: .orange
        )
        
        SummaryCard(
            title: "Splits",
            value: "3",
            icon: "arrow.left.arrow.right",
            color: .purple
        )
    }
    .padding()
}

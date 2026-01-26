//
//  PageFilterChip.swift
//  SplitLens
//
//  Chip component for filtering items by source page in multi-image receipts
//

import SwiftUI

/// Chip button for filtering items by their source page
struct PageFilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.shared.selection()
            action()
        }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                    )
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            PageFilterChip(title: "All Pages", isSelected: true, count: 15) {}
            PageFilterChip(title: "Page 1", isSelected: false, count: 8) {}
            PageFilterChip(title: "Page 2", isSelected: false, count: 7) {}
        }
        
        HStack(spacing: 8) {
            PageFilterChip(title: "All Pages", isSelected: false, count: 15) {}
            PageFilterChip(title: "Page 1", isSelected: true, count: 8) {}
            PageFilterChip(title: "Page 2", isSelected: false, count: 7) {}
        }
    }
    .padding()
}

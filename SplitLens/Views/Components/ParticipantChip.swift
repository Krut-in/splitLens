//
//  ParticipantChip.swift
//  SplitLens
//
//  Reusable chip component for participant selection with liquid glass design
//

import SwiftUI

/// A chip component for participant selection with glassmorphism design
struct ParticipantChip: View {
    // MARK: - Properties
    
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            HapticFeedback.shared.mediumImpact()
            action()
        }) {
            HStack(spacing: 6) {
                Text(name)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        // Liquid glass selected state
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.blue.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        // Liquid glass unselected state
                        Color(.systemBackground)
                            .opacity(0.6)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(
                    color: isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.05),
                    radius: isSelected ? 8 : 2,
                    x: 0,
                    y: isSelected ? 4 : 1
                )
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(isSelected ? "selected" : "not selected")")
        .accessibilityHint("Double tap to \(isSelected ? "deselect" : "select") \(name)")
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview

#Preview("Single Chip") {
    VStack(spacing: 20) {
        ParticipantChip(name: "Alice", isSelected: true) {}
        ParticipantChip(name: "Bob", isSelected: false) {}
    }
    .padding()
}

#Preview("Chip Grid") {
    VStack(spacing: 16) {
        Text("Select Participants")
            .font(.headline)
        
        FlowLayout(spacing: 10) {
            ParticipantChip(name: "Alice", isSelected: true) {}
            ParticipantChip(name: "Bob", isSelected: false) {}
            ParticipantChip(name: "Charlie", isSelected: true) {}
            ParticipantChip(name: "Diana", isSelected: false) {}
            ParticipantChip(name: "Everyone", isSelected: false) {}
        }
    }
    .padding()
}

// MARK: - Flow Layout Helper (for chip wrapping)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(
                width: maxWidth,
                height: currentY + lineHeight
            )
        }
    }
}

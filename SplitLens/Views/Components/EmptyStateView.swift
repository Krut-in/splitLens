//
//  EmptyStateView.swift
//  SplitLens
//
//  Empty state component with liquid glass design
//

import SwiftUI

/// An empty state view with icon, message, and optional action
struct EmptyStateView: View {
    // MARK: - Properties
    
    let icon: String
    let message: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    // MARK: - Initialization
    
    init(
        icon: String,
        message: String,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.message = message
        self.actionLabel = actionLabel
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon with glass effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.15),
                                Color.gray.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            
            // Message
            Text(message)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Optional action button
            if let action = action, let label = actionLabel {
                Button(action: {
                    HapticFeedback.shared.mediumImpact()
                    action()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(label)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.9),
                                Color.blue.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityHint(action != nil ? "Double tap to \(actionLabel ?? "take action")" : "")
    }
}

// MARK: - Preview

#Preview("With Action") {
    EmptyStateView(
        icon: "tray.fill",
        message: "No receipts yet. Start your first scan!",
        actionLabel: "New Scan"
    ) {
        print("Action tapped")
    }
}

#Preview("Without Action") {
    EmptyStateView(
        icon: "exclamationmark.triangle.fill",
        message: "No items found in the image. Please try another photo."
    )
}

#Preview("Different States") {
    ScrollView {
        VStack(spacing: 60) {
            EmptyStateView(
                icon: "folder.fill",
                message: "No past receipts. Start your first scan!",
                actionLabel: "New Scan"
            ) {}
            
            Divider()
            
            EmptyStateView(
                icon: "person.3.fill",
                message: "Add at least 2 people to split the bill.",
                actionLabel: "Add Participant"
            ) {}
            
            Divider()
            
            EmptyStateView(
                icon: "photo.fill",
                message: "No image selected. Choose a photo or take one."
            )
        }
        .padding()
    }
}

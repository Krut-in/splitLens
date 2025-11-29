//
//  ActionButton.swift
//  SplitLens
//
//  Reusable action button component with liquid glass design
//

import SwiftUI

/// A customizable action button with icon, loading state, and liquid glass styling
struct ActionButton: View {
    // MARK: - Properties
    
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var isLoading: Bool = false
    var isDisabled: Bool = false
    
    // MARK: - Initialization
    
    init(
        icon: String,
        title: String,
        color: Color,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.color = color
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            if !isDisabled && !isLoading {
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                action()
            }
        }) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    // Gradient background
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(isDisabled ? 0.5 : 1.0),
                                    color.opacity(isDisabled ? 0.4 : 0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Subtle border
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            color.opacity(0.3),
                            lineWidth: 1
                        )
                }
            )
            .shadow(
                color: color.opacity(isDisabled ? 0.1 : 0.3),
                radius: isDisabled ? 3 : 8,
                x: 0,
                y: isDisabled ? 2 : 4
            )
            .opacity(isDisabled ? 0.6 : 1.0)
            .scaleEffect(isDisabled ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isDisabled)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "")
    }
}

// MARK: - Preview

#Preview("Standard Buttons") {
    VStack(spacing: 16) {
        ActionButton(
            icon: "square.and.arrow.down.fill",
            title: "Save to History",
            color: .blue
        ) {
            print("Save tapped")
        }
        
        ActionButton(
            icon: "square.and.arrow.up.fill",
            title: "Share Report",
            color: .purple
        ) {
            print("Share tapped")
        }
        
        ActionButton(
            icon: "doc.fill",
            title: "Export as PDF",
            color: .green
        ) {
            print("Export tapped")
        }
    }
    .padding()
}

#Preview("Button States") {
    VStack(spacing: 16) {
        ActionButton(
            icon: "checkmark.circle.fill",
            title: "Normal State",
            color: .blue
        ) {
            print("Tapped")
        }
        
        ActionButton(
            icon: "arrow.down.circle.fill",
            title: "Loading State",
            color: .purple,
            isLoading: true
        ) {
            print("Tapped")
        }
        
        ActionButton(
            icon: "xmark.circle.fill",
            title: "Disabled State",
            color: .gray,
            isDisabled: true
        ) {
            print("Tapped")
        }
    }
    .padding()
}

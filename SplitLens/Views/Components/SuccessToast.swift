//
//  SuccessToast.swift
//  SplitLens
//
//  Success notification toast with glassmorphism design
//

import SwiftUI

/// A success notification toast that slides in from the top
struct SuccessToast: View {
    // MARK: - Properties
    
    let message: String
    @Binding var isShowing: Bool
    
    // MARK: - State
    
    @State private var offset: CGFloat = -200
    
    // MARK: - Body
    
    var body: some View {
        if isShowing {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green,
                                    Color.green.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
            )
            .shadow(color: Color.green.opacity(0.4), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .offset(y: offset)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Slide in animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                    offset = 0
                }
                
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        offset = -200
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// MARK: - Toast Modifier

extension View {
    /// Shows a success toast notification
    /// - Parameters:
    ///   - message: The message to display
    ///   - isShowing: Binding to control toast visibility
    /// - Returns: View with toast overlay
    func successToast(message: String, isShowing: Binding<Bool>) -> some View {
        ZStack {
            self
            
            VStack {
                SuccessToast(message: message, isShowing: isShowing)
                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview("Success Toast") {
    struct PreviewWrapper: View {
        @State private var showToast = false
        
        var body: some View {
            VStack(spacing: 20) {
                Button("Show Success Toast") {
                    showToast = true
                }
                .buttonStyle(.borderedProminent)
                
                Text("Toast will auto-dismiss after 2 seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .successToast(message: "Session saved successfully!", isShowing: $showToast)
        }
    }
    
    return PreviewWrapper()
}

#Preview("Long Message Toast") {
    struct PreviewWrapper: View {
        @State private var showToast = false
        
        var body: some View {
            Button("Show Long Message") {
                showToast = true
            }
            .padding()
            .successToast(
                message: "Your report has been exported and is ready to share!",
                isShowing: $showToast
            )
        }
    }
    
    return PreviewWrapper()
}

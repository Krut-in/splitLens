//
//  AnimatedGradientBackground.swift
//  SplitLens
//
//  Reusable animated gradient background component with liquid glass design
//

import SwiftUI

/// Animated gradient background with smooth color transitions
///
/// This component provides a continuously animating gradient background
/// that creates a dynamic, liquid glass effect throughout the app.
///
/// **Usage:**
/// ```swift
/// ZStack {
///     AnimatedGradientBackground()
///     // Your content here
/// }
/// ```
struct AnimatedGradientBackground: View {
    // MARK: - State
    
    @State private var animateGradient = false
    
    // MARK: - Body
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.3),
                Color.purple.opacity(0.3),
                Color.pink.opacity(0.3),
                Color.blue.opacity(0.3)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .linear(duration: 3.0)
                .repeatForever(autoreverses: true)
            ) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AnimatedGradientBackground()
}

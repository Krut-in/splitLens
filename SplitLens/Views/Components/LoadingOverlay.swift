//
//  LoadingOverlay.swift
//  SplitLens
//
//  Full-screen loading indicator with liquid glass design
//

import SwiftUI

/// A full-screen loading overlay with glassmorphism
struct LoadingOverlay: View {
    // MARK: - Properties
    
    let message: String
    
    // MARK: - State
    
    @State private var isRotating = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Dark backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Glass card
            VStack(spacing: 20) {
                // Custom spinner
                ZStack {
                    ForEach(0..<8) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.8),
                                        Color.blue.opacity(0.3)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 8, height: 8)
                            .offset(y: -25)
                            .rotationEffect(.degrees(Double(index) * 45))
                            .opacity(isRotating ? 1.0 - (Double(index) * 0.1) : 0.3)
                    }
                }
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    .linear(duration: 1.0)
                        .repeatForever(autoreverses: false),
                    value: isRotating
                )
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(minWidth: 200)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.systemBackground).opacity(0.95),
                                    Color(.systemBackground).opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                }
            )
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.blue.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .onAppear {
            isRotating = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading: \(message)")
    }
}

// MARK: - Preview

#Preview("Loading Overlay") {
    ZStack {
        // Sample content
        VStack {
            Text("Content beneath")
            Image(systemName: "photo")
        }
        
        LoadingOverlay(message: "Processing receipt...")
    }
}

#Preview("Different Messages") {
    VStack(spacing: 40) {
        LoadingOverlay(message: "Processing...")
            .frame(height: 200)
        
        LoadingOverlay(message: "Analyzing image...")
            .frame(height: 200)
        
        LoadingOverlay(message: "Saving session...")
            .frame(height: 200)
    }
}

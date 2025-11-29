//
//  ContentView.swift
//  SplitLens
//
//  Root view of the application (placeholder for Part 2+)
//

import SwiftUI

struct ContentView: View {
    
    // MARK: - State
    
    @State private var showWelcome = true
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Logo/Icon
                    Image(systemName: "receipt.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                    
                    // App Title
                    VStack(spacing: 10) {
                        Text("SplitLens")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Smart Bill Splitting")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                        .frame(height: 40)
                    
                    // Feature List
                    VStack(alignment: .leading, spacing: 20) {
                        FeatureRow(icon: "camera.fill", text: "Scan receipts with your camera")
                        FeatureRow(icon: "person.3.fill", text: "Split bills among friends")
                        FeatureRow(icon: "chart.bar.fill", text: "Track your expenses")
                        FeatureRow(icon: "checkmark.circle.fill", text: "Save and share splits")
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Version Info
                    VStack(spacing: 8) {
                        Text("✅ Part 1: Foundation Complete")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("iOS 18.0+ | SwiftUI + MVVM")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 40)
                }
                .padding()
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40)
            
            Text(text)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

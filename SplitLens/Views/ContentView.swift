//
//  ContentView.swift
//  SplitLens
//
//  Root view of the application with liquid glass navigation
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .withDependencies()
}

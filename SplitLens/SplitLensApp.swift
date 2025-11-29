//
//  SplitLensApp.swift
//  SplitLens
//
//  Main app entry point
//

import SwiftUI

@main
struct SplitLensApp: App {
    
    // MARK: - Dependencies
    
    /// Centralized dependency container
    let dependencies = DependencyContainer.shared
    
    // MARK: - App Initialization
    
    init() {
        configureApp()
    }
    
    // MARK: - Scene Configuration
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withDependencies(dependencies)
        }
    }
    
    // MARK: - App Configuration
    
    private func configureApp() {
        // Validate Supabase configuration
        let config = SupabaseConfig.default
        
        if !config.isValid {
            print("⚠️ Warning: Supabase not configured")
            print("   Using mock services for development")
            if let error = config.validationError {
                print("   \(error)")
            }
        } else {
            print("✅ Supabase configured successfully")
        }
        
        // Additional app-level configuration can go here
        // - Analytics setup
        // - Crash reporting
        // - Feature flags
        // etc.
    }
}

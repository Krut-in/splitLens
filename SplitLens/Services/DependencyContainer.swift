//
//  DependencyContainer.swift
//  SplitLens
//
//  Centralized dependency injection container
//

import Foundation

/// Centralized dependency management for the app
final class DependencyContainer {
    
    /// Shared instance
    static let shared = DependencyContainer()
    
    // MARK: - Services
    
    /// OCR service for receipt scanning
    let ocrService: OCRServiceProtocol
    
    /// Database service for persistence
    let supabaseService: SupabaseServiceProtocol
    
    /// Bill splitting calculation service
    let billSplitEngine: BillSplitEngineProtocol
    
    /// Report generation service
    let reportEngine: ReportGenerationEngineProtocol
    
    // MARK: - Initialization
    
    private init() {
        // Initialize services
        // For Part 1, we use mock implementations
        // In Part 2+, we'll switch to real implementations
        
        #if DEBUG
        // Use mock services in debug mode for faster development
        self.ocrService = MockOCRService()
        self.supabaseService = MockSupabaseService.shared
        #else
        // Use real services in release mode
        // NOTE: Currently using mock services in release builds until Supabase is fully configured
        // To enable real services, update SupabaseConfig and switch to:
        // - SupabaseOCRService(edgeFunctionURL:apiKey:)  
        // - RealSupabaseService(projectURL:apiKey:)
        self.ocrService = MockOCRService()
        self.supabaseService = MockSupabaseService.shared
        #endif
        
        // These services are the same in debug and release
        self.billSplitEngine = BillSplitEngine()
        self.reportEngine = ReportGenerationEngine()
    }
    
    // MARK: - Factory Methods (for custom configurations)
    
    /// Creates a custom OCR service with specific configuration
    static func createOCRService(withConfig config: SupabaseConfig) -> OCRServiceProtocol {
        if config.useMockServices {
            return MockOCRService()
        } else {
            guard let url = URL(string: config.ocrFunctionURL) else {
                fatalError("Invalid OCR function URL")
            }
            return SupabaseOCRService(edgeFunctionURL: url, apiKey: config.apiKey)
        }
    }
    
    /// Creates a custom database service with specific configuration
    static func createDatabaseService(withConfig config: SupabaseConfig) -> SupabaseServiceProtocol {
        if config.useMockServices {
            return MockSupabaseService.shared
        } else {
            return RealSupabaseService(
                projectURL: config.projectURL,
                apiKey: config.apiKey
            )
        }
    }
}

// MARK: - Dependency Injection via Environment

import SwiftUI

/// Environment key for dependency container
private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

/// View modifier to inject dependencies
extension View {
    func withDependencies(_ container: DependencyContainer = .shared) -> some View {
        self.environment(\.dependencies, container)
    }
}

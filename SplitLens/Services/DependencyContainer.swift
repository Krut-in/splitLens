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
        // Get Supabase configuration
        let config = SupabaseConfig.default
        
        // Use real services if:
        // 1. useMockServices is false AND
        // 2. Configuration is valid (has real credentials)
        let useRealServices = !config.useMockServices && config.isValid
        
        if useRealServices {
            // Real Supabase services
            self.ocrService = DependencyContainer.createOCRService(withConfig: config)
            self.supabaseService = DependencyContainer.createDatabaseService(withConfig: config)
            
            print("✅ Using REAL Supabase services")
            print("   Project: \(config.projectURL)")
        } else {
            // Mock services for development/testing
            self.ocrService = MockOCRService()
            self.supabaseService = MockSupabaseService.shared
            
            if !config.isValid {
                print("⚠️ Using MOCK services: Invalid Supabase configuration")
                if let error = config.validationError {
                    print("   Error: \(error)")
                }
            } else {
                print("ℹ️ Using MOCK services: useMockServices = true")
            }
        }
        
        // These services are the same regardless of config
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

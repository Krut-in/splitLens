//
//  DependencyContainer.swift
//  SplitLens
//
//  Centralized dependency injection container
//

import Foundation
import SwiftData

/// Centralized dependency management for the app
final class DependencyContainer {
    
    /// Shared instance
    static let shared = DependencyContainer()
    
    // MARK: - Services
    
    /// OCR service for receipt scanning
    let ocrService: OCRServiceProtocol
    
    /// Database service for persistence
    let supabaseService: SupabaseServiceProtocol

    /// Local store for durable session history.
    let sessionStore: SessionStoreProtocol

    /// Saved participant groups store.
    let groupStore: GroupStoreProtocol

    /// Local receipt image store.
    let receiptImageStore: ReceiptImageStoreProtocol

    /// Assignment pattern store for Smart Assignments.
    let patternStore: PatternStoreProtocol

    /// Pattern learning engine for Smart Assignments.
    let patternLearningEngine: PatternLearningEngineProtocol?

    /// In-memory cache of in-progress scan data so that downstream views
    /// preserve their state when the user navigates back and forth.
    let scanDraftStore: ScanDraftStoreProtocol = InMemoryScanDraftStore()

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

        // All stores share a single ModelContainer to avoid SwiftData conflicts.
        let resolvedStores: (
            session: SessionStoreProtocol,
            group: GroupStoreProtocol,
            pattern: PatternStoreProtocol,
            engine: PatternLearningEngineProtocol?
        )

        do {
            let container = try ModelContainer(for: StoredSession.self, StoredGroup.self, StoredPattern.self)
            let sessionStoreImpl = try SwiftDataSessionStore(modelContainer: container)
            let groupStoreImpl = try SwiftDataGroupStore(modelContainer: container)
            let patternStoreImpl = try SwiftDataPatternStore(modelContainer: container)
            let engineImpl = PatternLearningEngine(patternStore: patternStoreImpl)
            resolvedStores = (sessionStoreImpl, groupStoreImpl, patternStoreImpl, engineImpl)
        } catch {
            ErrorHandler.shared.log(error, context: "DependencyContainer.SwiftData")
            let inMemoryPatternStore = InMemoryPatternStore()
            let engineImpl = PatternLearningEngine(patternStore: inMemoryPatternStore)
            resolvedStores = (InMemorySessionStore(), InMemoryGroupStore(), inMemoryPatternStore, engineImpl)
        }

        self.sessionStore = resolvedStores.session
        self.groupStore = resolvedStores.group
        self.patternStore = resolvedStores.pattern
        self.patternLearningEngine = resolvedStores.engine

        self.receiptImageStore = LocalReceiptImageStore()

        // These services are the same regardless of config
        self.billSplitEngine = AdvancedBillSplitEngine()
        self.reportEngine = ReportGenerationEngine()
    }
    
    // MARK: - Factory Methods (for custom configurations)
    
    /// Creates a custom OCR service with specific configuration
    static func createOCRService(withConfig config: SupabaseConfig) -> OCRServiceProtocol {
        if config.useMockServices {
            return MockOCRService()
        } else {
            guard let url = URL(string: config.ocrFunctionURL) else {
                print("⚠️ Invalid OCR URL: \(config.ocrFunctionURL)")
                print("   Falling back to MockOCRService for development")
                return MockOCRService()
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

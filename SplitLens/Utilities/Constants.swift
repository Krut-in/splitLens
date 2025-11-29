//
//  Constants.swift
//  SplitLens
//
//  Centralized application constants and configuration values
//

import Foundation

/// Application-wide constants organized by feature area
///
/// This enum-based namespace consolidates magic numbers and configuration
/// values that were previously hardcoded throughout the codebase.
///
/// **Benefits:**
/// - Single source of truth for configuration
/// - Easy to modify behavior across the app
/// - Self-documenting code
/// - Type-safe constants
enum AppConstants {
    
    // MARK: - OCR Configuration
    
    /// Constants related to OCR processing
    enum OCR {
        /// Default timeout for OCR requests (seconds)
        static let defaultTimeout: TimeInterval = 30.0
        
        /// Maximum number of retry attempts for failed OCR requests
        static let maxRetries: Int = 3
        
        /// Simulated network delay for mock services (nanoseconds)
        static let mockDelay: UInt64 = 500_000_000 // 0.5 seconds
        
        /// Mock delay per image (nanoseconds)
        static let mockDelayPerImage: UInt64 = 500_000_000 // 0.5 seconds
        
        /// Long mock delay for full OCR simulation (nanoseconds)
        static let mockOCRDelay: UInt64 = 2_000_000_000 // 2 seconds
    }
    
    // MARK: - Bill Split Configuration
    
    /// Constants related to bill splitting calculations
    enum BillSplit {
        /// Allowed variance threshold as percentage (1% = 1.0)
        ///
        /// If the difference between calculated total and entered total
        /// exceeds this percentage, a warning is shown
        static let varianceThreshold: Double = 1.0
        
        /// Minimum number of participants required to split a bill
        static let minimumParticipants: Int = 2
        
        /// Minimum amount for a meaningful split (dollars)
        ///
        /// Splits below this amount are considered insignificant
        static let minimumSplitAmount: Double = 0.01
    }
    
    // MARK: - Validation Configuration
    
    /// Constants for data validation rules
    enum Validation {
        /// Maximum allowed length for participant names
        static let maxParticipantNameLength: Int = 50
        
        /// Tolerance for total amount discrepancies (dollars)
        ///
        /// Discrepancies below this amount are ignored
        static let totalDiscrepancyTolerance: Double = 0.05
        
        /// Minimum item quantity
        static let minimumQuantity: Int = 1
        
        /// Minimum item price (dollars)
        static let minimumPrice: Double = 0.0
    }
    
    // MARK: - Database Configuration
    
    /// Constants for database operations
    enum Database {
        /// Default session fetch limit
        static let defaultFetchLimit: Int = 20
        
        /// Mock database delay (nanoseconds)
        static let mockDatabaseDelay: UInt64 = 300_000_000 // 0.3 seconds
        
        /// Session fetch delay (nanoseconds)
        static let sessionFetchDelay: UInt64 = 500_000_000 // 0.5 seconds
    }
    
    // MARK: - UI Configuration
    
    /// Constants for UI behavior
    enum UI {
        /// Default animation duration (seconds)
        static let animationDuration: TimeInterval = 0.3
        
        // Add more UI-related constants as needed
    }
}

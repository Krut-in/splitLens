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
    
    // MARK: - Multi-Image Configuration
    
    /// Constants for multi-image receipt processing
    enum MultiImage {
        /// Maximum number of images allowed per receipt
        static let maxImages: Int = 10
        
        /// Threshold to warn about API costs
        static let warningThreshold: Int = 5
        
        /// Delay between API requests (nanoseconds) - 1 second
        static let delayBetweenRequests: UInt64 = 1_000_000_000
    }
    
    // MARK: - Fee Allocation Configuration
    
    /// Constants for fee allocation
    enum FeeAllocation {
        /// Default strategy for allocating fees
        static let defaultStrategy: FeeAllocationStrategy = .proportional
        
        /// Supported fee types for allocation
        static let supportedFeeTypes = ["tax", "tip", "delivery", "service"]
    }
    
    // MARK: - Groups Configuration

    /// Constants related to saved participant groups
    enum Groups {
        /// Maximum number of saved groups allowed
        static let maxGroups: Int = 20

        /// Maximum members per group
        static let maxMembersPerGroup: Int = 20

        /// Minimum members to form a group
        static let minMembersPerGroup: Int = 2

        /// Maximum characters for a group name
        static let maxGroupNameLength: Int = 30

        /// Available SF Symbol icon choices for group customisation
        static let availableIcons: [String] = [
            "person.3.fill",
            "house.fill",
            "briefcase.fill",
            "fork.knife",
            "airplane",
            "heart.fill",
            "star.fill",
            "flag.fill"
        ]
    }

    // MARK: - Smart Assignment Configuration

    /// Constants for the Smart Assignments (pattern learning) feature
    enum SmartAssignment {
        /// Minimum consecutive times an item must be assigned the same way before suggestions appear
        static let minimumConsecutiveHits: Int = 2

        /// Number of days after which a pattern is considered stale (not shown in suggestions)
        static let stalenessDays: Int = 90

        /// Number of days after which a pattern is eligible for cleanup/deletion
        static let cleanupDays: Int = 180

        /// Maximum number of patterns to store on-device
        static let maxPatterns: Int = 500

        /// Minimum Levenshtein similarity (0.0-1.0) to consider two item names a match
        static let nameSimilarityThreshold: Double = 0.80

        /// Maximum item name character length to learn (skip unusually long names)
        static let maxItemNameLength: Int = 80
    }

    // MARK: - Formatters

    /// Cached formatters to improve performance by avoiding repeated instantiation
    enum Formatters {
        /// Date and time formatter (e.g., "Nov 28, 2024 at 3:45 PM")
        ///
        /// **Performance**: DateFormatter creation is expensive, this singleton
        /// reduces overhead from O(n) to O(1) for date formatting operations
        static let dateTime: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }()
        
        /// Date-only formatter (e.g., "Nov 28, 2024")
        ///
        /// Used for list views and session history
        static let date: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter
        }()
    }
}

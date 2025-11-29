//
//  CurrencyFormatter.swift
//  SplitLens
//
//  Centralized currency formatting utility
//  Consolidates duplicate formatting logic across the codebase
//

import Foundation

/// Shared currency formatting utility with cached NumberFormatter instance
///
/// This singleton provides consistent currency formatting across the entire app
/// and improves performance by reusing a single NumberFormatter instance
/// instead of creating new ones for each formatting operation.
///
/// **Usage:**
/// ```swift
/// let formatted = CurrencyFormatter.shared.format(12.50)
/// // Returns: "$12.50"
/// ```
///
/// **Performance Benefits:**
/// - Single cached NumberFormatter instance (expensive to create)
/// - Thread-safe singleton pattern
/// - Consistent formatting rules app-wide
final class CurrencyFormatter {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide use
    static let shared = CurrencyFormatter()
    
    // MARK: - Private Properties
    
    /// Cached NumberFormatter instance configured for USD currency
    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f
    }()
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Public Methods
    
    /// Formats a Double value as a currency string
    ///
    /// - Parameter value: The monetary value to format
    /// - Returns: Formatted currency string (e.g., "$12.50")
    ///
    /// **Examples:**
    /// ```swift
    /// CurrencyFormatter.shared.format(12.50)    // "$12.50"
    /// CurrencyFormatter.shared.format(1000.00)  // "$1,000.00"
    /// CurrencyFormatter.shared.format(0.99)     // "$0.99"
    /// CurrencyFormatter.shared.format(12.999)   // "$13.00" (rounded)
    /// ```
    func format(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    /// Formats a Double value with custom currency code
    ///
    /// - Parameters:
    ///   - value: The monetary value to format
    ///   - currencyCode: ISO 4217 currency code (e.g., "EUR", "GBP")
    /// - Returns: Formatted currency string
    ///
    /// **Note:** This method creates a temporary formatter, use sparingly
    func format(_ value: Double, currencyCode: String) -> String {
        let customFormatter = NumberFormatter()
        customFormatter.numberStyle = .currency
        customFormatter.currencyCode = currencyCode
        customFormatter.maximumFractionDigits = 2
        return customFormatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Extension for Double

extension Double {
    /// Convenience property to format as currency
    ///
    /// **Usage:**
    /// ```swift
    /// let price = 12.50
    /// print(price.asCurrency) // "$12.50"
    /// ```
    var asCurrency: String {
        CurrencyFormatter.shared.format(self)
    }
}

//
//  DoubleExtensions.swift
//  SplitLens
//
//  Extensions for Double to support bill splitting calculations
//

import Foundation

// MARK: - Rounding Extension

extension Double {
    /// Rounds the value to a specified number of decimal places
    ///
    /// This is critical for monetary calculations to ensure consistent rounding
    /// behavior across all bill split calculations.
    ///
    /// - Parameter places: Number of decimal places to round to
    /// - Returns: Rounded value
    ///
    /// Example:
    /// ```swift
    /// let value = 12.3456
    /// let rounded = value.rounded(to: 2) // 12.35
    /// ```
    func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
    
    /// Convenience method for currency rounding (2 decimal places)
    var currencyRounded: Double {
        rounded(to: 2)
    }
}

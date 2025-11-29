//
//  ValidationHelper.swift
//  SplitLens
//
//  Shared validation utilities and protocol
//

import Foundation

// MARK: - Validatable Protocol

/// Protocol for types that can validate themselves
///
/// Conforming types implement `validate()` to return an array of
/// validation error messages. The `isValid` property is provided
/// automatically based on whether any errors exist.
///
/// **Usage:**
/// ```swift
/// final class MyViewModel: ObservableObject, Validatable {
///     func validate() -> [String] {
///         var errors: [String] = []
///         if someCondition {
///             errors.append("Error message")
///         }
///         return errors
///     }
/// }
/// ```
protocol Validatable {
    /// Validates the current state and returns error messages
    ///
    /// - Returns: Array of human-readable error messages (empty if valid)
    func validate() -> [String]
    
    /// Whether the current state is valid
    var isValid: Bool { get }
}

// MARK: - Default Implementation

extension Validatable {
    /// Default implementation: valid if no errors
    var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Validation Helper Functions

/// Collection of reusable validation helper methods
///
/// These methods provide common validation patterns used throughout
/// the app, reducing duplication in ViewModel validation logic.
enum ValidationHelper {
    
    // MARK: - Array Validation
    
    /// Validates that an array is not empty and meets minimum count requirement
    ///
    /// - Parameters:
    ///   - array: Array to validate
    ///   - fieldName: Human-readable field name for error message
    ///   - minimum: Minimum required count (default: 1)
    /// - Returns: Error message if invalid, nil if valid
    ///
    /// **Example:**
    /// ```swift
    /// if let error = ValidationHelper.validateNonEmpty(participants, fieldName: "Participants", minimum: 2) {
    ///     errors.append(error)
    /// }
    /// ```
    static func validateNonEmpty<T>(
        _ array: [T],
        fieldName: String,
        minimum: Int = 1
    ) -> String? {
        if array.isEmpty {
            return "\(fieldName) cannot be empty"
        }
        if array.count < minimum {
            if minimum == 1 {
                return "\(fieldName) must have at least 1 item"
            } else {
                return "\(fieldName) must have at least \(minimum) items"
            }
        }
        return nil
    }
    
    // MARK: - Numeric Validation
    
    /// Validates that a numeric value is positive (greater than 0)
    ///
    /// - Parameters:
    ///   - amount: Value to validate
    ///   - fieldName: Human-readable field name for error message
    /// - Returns: Error message if invalid, nil if valid
    ///
    /// **Example:**
    /// ```swift
    /// if let error = ValidationHelper.validatePositiveAmount(totalAmount, fieldName: "Total amount") {
    ///     errors.append(error)
    /// }
    /// ```
    static func validatePositiveAmount(
        _ amount: Double,
        fieldName: String
    ) -> String? {
        amount > 0 ? nil : "\(fieldName) must be greater than 0"
    }
    
    /// Validates that a value is non-negative (>= 0)
    ///
    /// - Parameters:
    ///   - amount: Value to validate
    ///   - fieldName: Human-readable field name for error message
    /// - Returns: Error message if invalid, nil if valid
    static func validateNonNegativeAmount(
        _ amount: Double,
        fieldName: String
    ) -> String? {
        amount >= 0 ? nil : "\(fieldName) cannot be negative"
    }
    
    /// Validates that an integer value is positive
    ///
    /// - Parameters:
    ///   - value: Integer to validate
    ///   - fieldName: Human-readable field name for error message
    /// - Returns: Error message if invalid, nil if valid
    static func validatePositiveInteger(
        _ value: Int,
        fieldName: String
    ) -> String? {
        value > 0 ? nil : "\(fieldName) must be greater than 0"
    }
    
    // MARK: - String Validation
    
    /// Validates that a string is not empty (after trimming whitespace)
    ///
    /// - Parameters:
    ///   - string: String to validate
    ///   - fieldName: Human-readable field name for error message
    /// - Returns: Error message if invalid, nil if valid
    ///
    /// **Example:**
    /// ```swift
    /// if let error = ValidationHelper.validateNonEmptyString(paidBy, fieldName: "Payer") {
    ///     errors.append(error)
    /// }
    /// ```
    static func validateNonEmptyString(
        _ string: String,
        fieldName: String
    ) -> String? {
        string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? "\(fieldName) cannot be empty" 
            : nil
    }
    
    /// Validates string length constraints
    ///
    /// - Parameters:
    ///   - string: String to validate
    ///   - fieldName: Human-readable field name for error message
    ///   - maxLength: Maximum allowed length
    /// - Returns: Error message if invalid, nil if valid
    static func validateStringLength(
        _ string: String,
        fieldName: String,
        maxLength: Int
    ) -> String? {
        string.count <= maxLength 
            ? nil 
            : "\(fieldName) is too long (max \(maxLength) characters)"
    }
    
    // MARK: - Membership Validation
    
    /// Validates that a value exists in a collection
    ///
    /// - Parameters:
    ///   - value: Value to check
    ///   - collection: Collection to search
    ///   - fieldName: Human-readable field name for error message
    ///   - collectionName: Human-readable collection name
    /// - Returns: Error message if invalid, nil if valid
    ///
    /// **Example:**
    /// ```swift
    /// if let error = ValidationHelper.validateMembership(
    ///     paidBy,
    ///     in: participants,
    ///     fieldName: "Payer",
    ///     collectionName: "participants"
    /// ) {
    ///     errors.append(error)
    /// }
    /// ```
    static func validateMembership<T: Equatable>(
        _ value: T,
        in collection: [T],
        fieldName: String,
        collectionName: String
    ) -> String? {
        collection.contains(value) 
            ? nil 
            : "\(fieldName) must be in \(collectionName)"
    }
    
    // MARK: - Uniqueness Validation
    
    /// Validates that all elements in array are unique
    ///
    /// - Parameters:
    ///   - array: Array to check for duplicates
    ///   - fieldName: Human-readable field name for error message
    /// - Returns: Error message if duplicates found, nil if all unique
    static func validateUnique<T: Hashable>(
        _ array: [T],
        fieldName: String
    ) -> String? {
        let uniqueSet = Set(array)
        return uniqueSet.count == array.count 
            ? nil 
            : "\(fieldName) must not contain duplicates"
    }
}

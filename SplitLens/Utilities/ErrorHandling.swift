//
//  ErrorHandling.swift
//  SplitLens
//
//  Centralized error handling for the app
//

import Foundation

// MARK: - App Error Protocol

/// Protocol for all app-specific errors
protocol AppError: LocalizedError {
    /// User-friendly error message
    var userMessage: String { get }
    
    /// Technical error details (for logging/debugging)
    var technicalDetails: String { get }
}

// MARK: - OCR Errors

/// Errors that can occur during OCR processing
enum OCRError: AppError {
    case imageProcessingFailed
    case noTextDetected
    case invalidImageFormat
    case invalidImage
    case ocrServiceUnavailable
    case networkError(Error)
    case parsingFailed(String)
    case timeout
    case unknown(Error)
    
    var userMessage: String {
        switch self {
        case .imageProcessingFailed:
            return "Unable to process the image. Please try again with a clearer photo."
        case .noTextDetected:
            return "No text was detected in the image. Please ensure the receipt is clearly visible."
        case .invalidImageFormat:
            return "The image format is not supported. Please use JPG or PNG."
        case .invalidImage:
            return "Image quality too low. Try better lighting."
        case .ocrServiceUnavailable:
            return "OCR service is currently unavailable. Please try again later."
        case .networkError:
            return "Network error occurred. Please check your internet connection."
        case .parsingFailed:
            return "Unable to extract receipt data. Please try manual entry."
        case .timeout:
            return "Request timed out. Please retry."
        case .unknown:
            return "An unexpected error occurred during OCR processing."
        }
    }
    
    var technicalDetails: String {
        switch self {
        case .imageProcessingFailed:
            return "Image preprocessing or conversion failed"
        case .noTextDetected:
            return "OCR engine returned no text results"
        case .invalidImageFormat:
            return "Image format validation failed"
        case .invalidImage:
            return "Image size too small or quality insufficient"
        case .ocrServiceUnavailable:
            return "OCR endpoint returned 503 or timeout"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingFailed(let details):
            return "Data parsing failed: \(details)"
        case .timeout:
            return "Request exceeded 30-second timeout"
        case .unknown(let error):
            return "Unknown OCR error: \(error.localizedDescription)"
        }
    }
    
    var errorDescription: String? { userMessage }
}

// MARK: - Database Errors

/// Errors that can occur during database operations
enum DatabaseError: AppError {
    case connectionFailed
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case invalidData
    case unauthorized
    case networkError(Error)
    case unknown(Error)
    
    var userMessage: String {
        switch self {
        case .connectionFailed:
            return "Unable to connect to the database. Please check your internet connection."
        case .saveFailed:
            return "Failed to save your session. Please try again."
        case .fetchFailed:
            return "Unable to load data. Please try again."
        case .deleteFailed:
            return "Failed to delete the session. Please try again."
        case .invalidData:
            return "The data is invalid or corrupted."
        case .unauthorized:
            return "You don't have permission to perform this action."
        case .networkError:
            return "Network error occurred. Please check your internet connection."
        case .unknown:
            return "An unexpected database error occurred."
        }
    }
    
    var technicalDetails: String {
        switch self {
        case .connectionFailed:
            return "Database connection initialization failed"
        case .saveFailed(let details):
            return "Save operation failed: \(details)"
        case .fetchFailed(let details):
            return "Fetch operation failed: \(details)"
        case .deleteFailed(let details):
            return "Delete operation failed: \(details)"
        case .invalidData:
            return "Data validation or deserialization failed"
        case .unauthorized:
            return "Authentication or authorization failed"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown database error: \(error.localizedDescription)"
        }
    }
    
    var errorDescription: String? { userMessage }
}

// MARK: - Validation Errors

/// Errors that can occur during data validation
enum ValidationError: AppError {
    case emptyParticipants
    case insufficientParticipants
    case emptyItems
    case invalidItemData(String)
    case invalidTotal
    case unassignedItems(Int)
    case payerNotInParticipants
    case duplicateParticipantNames
    
    var userMessage: String {
        switch self {
        case .emptyParticipants:
            return "Please add at least one participant."
        case .insufficientParticipants:
            return "You need at least 2 participants to split a bill."
        case .emptyItems:
            return "Please add at least one item to the receipt."
        case .invalidItemData(let details):
            return "Invalid item data: \(details)"
        case .invalidTotal:
            return "Total amount must be greater than zero."
        case .unassignedItems(let count):
            return "\(count) item(s) haven't been assigned to anyone yet."
        case .payerNotInParticipants:
            return "The person who paid must be in the participants list."
        case .duplicateParticipantNames:
            return "Participant names must be unique."
        }
    }
    
    var technicalDetails: String {
        switch self {
        case .emptyParticipants:
            return "Participants array is empty"
        case .insufficientParticipants:
            return "Participants count < 2"
        case .emptyItems:
            return "Items array is empty"
        case .invalidItemData(let details):
            return "Item validation failed: \(details)"
        case .invalidTotal:
            return "Total amount <= 0"
        case .unassignedItems(let count):
            return "\(count) items with empty assignedTo array"
        case .payerNotInParticipants:
            return "paidBy value not found in participants array"
        case .duplicateParticipantNames:
            return "Participants array contains duplicate values"
        }
    }
    
    var errorDescription: String? { userMessage }
}

// MARK: - Bill Split Errors

/// Errors that can occur during bill splitting calculations
enum BillSplitError: AppError {
    case noParticipants
    case noItems
    case calculationFailed(String)
    case roundingError
    case invalidConfiguration
    
    var userMessage: String {
        switch self {
        case .noParticipants:
            return "Cannot calculate splits without participants."
        case .noItems:
            return "Cannot calculate splits without items."
        case .calculationFailed:
            return "Failed to calculate bill splits. Please verify your data."
        case .roundingError:
            return "Rounding error in calculations. Please review the amounts."
        case .invalidConfiguration:
            return "Invalid split configuration. Please check your data."
        }
    }
    
    var technicalDetails: String {
        switch self {
        case .noParticipants:
            return "Empty participants array in split calculation"
        case .noItems:
            return "Empty items array in split calculation"
        case .calculationFailed(let details):
            return "Split calculation failed: \(details)"
        case .roundingError:
            return "Sum of splits doesn't match total within tolerance"
        case .invalidConfiguration:
            return "Split configuration validation failed"
        }
    }
    
    var errorDescription: String? { userMessage }
}

// MARK: - Storage Errors

/// Errors that can occur during storage operations
enum StorageError: AppError {
    case uploadFailed(String)
    case quotaExceeded
    case invalidImageFormat
    case networkError(Error)
    case unknown(Error)
    
    var userMessage: String {
        switch self {
        case .uploadFailed:
            return "Failed to upload image. Please try again."
        case .quotaExceeded:
            return "Storage quota exceeded. Please contact support."
        case .invalidImageFormat:
            return "Invalid image format. Please use JPG or PNG."
        case .networkError:
            return "Network error occurred. Please check your connection."
        case .unknown:
            return "An unexpected storage error occurred."
        }
    }
    
    var technicalDetails: String {
        switch self {
        case .uploadFailed(let details):
            return "Storage upload failed: \(details)"
        case .quotaExceeded:
            return "Storage quota limit reached"
        case .invalidImageFormat:
            return "Image format not supported by storage"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown storage error: \(error.localizedDescription)"
        }
    }
    
    var errorDescription: String? { userMessage }
}

// MARK: - Error Handler

/// Centralized error logging and handling
final class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    /// Logs an error for debugging
    func log(_ error: Error, context: String = "") {
        let contextPrefix = context.isEmpty ? "" : "[\(context)] "
        
        if let appError = error as? AppError {
            print("❌ \(contextPrefix)\(appError.userMessage)")
            print("   Technical: \(appError.technicalDetails)")
        } else {
            print("❌ \(contextPrefix)\(error.localizedDescription)")
        }
    }
    
    /// Gets a user-friendly message from any error
    func userMessage(for error: Error) -> String {
        if let appError = error as? AppError {
            return appError.userMessage
        } else {
            return "An unexpected error occurred. Please try again."
        }
    }
}

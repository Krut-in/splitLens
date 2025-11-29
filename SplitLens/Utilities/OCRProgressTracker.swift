//
//  OCRProgressTracker.swift
//  SplitLens
//
//  Tracks OCR processing progress and provides state management
//

import Foundation
import Observation

// MARK: - OCR Progress State

/// Represents the current state of OCR processing
enum OCRProgressState: Equatable {
    case idle
    case preprocessing(imageIndex: Int, total: Int)
    case uploading(imageIndex: Int, total: Int, progress: Double)
    case analyzing(imageIndex: Int, total: Int)
    case parsing
    case completed([ReceiptItem])
    case failed(String) // Store error message as String for Equatable conformance
    case cancelled
    
    /// Human-readable description of the current state
    var description: String {
        switch self {
        case .idle:
            return "Ready to scan"
        case .preprocessing(let index, let total):
            return "Preparing image \(index + 1) of \(total)..."
        case .uploading(let index, let total, let progress):
            let percentage = Int(progress * 100)
            return "Uploading image \(index + 1) of \(total)... \(percentage)%"
        case .analyzing(let index, let total):
            return "Analyzing receipt \(index + 1) of \(total)..."
        case .parsing:
            return "Extracting items..."
        case .completed(let items):
            return "Found \(items.count) items"
        case .failed(let message):
            return "Error: \(message)"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    /// Whether the operation is currently in progress
    var isInProgress: Bool {
        switch self {
        case .preprocessing, .uploading, .analyzing, .parsing:
            return true
        default:
            return false
        }
    }
    
    /// Progress percentage (0.0 to 1.0)
    var progressPercentage: Double {
        switch self {
        case .idle, .cancelled:
            return 0.0
        case .preprocessing(let index, let total):
            return Double(index) / Double(total) * 0.2 // 0-20%
        case .uploading(let index, let total, let progress):
            let baseProgress = Double(index) / Double(total) * 0.3
            let currentProgress = progress * (1.0 / Double(total)) * 0.3
            return 0.2 + baseProgress + currentProgress // 20-50%
        case .analyzing(let index, let total):
            return 0.5 + (Double(index) / Double(total) * 0.4) // 50-90%
        case .parsing:
            return 0.95 // 95%
        case .completed:
            return 1.0 // 100%
        case .failed:
            return 0.0
        }
    }
}

// MARK: - OCR Progress Tracker

/// Observable class to track OCR processing progress
@Observable
final class OCRProgressTracker {
    
    // MARK: - Properties
    
    /// Current state of OCR processing
    var state: OCRProgressState = .idle
    
    /// Whether the operation can be cancelled
    var canCancel: Bool = false
    
    /// Start time of the current operation
    private var startTime: Date?
    
    /// Estimated time remaining in seconds
    var estimatedTimeRemaining: TimeInterval? {
        guard let startTime = startTime,
              state.isInProgress,
              state.progressPercentage > 0 else {
            return nil
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let estimatedTotal = elapsed / state.progressPercentage
        return max(0, estimatedTotal - elapsed)
    }
    
    // MARK: - State Management
    
    /// Starts tracking a new OCR operation
    func start() {
        state = .idle
        canCancel = true
        startTime = Date()
    }
    
    /// Updates the current state
    func updateState(_ newState: OCRProgressState) {
        state = newState
        
        // Disable cancellation when completed/failed/cancelled
        switch newState {
        case .completed, .failed, .cancelled:
            canCancel = false
            startTime = nil
        default:
            break
        }
    }
    
    /// Resets the tracker to idle state
    func reset() {
        state = .idle
        canCancel = false
        startTime = nil
    }
    
    /// Formats time remaining as a readable string
    func formattedTimeRemaining() -> String? {
        guard let time = estimatedTimeRemaining else {
            return nil
        }
        
        if time < 60 {
            return "\(Int(time))s remaining"
        } else {
            let minutes = Int(time / 60)
            let seconds = Int(time.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s remaining"
        }
    }
}

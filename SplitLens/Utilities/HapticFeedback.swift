//
//  HapticFeedback.swift
//  SplitLens
//
//  Provides tactile feedback for user interactions
//

import UIKit

// MARK: - Haptic Feedback Manager

/// Manages haptic feedback throughout the app
final class HapticFeedback {
    
    // MARK: - Singleton
    
    static let shared = HapticFeedback()
    
    private init() {}
    
    // MARK: - Feedback Generators
    
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    // MARK: - Public Methods
    
    /// Provides success feedback (OCR completed, session saved, etc.)
    func success() {
        notificationGenerator.notificationOccurred(.success)
    }
    
    /// Provides error feedback (OCR failed, network error, etc.)
    func error() {
        notificationGenerator.notificationOccurred(.error)
    }
    
    /// Provides warning feedback (low image quality, timeout, etc.)
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }
    
    /// Provides light impact feedback (button taps, toggles, etc.)
    func lightImpact() {
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        lightImpact.impactOccurred()
    }
    
    /// Provides medium impact feedback (card swipes, deletions, etc.)
    func mediumImpact() {
        impactGenerator.impactOccurred()
    }
    
    /// Provides heavy impact feedback (important actions, completions, etc.)
    func heavyImpact() {
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        heavyImpact.impactOccurred()
    }
    
    /// Provides selection feedback (scrolling through items, picker changes, etc.)
    func selection() {
        selectionGenerator.selectionChanged()
    }
    
    /// Prepares haptic engine for imminent feedback (reduces latency)
    func prepare() {
        notificationGenerator.prepare()
        impactGenerator.prepare()
        selectionGenerator.prepare()
    }
}

// MARK: - OCR-Specific Haptics

extension HapticFeedback {
    
    /// Feedback for starting OCR processing
    func ocrStarted() {
        lightImpact()
    }
    
    /// Feedback for OCR progress updates
    func ocrProgress() {
        selection()
    }
    
    /// Feedback for OCR completion
    func ocrCompleted() {
        success()
    }
    
    /// Feedback for OCR failure
    func ocrFailed() {
        error()
    }
    
    /// Feedback for image quality warning
    func imageQualityWarning() {
        warning()
    }
    
    /// Feedback for cancellation
    func cancelled() {
        mediumImpact()
    }
}

// MARK: - UI Interaction Haptics

extension HapticFeedback {
    
    /// Feedback for item assignment
    func itemAssigned() {
        lightImpact()
    }
    
    /// Feedback for item unassignment
    func itemUnassigned() {
        lightImpact()
    }
    
    /// Feedback for adding participant
    func participantAdded() {
        lightImpact()
    }
    
    /// Feedback for removing participant
    func participantRemoved() {
        mediumImpact()
    }
    
    /// Feedback for session deletion
    func sessionDeleted() {
        heavyImpact()
    }
    
    /// Feedback for session saved
    func sessionSaved() {
        success()
    }
    
    // MARK: - Context-Aware Haptics
    
    /// Haptic for item assignment changes (assigning/unassigning items to people)
    func itemAssignmentChanged() {
        selectionGenerator.selectionChanged()
    }
    
    /// Haptic for when split calculation completes successfully
    func splitCalculated() {
        success()
    }
}

//
//  ParticipantsViewModel.swift
//  SplitLens
//
//  ViewModel for managing participants and payer selection
//

import Foundation
import SwiftUI

@MainActor
final class ParticipantsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// List of participant names
    @Published var participants: [String] = []
    
    /// Name of the person who paid
    @Published var paidBy: String = ""
    
    /// New participant name being entered
    @Published var newParticipantName: String = ""
    
    /// Error message for display
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    
    /// Number of participants
    var participantCount: Int {
        participants.count
    }
    
    /// Whether there are enough participants (minimum 2)
    var hasEnoughParticipants: Bool {
        participantCount >= 2
    }
    
    /// Whether a payer has been selected
    var hasSelectedPayer: Bool {
        !paidBy.isEmpty && participants.contains(paidBy)
    }
    
    // MARK: - Initialization
    
    init(participants: [String] = [], paidBy: String = "") {
        self.participants = participants
        self.paidBy = paidBy
    }
    
    // MARK: - Participant Management
    
    /// Adds a new participant
    func addParticipant(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validation
        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty"
            return
        }
        
        guard trimmedName.count <= 50 else {
            errorMessage = "Name is too long (max 50 characters)"
            return
        }
        
        // Check for duplicates (case-insensitive)
        guard !participants.contains(where: { $0.lowercased() == trimmedName.lowercased() }) else {
            errorMessage = "'\(trimmedName)' is already added"
            return
        }
        
        participants.append(trimmedName)
        errorMessage = nil
        
        // Auto-select as payer if first participant
        if participants.count == 1 {
            paidBy = trimmedName
        }
    }
    
    /// Adds participant from the newParticipantName field
    func addNewParticipant() {
        let trimmedName = newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // FIX Scenario 1: Reject empty trimmed names
        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty or just spaces"
            return
        }
        
        addParticipant(newParticipantName)
        newParticipantName = ""
    }
    
    /// Removes participants at specified indices
    func removeParticipants(at offsets: IndexSet) {
        let removedNames = offsets.map { participants[$0] }
        participants.remove(atOffsets: offsets)
        
        // If payer was removed, clear selection
        if removedNames.contains(paidBy) {
            paidBy = participants.first ?? ""
        }
    }
    
    /// Removes a specific participant
    func removeParticipant(_ name: String) {
        participants.removeAll { $0 == name }
        
        // If payer was removed, clear selection
        if paidBy == name {
            paidBy = participants.first ?? ""
        }
    }
    
    /// Clears all participants
    func clearAll() {
        participants = []
        paidBy = ""
        newParticipantName = ""
        errorMessage = nil
    }
    
    // MARK: - Payer Selection
    
    /// Sets the person who paid
    func setPayer(_ name: String) {
        guard participants.contains(name) else {
            errorMessage = "'\(name)' is not a participant"
            return
        }
        paidBy = name
        errorMessage = nil
    }
    
    // MARK: - Validation
    
    /// Validates the current state
    func validate() -> [String] {
        var errors: [String] = []
        
        if participants.isEmpty {
            errors.append("Add at least one participant")
        } else if participants.count < 2 {
            errors.append("Need at least 2 participants to split a bill")
        }
        
        if paidBy.isEmpty {
            errors.append("Select who paid the bill")
        } else if !participants.contains(paidBy) {
            errors.append("Payer must be a participant")
        }
        
        // Check for duplicate names (shouldn't happen with validation, but double-check)
        let uniqueParticipants = Set(participants.map { $0.lowercased() })
        if uniqueParticipants.count != participants.count {
            errors.append("Participant names must be unique")
        }
        
        return errors
    }
    
    /// Whether the current state is valid
    var isValid: Bool {
        validate().isEmpty
    }
    
    // MARK: - Quick Actions
    
    /// Adds multiple participants at once (useful for testing or presets)
    func addMultipleParticipants(_ names: [String]) {
        for name in names {
            addParticipant(name)
        }
    }
    
    /// Suggests common names for quick adding
    static var suggestedNames: [String] {
        ["Me", "Friend", "Roommate", "Colleague"]
    }
}

// MARK: - Preset Support

extension ParticipantsViewModel {
    /// Creates a sample configuration for testing
    static func sample() -> ParticipantsViewModel {
        let vm = ParticipantsViewModel()
        vm.addMultipleParticipants(["Alice", "Bob", "Charlie"])
        vm.setPayer("Alice")
        return vm
    }
}

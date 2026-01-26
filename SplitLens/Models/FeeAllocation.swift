//
//  FeeAllocation.swift
//  SplitLens
//
//  Models for fee allocation strategies and tracking
//

import Foundation

// MARK: - Fee Allocation Strategy

/// Strategy for allocating fees (tax, tip, delivery) among participants
enum FeeAllocationStrategy: String, Codable, CaseIterable, Identifiable {
    case proportional  // Split by spending ratio
    case equal         // Divide evenly among all
    case manual        // User assigns to specific people
    
    var id: String { rawValue }
    
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .proportional: return "By spending"
        case .equal: return "Split equally"
        case .manual: return "Assign manually"
        }
    }
    
    /// Detailed description of the strategy
    var description: String {
        switch self {
        case .proportional: return "People who spent more pay more of the fee"
        case .equal: return "Everyone pays the same amount"
        case .manual: return "You choose who pays"
        }
    }
    
    /// SF Symbol icon for the strategy
    var icon: String {
        switch self {
        case .proportional: return "chart.pie.fill"
        case .equal: return "equal.circle.fill"
        case .manual: return "hand.point.up.fill"
        }
    }
}

// MARK: - Fee Allocation

/// Tracks how a fee should be allocated among participants
struct FeeAllocation: Identifiable, Codable, Equatable {
    // MARK: - Properties
    
    /// Unique identifier
    let id: UUID
    
    /// The fee being allocated
    let fee: Fee
    
    /// Strategy for distributing this fee
    var strategy: FeeAllocationStrategy
    
    /// Participants assigned to pay (for .manual strategy only)
    /// When nil or empty, applies to all participants based on strategy
    var manualAssignments: [String]?
    
    // MARK: - Initialization
    
    /// Creates a new fee allocation with default proportional strategy
    init(
        id: UUID = UUID(),
        fee: Fee,
        strategy: FeeAllocationStrategy = .proportional,
        manualAssignments: [String]? = nil
    ) {
        self.id = id
        self.fee = fee
        self.strategy = strategy
        self.manualAssignments = manualAssignments
    }
    
    // MARK: - Computed Properties
    
    /// Formatted fee amount
    var formattedAmount: String {
        CurrencyFormatter.shared.format(fee.amount)
    }
    
    /// Whether manual assignments are valid (non-empty when strategy is manual)
    var hasValidManualAssignments: Bool {
        guard strategy == .manual else { return true }
        guard let assignments = manualAssignments else { return false }
        return !assignments.isEmpty
    }
    
    /// Display text for current assignment state
    var assignmentSummary: String {
        switch strategy {
        case .proportional:
            return "Split by spending ratio"
        case .equal:
            return "Split equally among all"
        case .manual:
            if let assignments = manualAssignments, !assignments.isEmpty {
                if assignments.count == 1 {
                    return assignments[0]
                } else {
                    return "\(assignments.count) people"
                }
            }
            return "Not assigned"
        }
    }
    
    // MARK: - Mutating Methods
    
    /// Updates the allocation strategy
    mutating func setStrategy(_ newStrategy: FeeAllocationStrategy) {
        strategy = newStrategy
        // Clear manual assignments if switching away from manual
        if newStrategy != .manual {
            manualAssignments = nil
        }
    }
    
    /// Toggles a participant in manual assignments
    mutating func toggleManualAssignment(_ participant: String) {
        var current = manualAssignments ?? []
        if current.contains(participant) {
            current.removeAll { $0 == participant }
        } else {
            current.append(participant)
        }
        manualAssignments = current.isEmpty ? nil : current
    }
    
    /// Sets manual assignments to specific participants
    mutating func setManualAssignments(_ participants: [String]) {
        manualAssignments = participants.isEmpty ? nil : participants
    }
    
    /// Clears all manual assignments
    mutating func clearManualAssignments() {
        manualAssignments = nil
    }
}

// MARK: - Fee Allocation Array Extension

extension Array where Element == FeeAllocation {
    /// Total amount of all fees
    var totalAmount: Double {
        reduce(0) { $0 + $1.fee.amount }
    }
    
    /// Formatted total amount
    var formattedTotalAmount: String {
        CurrencyFormatter.shared.format(totalAmount)
    }
    
    /// Whether all allocations are valid (manual strategies have assignments)
    var allValid: Bool {
        allSatisfy { $0.hasValidManualAssignments }
    }
    
    /// Fees grouped by type
    var groupedByType: [FeeType: [FeeAllocation]] {
        Dictionary(grouping: self) { $0.fee.feeType }
    }
}

// MARK: - Sample Data

extension FeeAllocation {
    /// Sample fee allocation for previews
    static var sample: FeeAllocation {
        FeeAllocation(
            fee: Fee(type: "tax", amount: 5.00),
            strategy: .proportional
        )
    }
    
    /// Multiple sample allocations for previews
    static var samples: [FeeAllocation] {
        [
            FeeAllocation(fee: Fee(type: "tax", amount: 5.00), strategy: .proportional),
            FeeAllocation(fee: Fee(type: "tip", amount: 10.00), strategy: .equal),
            FeeAllocation(fee: Fee(type: "delivery", amount: 3.99), strategy: .manual, manualAssignments: ["Alice"])
        ]
    }
}

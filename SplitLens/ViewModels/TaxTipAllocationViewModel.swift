//
//  TaxTipAllocationViewModel.swift
//  SplitLens
//
//  ViewModel for managing tax and tip allocation strategies
//

import Foundation
import SwiftUI

@MainActor
final class TaxTipAllocationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Fee allocations with their strategies
    @Published var feeAllocations: [FeeAllocation]
    
    /// Items from the receipt (for proportional calculations)
    @Published private(set) var items: [ReceiptItem]
    
    /// Participants in the split
    @Published private(set) var participants: [String]
    
    /// Person who paid the bill
    @Published private(set) var paidBy: String
    
    /// Total bill amount
    @Published private(set) var totalAmount: Double
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Whether calculation preview is loading
    @Published var isCalculating: Bool = false
    
    // MARK: - Private Properties
    
    /// Cached item totals per person for proportional calculations
    private var cachedItemTotals: [String: Double] = [:]
    
    // MARK: - Computed Properties
    
    /// Total amount of all fees
    var totalFees: Double {
        feeAllocations.totalAmount
    }
    
    /// Formatted total fees
    var formattedTotalFees: String {
        CurrencyFormatter.shared.format(totalFees)
    }
    
    /// Subtotal (items only, no fees)
    var subtotal: Double {
        items.reduce(0) { $0 + $1.totalPrice }
    }
    
    /// Formatted subtotal
    var formattedSubtotal: String {
        CurrencyFormatter.shared.format(subtotal)
    }
    
    /// Whether all fee allocations are valid
    var isValid: Bool {
        feeAllocations.allValid
    }
    
    /// Validation errors
    var validationErrors: [String] {
        var errors: [String] = []
        
        for allocation in feeAllocations where !allocation.hasValidManualAssignments {
            errors.append("\(allocation.fee.displayName) needs at least one person assigned")
        }
        
        return errors
    }
    
    /// Number of fees with manual strategy that need assignments
    var pendingManualAssignments: Int {
        feeAllocations.filter { 
            $0.strategy == .manual && !$0.hasValidManualAssignments 
        }.count
    }
    
    // MARK: - Initialization
    
    /// Creates a new TaxTipAllocationViewModel
    /// - Parameters:
    ///   - items: Receipt items for proportional calculations
    ///   - fees: Fees to allocate (creates FeeAllocation with default strategy)
    ///   - participants: List of participants
    ///   - paidBy: Person who paid the bill
    ///   - totalAmount: Total bill amount
    init(
        items: [ReceiptItem],
        fees: [Fee],
        participants: [String],
        paidBy: String,
        totalAmount: Double
    ) {
        self.items = items
        self.participants = participants
        self.paidBy = paidBy
        self.totalAmount = totalAmount
        
        // Convert fees to fee allocations with default proportional strategy
        self.feeAllocations = fees.map { fee in
            FeeAllocation(
                fee: fee,
                strategy: AppConstants.FeeAllocation.defaultStrategy
            )
        }
        
        // Calculate initial item totals
        calculateItemTotals()
    }
    
    // MARK: - Strategy Management
    
    /// Applies a strategy to all fee allocations
    /// - Parameter strategy: The strategy to apply
    func applyStrategyToAll(_ strategy: FeeAllocationStrategy) {
        HapticFeedback.shared.mediumImpact()
        
        for index in feeAllocations.indices {
            feeAllocations[index].setStrategy(strategy)
        }
        
        errorMessage = nil
    }
    
    /// Updates strategy for a specific fee allocation
    /// - Parameters:
    ///   - allocationId: ID of the allocation to update
    ///   - strategy: New strategy to apply
    func updateStrategy(for allocationId: UUID, to strategy: FeeAllocationStrategy) {
        guard let index = feeAllocations.firstIndex(where: { $0.id == allocationId }) else {
            return
        }
        
        HapticFeedback.shared.selection()
        feeAllocations[index].setStrategy(strategy)
        errorMessage = nil
    }
    
    /// Toggles manual assignment for a participant on a specific fee
    /// - Parameters:
    ///   - allocationId: ID of the allocation
    ///   - participant: Participant to toggle
    func toggleManualAssignment(for allocationId: UUID, participant: String) {
        guard let index = feeAllocations.firstIndex(where: { $0.id == allocationId }) else {
            return
        }
        
        HapticFeedback.shared.selection()
        feeAllocations[index].toggleManualAssignment(participant)
    }
    
    /// Sets manual assignments for a specific fee
    /// - Parameters:
    ///   - allocationId: ID of the allocation
    ///   - participants: Participants to assign
    func setManualAssignments(for allocationId: UUID, participants: [String]) {
        guard let index = feeAllocations.firstIndex(where: { $0.id == allocationId }) else {
            return
        }
        
        feeAllocations[index].setManualAssignments(participants)
    }
    
    // MARK: - Calculation Methods
    
    /// Calculates item totals per person (for proportional fee distribution)
    private func calculateItemTotals() {
        cachedItemTotals = [:]
        
        for participant in participants {
            cachedItemTotals[participant] = 0.0
        }
        
        for item in items where item.isAssigned {
            if item.assignedTo.contains("All") {
                // Split among all participants
                let perPerson = item.totalPrice / Double(participants.count)
                for participant in participants {
                    cachedItemTotals[participant, default: 0.0] += perPerson
                }
            } else {
                // Split among assigned participants
                let perPerson = item.pricePerPerson
                for person in item.assignedTo {
                    cachedItemTotals[person, default: 0.0] += perPerson
                }
            }
        }
    }
    
    /// Returns formatted items total for a participant
    /// - Parameter participant: The participant name
    /// - Returns: Formatted currency string
    func itemsTotal(for participant: String) -> String {
        let amount = cachedItemTotals[participant] ?? 0.0
        return CurrencyFormatter.shared.format(amount)
    }
    
    /// Returns the raw items amount for a participant
    /// - Parameter participant: The participant name
    /// - Returns: Items total amount
    func itemsAmount(for participant: String) -> Double {
        cachedItemTotals[participant] ?? 0.0
    }
    
    /// Calculates total fees for a participant based on current allocations
    /// - Parameter participant: The participant name
    /// - Returns: Total fees amount
    func feesAmount(for participant: String) -> Double {
        var totalFeeAmount = 0.0
        let itemTotalSum = cachedItemTotals.values.reduce(0, +)
        
        for allocation in feeAllocations {
            switch allocation.strategy {
            case .proportional:
                // Distribute based on spending ratio
                guard itemTotalSum > 0 else { continue }
                let personItems = cachedItemTotals[participant] ?? 0.0
                let ratio = personItems / itemTotalSum
                totalFeeAmount += allocation.fee.amount * ratio
                
            case .equal:
                // Divide equally among all participants
                totalFeeAmount += allocation.fee.amount / Double(participants.count)
                
            case .manual:
                // Only include if participant is in manual assignments
                if let assignees = allocation.manualAssignments,
                   assignees.contains(participant) {
                    totalFeeAmount += allocation.fee.amount / Double(assignees.count)
                }
            }
        }
        
        return totalFeeAmount
    }
    
    /// Returns formatted fees total for a participant
    /// - Parameter participant: The participant name
    /// - Returns: Formatted currency string
    func feesTotal(for participant: String) -> String {
        CurrencyFormatter.shared.format(feesAmount(for: participant))
    }
    
    /// Calculates grand total (items + fees) for a participant
    /// - Parameter participant: The participant name
    /// - Returns: Grand total amount
    func grandTotal(for participant: String) -> Double {
        itemsAmount(for: participant) + feesAmount(for: participant)
    }
    
    /// Returns formatted grand total for a participant
    /// - Parameter participant: The participant name
    /// - Returns: Formatted currency string
    func formattedGrandTotal(for participant: String) -> String {
        CurrencyFormatter.shared.format(grandTotal(for: participant))
    }
    
    // MARK: - Validation
    
    /// Validates all allocations are properly configured
    /// - Returns: True if valid, false otherwise
    func validate() -> Bool {
        errorMessage = nil
        
        let errors = validationErrors
        if !errors.isEmpty {
            errorMessage = errors.first
            return false
        }
        
        return true
    }
}

// MARK: - Preview Support

extension TaxTipAllocationViewModel {
    /// Creates a sample view model for previews
    static func sample() -> TaxTipAllocationViewModel {
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 20.00, assignedTo: ["Alice", "Bob"]),
            ReceiptItem(name: "Salad", quantity: 1, price: 10.00, assignedTo: ["Alice"])
        ]
        
        let fees = [
            Fee(type: "tax", amount: 2.50),
            Fee(type: "tip", amount: 5.00)
        ]
        
        return TaxTipAllocationViewModel(
            items: items,
            fees: fees,
            participants: ["Alice", "Bob"],
            paidBy: "Alice",
            totalAmount: 37.50
        )
    }
}

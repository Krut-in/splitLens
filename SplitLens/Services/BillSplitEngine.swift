//
//  BillSplitEngine.swift
//  SplitLens
//
//  Service for computing bill splits among participants
//

import Foundation

// MARK: - Bill Split Engine Protocol

/// Protocol defining bill splitting calculation capabilities
protocol BillSplitEngineProtocol {
    /// Computes split logs showing who owes whom
    /// - Parameter session: The receipt session to calculate splits for
    /// - Returns: Array of split logs indicating payment transfers
    /// - Throws: BillSplitError if calculation fails
    func computeSplits(session: ReceiptSession) -> [SplitLog]
}

// MARK: - Bill Split Engine Implementation

/// Implements bill splitting logic with support for shared items
final class BillSplitEngine: BillSplitEngineProtocol {
    
    /// Computes splits for a session using the "payer reimbursement" method
    ///
    /// Algorithm:
    /// 1. Calculate what each person owes based on their assigned items
    /// 2. The payer already paid the full amount
    /// 3. Create split logs for non-payers to reimburse the payer
    /// 4. Optimize by canceling out debts where possible
    func computeSplits(session: ReceiptSession) -> [SplitLog] {
        guard !session.participants.isEmpty else { return [] }
        guard !session.items.isEmpty else { return [] }
        
        // Step 1: Calculate what each participant owes
        var balances: [String: Double] = [:]
        
        for participant in session.participants {
            balances[participant] = 0.0
        }
        
        // Calculate individual shares
        for item in session.items {
            guard item.isAssigned else { continue }
            
            let pricePerPerson = item.pricePerPerson
            
            for person in item.assignedTo {
                balances[person, default: 0.0] += pricePerPerson
            }
        }
        
        // Step 2: Adjust balances (payer has negative balance equal to total)
        let payer = session.paidBy
        let totalPaid = session.totalAmount
        
        // Payer already paid, so they have a credit
        balances[payer, default: 0.0] -= totalPaid
        
        // Step 3: Generate split logs
        var splits: [SplitLog] = []
        
        for (person, balance) in balances {
            // Positive balance = owes money
            // Negative balance = is owed money
            
            if person == payer {
                continue // Skip the payer
            }
            
            if balance > 0.01 { // Only create split if meaningful amount
                let split = SplitLog(
                    from: person,
                    to: payer,
                    amount: roundToTwoDecimals(balance),
                    explanation: generateExplanation(
                        for: person,
                        items: session.items(assignedTo: person),
                        totalOwed: balance
                    )
                )
                splits.append(split)
            }
        }
        
        // Sort by amount (largest first)
        splits.sort { $0.amount > $1.amount }
        
        return splits
    }
    
    // MARK: - Helper Methods
    
    /// Rounds a value to 2 decimal places
    private func roundToTwoDecimals(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
    
    /// Generates a human-readable explanation for a split
    private func generateExplanation(
        for person: String,
        items: [ReceiptItem],
        totalOwed: Double
    ) -> String {
        guard !items.isEmpty else {
            return "Your share of the bill"
        }
        
        if items.count == 1 {
            let item = items[0]
            if item.sharingCount > 1 {
                return "Your share of \(item.name) (split \(item.sharingCount) ways)"
            } else {
                return item.name
            }
        }
        
        if items.count <= 3 {
            let itemNames = items.map { $0.name }.joined(separator: ", ")
            return "Your share: \(itemNames)"
        }
        
        return "Your share: \(items.count) items"
    }
}

// MARK: - Advanced Split Engine (Future Enhancement)

/// Advanced bill splitting with support for complex scenarios
/// This can be extended in future versions for:
/// - Custom split percentages
/// - Tax and tip distribution
/// - Service charges
/// - Discounts and promo codes
final class AdvancedBillSplitEngine: BillSplitEngineProtocol {
    
    private let basicEngine = BillSplitEngine()
    
    // Tax distribution method
    enum TaxDistribution {
        case proportional  // Distribute tax proportionally by amount
        case equal         // Split tax equally
        case none          // No tax
    }
    
    // Tip distribution method
    enum TipDistribution {
        case proportional
        case equal
        case none
    }
    
    var taxDistribution: TaxDistribution = .proportional
    var tipDistribution: TipDistribution = .proportional
    
    func computeSplits(session: ReceiptSession) -> [SplitLog] {
        // For now, use basic engine
        // Future: Add tax/tip distribution logic here
        return basicEngine.computeSplits(session: session)
    }
    
    // Future methods:
    // - func distributeTax(amount: Double, among participants: [String])
    // - func distributeTip(amount: Double, among participants: [String])
    // - func applyDiscount(code: String, to session: ReceiptSession)
}

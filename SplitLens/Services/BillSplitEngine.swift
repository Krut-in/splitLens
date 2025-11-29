//
//  BillSplitEngine.swift
//  SplitLens
//
//  Service for computing bill splits among participants
//

import Foundation

// MARK: - Bill Split Warning Types

/// Warnings that may occur during split calculation (non-fatal)
struct BillSplitWarning {
    enum WarningType {
        case totalVariance(calculated: Double, expected: Double, variance: Double)
        case unassignedItems(count: Int)
        case singleParticipant
    }
    
    let type: WarningType
    
    var message: String {
        switch type {
        case .totalVariance(let calculated, let expected, let variance):
            return String(format: "⚠️ Total mismatch: Calculated $%.2f vs Entered $%.2f (Variance: %.2f%%). Please verify manually.", calculated, expected, variance)
        case .unassignedItems(let count):
            return "⚠️ \(count) item(s) not assigned to any participant"
        case .singleParticipant:
            return "⚠️ Only one participant - no splits necessary"
        }
    }
}

// MARK: - Bill Split Result

/// Result of a bill split computation including any warnings
struct BillSplitResult {
    let splits: [SplitLog]
    let warnings: [BillSplitWarning]
    
    var hasWarnings: Bool {
        !warnings.isEmpty
    }
}

// MARK: - Bill Split Engine Protocol

/// Protocol defining bill splitting calculation capabilities
protocol BillSplitEngineProtocol {
    /// Computes split logs showing who owes whom
    /// - Parameter session: The receipt session to calculate splits for
    /// - Returns: Result containing splits and any warnings
    /// - Throws: BillSplitError if calculation fails
    func computeSplits(session: ReceiptSession) throws -> BillSplitResult
}


/// Implements bill splitting logic with support for shared items
final class BillSplitEngine: BillSplitEngineProtocol {
    
    /// Computes splits for a session using the "payer reimbursement" method
    ///
    /// **Algorithm:**
    /// 1. Validate session data (participants, items, payer)
    /// 2. Calculate per-person costs for each item:
    ///    - If assigned to "All": divide equally among ALL participants
    ///    - Otherwise: divide only among assigned people
    /// 3. Handle quantities (totalPrice = price × quantity, then split)
    /// 4. Validate calculated total matches entered total (warn if > 1% variance)
    /// 5. Generate settlement logs (everyone pays the payer)
    /// 6. Filter out insignificant amounts (< $0.01)
    ///
    /// - Parameter session: The receipt session to calculate splits for
    /// - Returns: BillSplitResult with splits and any warnings
    /// - Throws: BillSplitError for critical validation failures
    func computeSplits(session: ReceiptSession) throws -> BillSplitResult {
        var warnings: [BillSplitWarning] = []
        
        // VALIDATION: Check basic requirements
        guard !session.participants.isEmpty else {
            throw BillSplitError.noParticipants
        }
        
        guard !session.items.isEmpty else {
            throw BillSplitError.noItems
        }
        
        guard session.participants.contains(session.paidBy) else {
            throw BillSplitError.invalidPayer(session.paidBy)
        }
        
        // Check for unassigned items (warning only)
        let unassignedCount = session.items.filter { !$0.isAssigned }.count
        if unassignedCount > 0 {
            warnings.append(BillSplitWarning(type: .unassignedItems(count: unassignedCount)))
        }
        
        // Edge case: Single participant
        if session.participants.count == 1 {
            warnings.append(BillSplitWarning(type: .singleParticipant))
            return BillSplitResult(splits: [], warnings: warnings)
        }
        
        // STEP 1: Calculate what each person owes based on their assigned items
        var personTotals: [String: Double] = [:]
        
        // Initialize all participants to $0.00
        for participant in session.participants {
            personTotals[participant] = 0.0
        }
        
        // Calculate individual shares
        for item in session.items {
            guard item.isAssigned else { continue }
            
            // Handle quantity: total item cost = price × quantity
            let totalItemCost = item.totalPrice
            
            // Check if assigned to "All"
            if item.assignedTo.contains("All") {
                // Divide equally among ALL participants
                let costPerPerson = totalItemCost / Double(session.participants.count)
                for participant in session.participants {
                    personTotals[participant, default: 0.0] += costPerPerson
                }
            } else {
                // Divide only among assigned people
                let assignedCount = item.assignedTo.count
                guard assignedCount > 0 else { continue }
                
                let costPerPerson = totalItemCost / Double(assignedCount)
                for person in item.assignedTo {
                    personTotals[person, default: 0.0] += costPerPerson
                }
            }
        }
        
        // STEP 2: Validate totals (error at >10% variance, warn at > 1%)
        let calculatedTotal = personTotals.values.reduce(0.0, +)
        let difference = abs(calculatedTotal - session.totalAmount)
        let variancePercent = (difference / session.totalAmount) * 100.0
        
        // Hard error if variance exceeds 10%
        if variancePercent > 10.0 {
            throw BillSplitError.totalsDoNotMatch(
                calculated: calculatedTotal,
                expected: session.totalAmount,
                variance: variancePercent
            )
        }
        
        // Warning if variance is between 1% and 10%
        if variancePercent > 1.0 {
            warnings.append(BillSplitWarning(
                type: .totalVariance(
                    calculated: calculatedTotal,
                    expected: session.totalAmount,
                    variance: variancePercent
                )
            ))
        }
        
        // Warning if variance is between 1% and 10%
        if variancePercent > 1.0 {
            warnings.append(BillSplitWarning(
                type: .totalVariance(
                    calculated: calculatedTotal,
                    expected: session.totalAmount,
                    variance: variancePercent
                )
            ))
        }
        
        // STEP 2.5: Floating point precision fix - Redistribute cents
        // This ensures splits add up exactly to the total (e.g., $10.00 split 3 ways = $3.33 + $3.33 + $3.34, not $9.99)
        let adjustedTotals = distributeCents(
            total: session.totalAmount,
            among: session.participants,
            baseAmounts: personTotals
        )
        
        // STEP 3: Generate settlement logs
        // Everyone owes the payer (simplified debt model)
        var splits: [SplitLog] = []
        let payer = session.paidBy
        
        for participant in session.participants where participant != payer {
            let amountOwed = adjustedTotals[participant] ?? 0.0
            
            // Filter out insignificant amounts (< $0.01)
            if amountOwed > 0.01 {
                let split = SplitLog(
                    from: participant,
                    to: payer,
                    amount: (amountOwed * 100).rounded() / 100,
                    explanation: generateDetailedExplanation(
                        for: participant,
                        items: session.items,
                        allParticipants: session.participants,
                        totalOwed: amountOwed
                    )
                )
                splits.append(split)
            }
        }
        
        // Sort by amount (largest first)
        splits.sort { $0.amount > $1.amount }
        
        return BillSplitResult(splits: splits, warnings: warnings)
    }
    
    // MARK: - Helper Methods
    
    /// Distributes remaining cents among participants to ensure exact total
    ///
    /// Uses the "largest remainder" method to fairly distribute cents that arise
    /// from rounding. This ensures the sum of all splits equals exactly the entered total.
    ///
    /// **Example:**
    /// - Total: $10.00, 3 participants
    /// - Base calculation: $3.333... each
    /// - Rounded: $3.33, $3.33, $3.33 = $9.99 (missing $0.01)
    /// - After redistribution: $3.33, $3.33, $3.34 = $10.00 ✅
    ///
    /// **Algorithm:**
    /// 1. Convert amounts to cents (avoid floating point errors)
    /// 2. Calculate how many cents are missing/extra
    /// 3. Distribute extra cents to first N participants (alphabetically sorted for consistency)
    ///
    /// - Parameters:
    ///   - total: The target total amount
    ///   - participants: List of all participants
    ///   - baseAmounts: Initial calculated amounts per participant
    /// - Returns: Adjusted amounts that sum exactly to total
    private func distributeCents(
        total: Double,
        among participants: [String],
        baseAmounts: [String: Double]
    ) -> [String: Double] {
        var adjusted = baseAmounts
        
        // Convert to cents to avoid floating point errors
        let totalCents = Int(round(total * 100))
        let sumOfBase = baseAmounts.values.reduce(0.0, +)
        let baseCents = Int(round(sumOfBase * 100))
        let remainder = totalCents - baseCents
        
        // If there's a discrepancy, distribute the remaining cents
        if remainder != 0 {
            // Sort participants for consistent distribution
            let sorted = participants.sorted()
            let absRemainder = abs(remainder)
            
            // Distribute cents one by one to participants
            for i in 0..<absRemainder {
                let participant = sorted[i % sorted.count]
                if remainder > 0 {
                    // Add a cent
                    adjusted[participant, default: 0.0] += 0.01
                } else {
                    // Subtract a cent
                    adjusted[participant, default: 0.0] -= 0.01
                }
            }
        }
        
        return adjusted
    }
    
    /// Generates a human-readable explanation for a participant's split
    ///
    /// Shows detailed breakdown of each item with division logic:
    /// - "Pizza: $24.00 ÷ 3 = $8.00"
    /// - "Tax (All): $5.00 ÷ 4 = $1.25"
    ///
    /// - Parameters:
    ///   - person: The participant to generate explanation for
    ///   - items: All items in the session
    ///   - allParticipants: All participants in the session
    ///   - totalOwed: Total amount this person owes
    /// - Returns: Formatted explanation string
    private func generateDetailedExplanation(
        for person: String,
        items: [ReceiptItem],
        allParticipants: [String],
        totalOwed: Double
    ) -> String {
        // Filter items this person is involved with
        let personItems = items.filter { item in
            item.assignedTo.contains(person) || item.assignedTo.contains("All")
        }
        
        guard !personItems.isEmpty else {
            return "Your share of the bill"
        }
        
        var lines: [String] = []
        
        for item in personItems {
            let totalItemCost = item.totalPrice
            
            if item.assignedTo.contains("All") {
                // Item assigned to "All" participants
                let count = allParticipants.count
                let share = totalItemCost / Double(count)
                
                if count == 1 {
                    lines.append(String(format: "%@ (All): $%.2f", item.name, totalItemCost))
                } else {
                    lines.append(String(format: "%@ (All): $%.2f ÷ %d = $%.2f", item.name, totalItemCost, count, share))
                }
            } else if item.assignedTo.contains(person) {
                // Item assigned to specific people
                let count = item.assignedTo.count
                let share = totalItemCost / Double(count)
                
                if count == 1 {
                    // Person ordered this item alone
                    if item.quantity > 1 {
                        lines.append(String(format: "%@ (×%d): $%.2f", item.name, item.quantity, totalItemCost))
                    } else {
                        lines.append(String(format: "%@: $%.2f", item.name, totalItemCost))
                    }
                } else {
                    // Item split among multiple people
                    if item.quantity > 1 {
                        lines.append(String(format: "%@ (×%d): $%.2f ÷ %d = $%.2f", item.name, item.quantity, totalItemCost, count, share))
                    } else {
                        lines.append(String(format: "%@: $%.2f ÷ %d = $%.2f", item.name, totalItemCost, count, share))
                    }
                }
            }
        }
        
        if lines.isEmpty {
            return String(format: "Your share: $%.2f", totalOwed)
        }
        
        return lines.joined(separator: "\n")
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
    
    func computeSplits(session: ReceiptSession) throws -> BillSplitResult {
        // For now, use basic engine
        // Future: Add tax/tip distribution logic here
        return try basicEngine.computeSplits(session: session)
    }
    
    // Future methods:
    // - func distributeTax(amount: Double, among participants: [String])
    // - func distributeTip(amount: Double, among participants: [String])
    // - func applyDiscount(code: String, to session: ReceiptSession)
}


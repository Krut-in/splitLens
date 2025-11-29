//
//  ReportData.swift
//  SplitLens
//
//  Data structures for report generation and charts
//

import Foundation

/// Complete data structure for report generation
struct ReportData {
    // MARK: - Properties
    
    /// The source receipt session
    let session: ReceiptSession
    
    /// Per-person total spending
    let personTotals: [String: Double]
    
    /// Net balances (positive = owed to them, negative = they owe)
    let balances: [String: Double]
    
    /// Formatted settlement strings
    let formattedSettlements: [String]
    
    /// Chart-specific data
    let chartsData: ChartsData
    
    // MARK: - Initialization
    
    init(session: ReceiptSession) {
        self.session = session
        
        // Calculate per-person totals
        var totals: [String: Double] = [:]
        for participant in session.participants {
            totals[participant] = session.totalOwed(by: participant)
        }
        self.personTotals = totals
        
        // Calculate balances
        var balances: [String: Double] = [:]
        for participant in session.participants {
            let owed = session.totalOwed(by: participant)
            let balance: Double
            
            if participant == session.paidBy {
                // Payer's balance = total - their consumption
                balance = session.totalAmount - owed
            } else {
                // Others owe money (negative balance)
                balance = -owed
            }
            
            balances[participant] = balance
        }
        self.balances = balances
        
        // Format settlements
        self.formattedSettlements = session.computedSplits.map { $0.summary }
        
        // Build charts data
        self.chartsData = ChartsData(
            session: session,
            personTotals: totals,
            balances: balances
        )
    }
}

// MARK: - Charts Data

/// Data structure specifically for chart visualizations
struct ChartsData {
    // MARK: - Properties
    
    /// Spending breakdown for pie chart: [(person, amount)]
    let spendingBreakdown: [(String, Double)]
    
    /// Owe/Lent data for bar chart: [(person, amount)]
    /// Positive = lent (owed to them), Negative = owed by them
    let oweLent: [(String, Double)]
    
    /// Net balances for balance chart: [(person, balance)]
    let netBalances: [(String, Double)]
    
    // MARK: - Initialization
    
    init(session: ReceiptSession, personTotals: [String: Double], balances: [String: Double]) {
        // Spending breakdown (sorted alphabetically)
        self.spendingBreakdown = personTotals.sorted { $0.key < $1.key }
        
        // Calculate owe/lent amounts
        var oweLentData: [(String, Double)] = []
        for participant in session.participants.sorted() {
            let balance = balances[participant] ?? 0.0
            oweLentData.append((participant, balance))
        }
        self.oweLent = oweLentData
        
        // Net balances (same as owe/lent for this chart)
        self.netBalances = oweLentData
    }
    
    // MARK: - Computed Properties
    
    /// Total spending (sum of all person totals)
    var totalSpending: Double {
        spendingBreakdown.reduce(0.0) { $0 + $1.1 }
    }
    
    /// Verify conservation: sum of balances should be zero
    var balanceSum: Double {
        netBalances.reduce(0.0) { $0 + $1.1 }
    }
    
    /// Whether balance data is valid (sum ≈ 0 within rounding error)
    var isBalanced: Bool {
        abs(balanceSum) < 0.10  // Allow 10 cent variance for rounding
    }
}

// MARK: - Sample Data

extension ReportData {
    /// Sample data for previews and testing
    static var sample: ReportData {
        ReportData(session: ReceiptSession.sample)
    }
}

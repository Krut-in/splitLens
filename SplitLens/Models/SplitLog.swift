//
//  SplitLog.swift
//  SplitLens
//
//  Records a payment transaction between two participants
//

import Foundation

/// Represents a calculated payment from one person to another
struct SplitLog: Identifiable, Codable, Equatable {
    // MARK: - Properties
    
    /// Unique identifier for this split log
    var id: UUID
    
    /// Name of the person who owes money
    var from: String
    
    /// Name of the person who should receive money
    var to: String
    
    /// Amount to be transferred
    var amount: Double
    
    /// Human-readable explanation of this split
    var explanation: String
    
    // MARK: - Initialization
    
    /// Creates a new split log entry
    init(
        id: UUID = UUID(),
        from: String,
        to: String,
        amount: Double,
        explanation: String = ""
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.amount = amount
        self.explanation = explanation
    }
    
    // MARK: - Computed Properties
    
    /// Formatted amount string (e.g., "$12.50")
    var formattedAmount: String {
        CurrencyFormatter.shared.format(amount)
    }
    
    /// Summary text for display (e.g., "Alice → Bob: $12.50")
    var summary: String {
        "\(from) → \(to): \(formattedAmount)"
    }
    
    /// Detailed description including explanation if available
    var detailedDescription: String {
        if explanation.isEmpty {
            return summary
        } else {
            return "\(summary)\n\(explanation)"
        }
    }
    
    /// Whether this split has a meaningful amount (> $0.01)
    var isSignificant: Bool {
        amount >= 0.01
    }
}

// MARK: - Sample Data

extension SplitLog {
    /// Sample data for previews and testing
    static var sample: SplitLog {
        SplitLog(
            from: "Bob",
            to: "Alice",
            amount: 15.50,
            explanation: "Your share of Caesar Salad and Pizza"
        )
    }
    
    static var samples: [SplitLog] {
        [
            SplitLog(from: "Bob", to: "Alice", amount: 15.50, explanation: "Share of Pizza"),
            SplitLog(from: "Charlie", to: "Alice", amount: 8.33, explanation: "Share of Salad and Pizza"),
            SplitLog(from: "David", to: "Bob", amount: 12.00, explanation: "Share of Burger")
        ]
    }
}

//
//  ReceiptSession.swift
//  SplitLens
//
//  Complete receipt scanning session with all data and splits
//

import Foundation

/// Represents a complete receipt scanning and bill-splitting session
struct ReceiptSession: Identifiable, Codable, Equatable {
    // MARK: - Properties
    
    /// Unique identifier for the session
    var id: UUID
    
    /// When this session was created
    var createdAt: Date
    
    /// List of participant names involved in this split
    var participants: [String]
    
    /// Total amount of the bill
    var totalAmount: Double
    
    /// Name of the person who paid the bill
    var paidBy: String
    
    /// All items extracted from the receipt
    var items: [ReceiptItem]
    
    /// Calculated split logs showing who owes whom
    var computedSplits: [SplitLog]
    
    // MARK: - Initialization
    
    /// Creates a new receipt session
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        participants: [String] = [],
        totalAmount: Double = 0.0,
        paidBy: String = "",
        items: [ReceiptItem] = [],
        computedSplits: [SplitLog] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.participants = participants
        self.totalAmount = totalAmount
        self.paidBy = paidBy
        self.items = items
        self.computedSplits = computedSplits
    }
    
    // MARK: - Computed Properties
    
    /// Total number of items in this session
    var itemCount: Int {
        items.count
    }
    
    /// Number of participants
    var participantCount: Int {
        participants.count
    }
    
    /// Number of payment transfers needed
    var splitCount: Int {
        computedSplits.count
    }
    
    /// Calculated total from all items (sum of item totals)
    var calculatedTotal: Double {
        items.reduce(0.0) { $0 + $1.totalPrice }
    }
    
    /// Difference between entered total and calculated total
    var totalDiscrepancy: Double {
        totalAmount - calculatedTotal
    }
    
    /// Whether there's a discrepancy in totals (> $0.05)
    var hasTotalDiscrepancy: Bool {
        abs(totalDiscrepancy) > 0.05
    }
    
    /// Number of unassigned items
    var unassignedItemCount: Int {
        items.filter { !$0.isAssigned }.count
    }
    
    /// Whether all items have been assigned to participants
    var allItemsAssigned: Bool {
        unassignedItemCount == 0
    }
    
    /// Formatted total amount string
    var formattedTotal: String {
        formatCurrency(totalAmount)
    }
    
    /// Formatted creation date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// Short date format for list displays (e.g., "Nov 28, 2024")
    var shortFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
    
    // MARK: - Validation
    
    /// Validates the session has all required data
    var isValid: Bool {
        !participants.isEmpty &&
        participants.count >= 2 &&
        !paidBy.isEmpty &&
        participants.contains(paidBy) &&
        !items.isEmpty &&
        items.allSatisfy { $0.isValid } &&
        totalAmount > 0
    }
    
    /// Validation errors as human-readable messages
    var validationErrors: [String] {
        var errors: [String] = []
        
        if participants.isEmpty {
            errors.append("No participants added")
        } else if participants.count < 2 {
            errors.append("Need at least 2 participants")
        }
        
        if paidBy.isEmpty {
            errors.append("No payer selected")
        } else if !participants.contains(paidBy) {
            errors.append("Payer must be a participant")
        }
        
        if items.isEmpty {
            errors.append("No items added")
        } else if !items.allSatisfy({ $0.isValid }) {
            errors.append("Some items have invalid data")
        }
        
        if totalAmount <= 0 {
            errors.append("Total amount must be greater than 0")
        }
        
        if !allItemsAssigned {
            errors.append("\(unassignedItemCount) item(s) not assigned")
        }
        
        return errors
    }
    
    // MARK: - Helper Methods
    
    /// Gets all items assigned to a specific participant
    func items(assignedTo participant: String) -> [ReceiptItem] {
        items.filter { $0.isAssigned(to: participant) }
    }
    
    /// Calculates total amount owed by a participant
    func totalOwed(by participant: String) -> Double {
        items(assignedTo: participant).reduce(0.0) { total, item in
            total + item.pricePerPerson
        }
    }
    
    /// Gets all splits involving a specific participant
    func splits(for participant: String) -> [SplitLog] {
        computedSplits.filter { $0.from == participant || $0.to == participant }
    }
    
    /// Formats a currency value to string
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Coding Keys

extension ReceiptSession {
    /// Custom coding keys to match Supabase schema
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case participants
        case totalAmount = "total_amount"
        case paidBy = "paid_by"
        case items
        case computedSplits = "computed_splits"
    }
}

// MARK: - Sample Data

extension ReceiptSession {
    /// Sample data for previews and testing
    static var sample: ReceiptSession {
        ReceiptSession(
            id: UUID(),
            createdAt: Date(),
            participants: ["Alice", "Bob", "Charlie"],
            totalAmount: 65.96,
            paidBy: "Alice",
            items: ReceiptItem.samples,
            computedSplits: SplitLog.samples
        )
    }
    
    static var samples: [ReceiptSession] {
        [
            ReceiptSession(
                createdAt: Date().addingTimeInterval(-86400), // 1 day ago
                participants: ["Alice", "Bob"],
                totalAmount: 45.50,
                paidBy: "Alice",
                items: Array(ReceiptItem.samples.prefix(2)),
                computedSplits: [SplitLog.samples[0]]
            ),
            ReceiptSession(
                createdAt: Date().addingTimeInterval(-172800), // 2 days ago
                participants: ["Alice", "Bob", "Charlie", "David"],
                totalAmount: 120.75,
                paidBy: "Bob",
                items: ReceiptItem.samples,
                computedSplits: SplitLog.samples
            )
        ]
    }
}

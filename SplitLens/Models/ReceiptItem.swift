//
//  ReceiptItem.swift
//  SplitLens
//
//  Receipt item model representing a single line item from a scanned receipt
//

import Foundation

/// Represents a single item from a receipt with assignment capabilities
struct ReceiptItem: Identifiable, Codable, Equatable {
    // MARK: - Properties
    
    /// Unique identifier for the item
    var id: UUID
    
    /// Name/description of the item
    var name: String
    
    /// Quantity of the item
    var quantity: Int
    
    /// Total price for this line item (as shown on receipt)
    /// This is the final amount for this line, NOT per-unit price
    var price: Double
    
    /// List of participant names this item is assigned to (supports splitting)
    var assignedTo: [String]
    
    /// Source page index for multi-image receipts (0-based)
    /// nil for single-image receipts or manually added items
    var sourcePageIndex: Int?
    
    // MARK: - Initialization
    
    /// Creates a new receipt item with default values
    init(
        id: UUID = UUID(),
        name: String = "",
        quantity: Int = 1,
        price: Double = 0.0,
        assignedTo: [String] = [],
        sourcePageIndex: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.price = price
        self.assignedTo = assignedTo
        self.sourcePageIndex = sourcePageIndex
    }
    
    // MARK: - Computed Properties
    
    /// Total price for this item (same as price, which is the receipt line total)
    var totalPrice: Double {
        price
    }
    
    /// Price per unit (calculated from total / quantity, for editing purposes)
    var unitPrice: Double {
        guard quantity > 0 else { return price }
        return price / Double(quantity)
    }
    
    /// Whether the item is assigned to anyone
    var isAssigned: Bool {
        !assignedTo.isEmpty
    }
    
    /// Number of people this item is shared among
    var sharingCount: Int {
        assignedTo.count
    }
    
    /// Price per person if split equally among assigned participants
    var pricePerPerson: Double {
        guard sharingCount > 0 else { return 0.0 }
        return totalPrice / Double(sharingCount)
    }
    
    /// Formatted total price string (e.g., "$12.50")
    var formattedTotalPrice: String {
        CurrencyFormatter.shared.format(totalPrice)
    }
    
    /// Formatted price per person (e.g., "$6.25 each")
    var formattedPricePerPerson: String {
        let amount = CurrencyFormatter.shared.format(pricePerPerson)
        return sharingCount > 1 ? "\(amount) each" : amount
    }
    
    // MARK: - Validation
    
    /// Validates the item has required data
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        quantity > 0 &&
        price >= 0
    }
    
    // MARK: - Assignment Methods
    
    /// Assigns this item to a specific participant
    mutating func assign(to participant: String) {
        if !assignedTo.contains(participant) {
            assignedTo.append(participant)
        }
    }
    
    /// Removes a participant from this item's assignment
    mutating func unassign(from participant: String) {
        assignedTo.removeAll { $0 == participant }
    }
    
    /// Toggles assignment for a participant (add if not present, remove if present)
    mutating func toggleAssignment(for participant: String) {
        if assignedTo.contains(participant) {
            unassign(from: participant)
        } else {
            assign(to: participant)
        }
    }
    
    /// Checks if this item is assigned to a specific participant
    func isAssigned(to participant: String) -> Bool {
        assignedTo.contains(participant)
    }
}

// MARK: - Sample Data

extension ReceiptItem {
    /// Sample data for previews and testing
    static var sample: ReceiptItem {
        ReceiptItem(
            name: "Caesar Salad",
            quantity: 1,
            price: 12.99,
            assignedTo: ["Alice"],
            sourcePageIndex: 0
        )
    }
    
    static var sampleShared: ReceiptItem {
        ReceiptItem(
            name: "Pizza (Large)",
            quantity: 1,
            price: 24.99,
            assignedTo: ["Alice", "Bob", "Charlie"],
            sourcePageIndex: 0
        )
    }
    
    static var samples: [ReceiptItem] {
        [
            ReceiptItem(name: "Caesar Salad", quantity: 1, price: 12.99, assignedTo: ["Alice"], sourcePageIndex: 0),
            ReceiptItem(name: "Burger", quantity: 2, price: 15.99, assignedTo: ["Bob"], sourcePageIndex: 0),
            ReceiptItem(name: "Pizza (Large)", quantity: 1, price: 24.99, assignedTo: ["Alice", "Bob", "Charlie"], sourcePageIndex: 1),
            ReceiptItem(name: "Coke", quantity: 3, price: 2.99, assignedTo: [], sourcePageIndex: 1)
        ]
    }
    
    /// Sample data for multi-page receipt testing
    static var multiPageSamples: [ReceiptItem] {
        [
            // Page 1 items
            ReceiptItem(name: "Caesar Salad", quantity: 1, price: 12.99, assignedTo: [], sourcePageIndex: 0),
            ReceiptItem(name: "Burger Deluxe", quantity: 2, price: 15.99, assignedTo: [], sourcePageIndex: 0),
            ReceiptItem(name: "Fries Large", quantity: 1, price: 4.99, assignedTo: [], sourcePageIndex: 0),
            // Page 2 items
            ReceiptItem(name: "Pizza Margherita", quantity: 1, price: 18.99, assignedTo: [], sourcePageIndex: 1),
            ReceiptItem(name: "Pasta Carbonara", quantity: 1, price: 16.99, assignedTo: [], sourcePageIndex: 1),
            // Page 3 items
            ReceiptItem(name: "Tiramisu", quantity: 2, price: 8.99, assignedTo: [], sourcePageIndex: 2),
            ReceiptItem(name: "Espresso", quantity: 3, price: 3.50, assignedTo: [], sourcePageIndex: 2)
        ]
    }
}

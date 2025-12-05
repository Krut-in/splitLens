//
//  StructuredReceiptData.swift
//  SplitLens
//
//  Models for structured receipt data returned by Gemini Vision API
//

import Foundation

// MARK: - Structured Receipt Response

/// Response from the Gemini Vision API with structured receipt data
struct StructuredReceiptData: Codable {
    /// Extracted product items from the receipt
    let items: [ExtractedItem]
    
    /// Additional fees (delivery, service, tax, tip, etc.)
    let fees: [Fee]?
    
    /// Subtotal before fees (if detected)
    let subtotal: Double?
    
    /// Grand total (if detected)
    let total: Double?
    
    /// Store or vendor name (if detected)
    let storeName: String?
    
    /// Raw OCR text (only present when using legacy Vision API)
    let rawText: String?
    
    /// Whether this response was from structured extraction (Gemini) vs raw OCR
    var isStructured: Bool {
        !items.isEmpty || rawText == nil
    }
}

// MARK: - Extracted Item

/// A single item extracted from the receipt
struct ExtractedItem: Codable {
    /// Product name/description
    let name: String
    
    /// Quantity purchased
    let quantity: Int
    
    /// Price per unit (or total price if quantity is 1)
    let price: Double
    
    /// Convert to ReceiptItem for use in the app
    func toReceiptItem() -> ReceiptItem {
        ReceiptItem(
            name: name,
            quantity: quantity,
            price: price,
            assignedTo: []
        )
    }
}

// MARK: - Fee

/// Additional fees on the receipt (delivery, service, tax, tip)
struct Fee: Codable {
    /// Type of fee: "delivery", "service", "tax", "tip", "other"
    let type: String
    
    /// Fee amount
    let amount: Double
    
    /// User-friendly display name
    var displayName: String {
        switch type.lowercased() {
        case "delivery": return "Delivery Fee"
        case "service": return "Service Fee"
        case "tax": return "Tax"
        case "tip": return "Tip"
        default: return type.capitalized
        }
    }
    
    /// Convert to ReceiptItem for display
    func toReceiptItem() -> ReceiptItem {
        ReceiptItem(
            name: displayName,
            quantity: 1,
            price: amount,
            assignedTo: []
        )
    }
}

// MARK: - Extension for Convenience

extension StructuredReceiptData {
    /// Convert all items to ReceiptItem array
    func toReceiptItems(includeFees: Bool = true) -> [ReceiptItem] {
        var receiptItems = items.map { $0.toReceiptItem() }
        
        if includeFees, let fees = fees {
            receiptItems.append(contentsOf: fees.map { $0.toReceiptItem() })
        }
        
        return receiptItems
    }
    
    /// Calculate total from items if not provided
    var calculatedTotal: Double {
        if let total = total {
            return total
        }
        
        let itemsTotal = items.reduce(0.0) { $0 + (Double($1.quantity) * $1.price) }
        let feesTotal = fees?.reduce(0.0) { $0 + $1.amount } ?? 0
        return itemsTotal + feesTotal
    }
}

// MARK: - Sample Data

extension StructuredReceiptData {
    static var sample: StructuredReceiptData {
        StructuredReceiptData(
            items: [
                ExtractedItem(name: "Kawan Plain Paratha", quantity: 1, price: 10.99),
                ExtractedItem(name: "Deep Paneer Paratha", quantity: 1, price: 3.99),
                ExtractedItem(name: "Haldiram's Home Style Paratha", quantity: 1, price: 9.99)
            ],
            fees: [
                Fee(type: "delivery", amount: 4.95)
            ],
            subtotal: 24.97,
            total: 29.92,
            storeName: "Instacart",
            rawText: nil
        )
    }
}

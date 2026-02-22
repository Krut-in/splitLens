//
//  StructuredReceiptData.swift
//  SplitLens
//
//  Models for structured receipt data returned by Gemini Vision API
//  with multi-image support for source page tracking
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

    /// Receipt date/time in ISO-8601 format (if detected by OCR).
    let receiptDateISO: String?
    
    /// Raw OCR text (only present when using legacy Vision API)
    let rawText: String?
    
    /// Whether this response was from structured extraction (Gemini) vs raw OCR
    var isStructured: Bool {
        !items.isEmpty || rawText == nil
    }
}

// MARK: - Extracted Item

/// A single item extracted from the receipt with optional source page tracking
struct ExtractedItem: Codable {
    /// Product name/description
    let name: String
    
    /// Quantity purchased
    let quantity: Int
    
    /// Total price for this line item (as shown on receipt, NOT per-unit)
    /// Example: If "2 x $7.05 = $14.10", this would be 14.10
    let price: Double
    
    /// Source page index for multi-image receipts (0-based)
    /// nil for single-image receipts or when not tracked
    let sourcePageIndex: Int?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case name
        case quantity
        case price
        case sourcePageIndex
    }
    
    // MARK: - Initialization
    
    /// Full initializer with all properties
    init(name: String, quantity: Int, price: Double, sourcePageIndex: Int? = nil) {
        self.name = name
        self.quantity = quantity
        self.price = price
        self.sourcePageIndex = sourcePageIndex
    }
    
    /// Decoder initializer with default for sourcePageIndex
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decode(Int.self, forKey: .quantity)
        price = try container.decode(Double.self, forKey: .price)
        sourcePageIndex = try container.decodeIfPresent(Int.self, forKey: .sourcePageIndex)
    }
    
    /// Convert to ReceiptItem for use in the app
    /// Preserves sourcePageIndex for multi-image tracking
    func toReceiptItem() -> ReceiptItem {
        ReceiptItem(
            name: name,
            quantity: quantity,
            price: price,
            assignedTo: [],
            sourcePageIndex: sourcePageIndex
        )
    }
}

// MARK: - Fee

/// Additional fees on the receipt (delivery, service, tax, tip)
struct Fee: Codable, Equatable {
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
    
    /// Fee type enumeration for type-safe handling
    var feeType: FeeType {
        FeeType(rawValue: type.lowercased()) ?? .other
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

// MARK: - Fee Type Enum

/// Type-safe fee type enumeration
enum FeeType: String, Codable, CaseIterable {
    case delivery
    case service
    case tax
    case tip
    case other
    
    var displayName: String {
        switch self {
        case .delivery: return "Delivery Fee"
        case .service: return "Service Fee"
        case .tax: return "Tax"
        case .tip: return "Tip"
        case .other: return "Other Fee"
        }
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
        
        // price is already the line total (not per-unit), so just sum them
        let itemsTotal = items.reduce(0.0) { $0 + $1.price }
        let feesTotal = fees?.reduce(0.0) { $0 + $1.amount } ?? 0
        return itemsTotal + feesTotal
    }

    /// Parsed receipt date from `receiptDateISO`, if available and valid.
    var parsedReceiptDate: Date? {
        guard let receiptDateISO else { return nil }
        if let date = ISO8601DateFormatter.withFractional.date(from: receiptDateISO) {
            return date
        }
        if let date = ISO8601DateFormatter.withoutFractional.date(from: receiptDateISO) {
            return date
        }
        return ReceiptDateOnlyParser.parseLocalDateOnly(receiptDateISO)
    }

    /// Whether OCR returned a receipt date with explicit time.
    var parsedReceiptDateHasTime: Bool {
        guard let receiptDateISO else { return false }
        return receiptDateISO.contains("T")
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
            receiptDateISO: nil,
            rawText: nil
        )
    }
}

private extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let withoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private enum ReceiptDateOnlyParser {
    static func parseLocalDateOnly(_ value: String) -> Date? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = normalized.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.minute = 0
        components.second = 0

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        return calendar.date(from: components)
    }
}

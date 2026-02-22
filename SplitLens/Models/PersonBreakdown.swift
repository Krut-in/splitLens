//
//  PersonBreakdown.swift
//  SplitLens
//
//  Per-person itemised cost breakdown for history and report display.
//

import Foundation

// MARK: - PersonBreakdown

/// Detailed cost breakdown for a single participant in a split session.
struct PersonBreakdown: Identifiable, Codable, Equatable {
    var id: UUID = UUID()

    /// Participant name
    var person: String

    /// Individual item charges attributed to this person
    var itemCharges: [ItemCharge]

    /// Fee charges attributed to this person
    var feeCharges: [FeeCharge]

    /// Net settlement amount (positive = owes payer, negative = is owed)
    var settlementAmount: Double

    /// Total amount this person is responsible for (items + fees), computed on demand
    var totalAmount: Double {
        itemCharges.reduce(0) { $0 + $1.amount } +
        feeCharges.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - ItemCharge

/// A single receipt item charge attributed to a specific participant.
struct ItemCharge: Identifiable, Codable, Equatable {
    var id: UUID = UUID()

    /// Name of the receipt item
    var itemName: String

    /// Full price of the item as printed on the receipt
    var itemFullPrice: Double

    /// Number of people this item was split among
    var splitAmong: Int

    /// This person's share (itemFullPrice ÷ splitAmong)
    var amount: Double
}

// MARK: - FeeCharge

/// A fee charge attributed to a specific participant.
struct FeeCharge: Identifiable, Codable, Equatable {
    var id: UUID = UUID()

    /// Fee display name (e.g. "Tax", "Tip", "Delivery Fee")
    var feeName: String

    /// Total fee amount before splitting
    var feeFullAmount: Double

    /// Allocation strategy used for this fee
    var strategy: FeeAllocationStrategy

    /// This person's share of the fee
    var amount: Double
}

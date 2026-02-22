//
//  ReceiptSession.swift
//  SplitLens
//
//  Complete receipt scanning session with all data and splits
//

import Foundation

/// Source used to determine the receipt date shown in history.
enum ReceiptDateSource: String, Codable {
    case ocrExtracted = "ocr_extracted"
    case scanTimestampFallback = "scan_timestamp_fallback"
}

/// Represents a complete receipt scanning and bill-splitting session
struct ReceiptSession: Identifiable, Codable, Equatable {
    // MARK: - Properties
    
    /// Unique identifier for the session
    var id: UUID
    
    /// When this session was created
    var createdAt: Date

    /// Date to display for the receipt in history.
    /// Uses OCR date when available, otherwise scan timestamp fallback.
    var receiptDate: Date

    /// Indicates where `receiptDate` came from.
    var receiptDateSource: ReceiptDateSource

    /// Whether receiptDate includes a reliable time component.
    var receiptDateHasTime: Bool

    /// Absolute on-device paths to persisted receipt images for this session.
    var receiptImagePaths: [String]
    
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
    
    /// Extracted fees with their allocation strategies
    var feeAllocations: [FeeAllocation]

    /// Per-person itemised breakdowns for history display (v2+)
    var personBreakdowns: [PersonBreakdown]

    // MARK: - Initialization

    /// Creates a new receipt session
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        receiptDate: Date? = nil,
        receiptDateSource: ReceiptDateSource = .scanTimestampFallback,
        receiptDateHasTime: Bool = true,
        receiptImagePaths: [String] = [],
        participants: [String] = [],
        totalAmount: Double = 0.0,
        paidBy: String = "",
        items: [ReceiptItem] = [],
        computedSplits: [SplitLog] = [],
        feeAllocations: [FeeAllocation] = [],
        personBreakdowns: [PersonBreakdown] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.receiptDate = receiptDate ?? createdAt
        self.receiptDateSource = receiptDateSource
        self.receiptDateHasTime = receiptDateHasTime
        self.receiptImagePaths = receiptImagePaths
        self.participants = participants
        self.totalAmount = totalAmount
        self.paidBy = paidBy
        self.items = items
        self.computedSplits = computedSplits
        self.feeAllocations = feeAllocations
        self.personBreakdowns = personBreakdowns
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
    
    /// Computed: Total fees amount
    var totalFees: Double {
        feeAllocations.reduce(0) { $0 + $1.fee.amount }
    }
    
    /// Computed: Subtotal (items only, no fees)
    var subtotal: Double {
        items.reduce(0) { $0 + $1.totalPrice }
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
        CurrencyFormatter.shared.format(totalAmount)
    }
    
    /// Formatted creation date string
    var formattedDate: String {
        formattedReceiptDate
    }

    /// Formatted receipt date/time string (primary user-facing date).
    var formattedReceiptDate: String {
        if receiptDateHasTime {
            return AppConstants.Formatters.dateTime.string(from: receiptDate)
        }
        return AppConstants.Formatters.date.string(from: receiptDate)
    }

    /// Formatted receipt date for history rows (date-only by product policy).
    var formattedHistoryDate: String {
        AppConstants.Formatters.date.string(from: receiptDate)
    }

    /// Formatted internal creation timestamp.
    var formattedCreatedAt: String {
        AppConstants.Formatters.dateTime.string(from: createdAt)
    }
    
    /// Short date format for list displays (e.g., "Nov 28, 2024")
    var shortFormattedDate: String {
        AppConstants.Formatters.date.string(from: receiptDate)
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
}

// MARK: - Coding Keys

extension ReceiptSession {
    /// Custom coding keys to match Supabase schema
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case receiptDate = "receipt_date"
        case receiptDateSource = "receipt_date_source"
        case receiptDateHasTime = "receipt_date_has_time"
        case receiptImagePaths = "receipt_image_paths"
        case participants
        case totalAmount = "total_amount"
        case paidBy = "paid_by"
        case items
        case computedSplits = "computed_splits"
        case feeAllocations = "fee_allocations"
        case personBreakdowns = "person_breakdowns"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        receiptDate = try container.decodeIfPresent(Date.self, forKey: .receiptDate) ?? createdAt
        receiptDateSource = try container.decodeIfPresent(ReceiptDateSource.self, forKey: .receiptDateSource) ?? .scanTimestampFallback
        receiptDateHasTime = try container.decodeIfPresent(Bool.self, forKey: .receiptDateHasTime) ?? true
        receiptImagePaths = try container.decodeIfPresent([String].self, forKey: .receiptImagePaths) ?? []
        participants = try container.decodeIfPresent([String].self, forKey: .participants) ?? []
        totalAmount = try container.decodeIfPresent(Double.self, forKey: .totalAmount) ?? 0.0
        paidBy = try container.decodeIfPresent(String.self, forKey: .paidBy) ?? ""
        items = try container.decodeIfPresent([ReceiptItem].self, forKey: .items) ?? []
        computedSplits = try container.decodeIfPresent([SplitLog].self, forKey: .computedSplits) ?? []
        feeAllocations = try container.decodeIfPresent([FeeAllocation].self, forKey: .feeAllocations) ?? []
        // v2 field — gracefully defaults to [] for legacy (v1) sessions
        personBreakdowns = try container.decodeIfPresent([PersonBreakdown].self, forKey: .personBreakdowns) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(receiptDate, forKey: .receiptDate)
        try container.encode(receiptDateSource, forKey: .receiptDateSource)
        try container.encode(receiptDateHasTime, forKey: .receiptDateHasTime)
        try container.encode(receiptImagePaths, forKey: .receiptImagePaths)
        try container.encode(participants, forKey: .participants)
        try container.encode(totalAmount, forKey: .totalAmount)
        try container.encode(paidBy, forKey: .paidBy)
        try container.encode(items, forKey: .items)
        try container.encode(computedSplits, forKey: .computedSplits)
        try container.encode(feeAllocations, forKey: .feeAllocations)
        try container.encode(personBreakdowns, forKey: .personBreakdowns)
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

//
//  StoredSession.swift
//  SplitLens
//
//  SwiftData model for persisted receipt sessions.
//

import Foundation
import SwiftData

@Model
final class StoredSession {
    @Attribute(.unique) var id: UUID
    var receiptDate: Date
    var totalAmount: Double
    var paidBy: String
    var createdAt: Date
    var schemaVersion: Int
    var payloadData: Data

    init(
        id: UUID,
        receiptDate: Date,
        totalAmount: Double,
        paidBy: String,
        createdAt: Date,
        schemaVersion: Int,
        payloadData: Data
    ) {
        self.id = id
        self.receiptDate = receiptDate
        self.totalAmount = totalAmount
        self.paidBy = paidBy
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
        self.payloadData = payloadData
    }
}

#Index<StoredSession>([\.receiptDate], [\.totalAmount], [\.paidBy])

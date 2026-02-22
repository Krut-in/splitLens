//
//  StoredPattern.swift
//  SplitLens
//
//  SwiftData model for persisted assignment patterns.
//

import Foundation
import SwiftData

@Model
final class StoredPattern {
    @Attribute(.unique) var id: UUID
    var normalizedItemName: String
    var normalizedStoreName: String?
    var consecutiveHits: Int
    var lastSeenAt: Date
    var payloadData: Data

    init(
        id: UUID,
        normalizedItemName: String,
        normalizedStoreName: String?,
        consecutiveHits: Int,
        lastSeenAt: Date,
        payloadData: Data
    ) {
        self.id = id
        self.normalizedItemName = normalizedItemName
        self.normalizedStoreName = normalizedStoreName
        self.consecutiveHits = consecutiveHits
        self.lastSeenAt = lastSeenAt
        self.payloadData = payloadData
    }
}

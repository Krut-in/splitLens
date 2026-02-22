//
//  StoredGroup.swift
//  SplitLens
//
//  SwiftData model for persisted participant groups.
//

import Foundation
import SwiftData

@Model
final class StoredGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var memberCount: Int
    var createdAt: Date
    var lastUsedAt: Date?
    var usageCount: Int
    var payloadData: Data

    init(
        id: UUID,
        name: String,
        memberCount: Int,
        createdAt: Date,
        lastUsedAt: Date?,
        usageCount: Int,
        payloadData: Data
    ) {
        self.id = id
        self.name = name
        self.memberCount = memberCount
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
        self.payloadData = payloadData
    }
}

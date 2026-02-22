//
//  AssignmentPattern.swift
//  SplitLens
//
//  Learned pattern model for Smart Assignment feature.
//

import Foundation

// MARK: - AssignmentPattern

/// A learned pattern recording which person(s) are typically assigned to a specific item
struct AssignmentPattern: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var normalizedItemName: String
    var displayItemName: String
    var normalizedStoreName: String?
    var displayStoreName: String?
    /// Sorted alphabetically for consistent comparison.
    var assignedParticipants: [String]
    var consecutiveHits: Int
    var createdAt: Date = Date()
    var lastSeenAt: Date = Date()
    var totalOccurrences: Int = 1
}

// MARK: - Computed Properties

extension AssignmentPattern {
    var isSuggestable: Bool {
        consecutiveHits >= AppConstants.SmartAssignment.minimumConsecutiveHits
    }

    var confidence: PatternConfidence {
        switch consecutiveHits {
        case 0...1: return .none
        case 2: return .likely
        case 3...4: return .strong
        default: return .veryStrong
        }
    }

    var isStale: Bool {
        let stalenessThreshold: TimeInterval = Double(AppConstants.SmartAssignment.stalenessDays) * 24 * 60 * 60
        return Date().timeIntervalSince(lastSeenAt) > stalenessThreshold
    }

    var isStoreSpecific: Bool {
        normalizedStoreName != nil && !normalizedStoreName!.isEmpty
    }

    var participantLabel: String {
        if assignedParticipants.count <= 2 {
            return assignedParticipants.joined(separator: ", ")
        } else {
            let first2 = assignedParticipants.prefix(2).joined(separator: ", ")
            return "\(first2) + \(assignedParticipants.count - 2) more"
        }
    }
}

// MARK: - CodingKeys

extension AssignmentPattern {
    enum CodingKeys: String, CodingKey {
        case id
        case normalizedItemName = "normalized_item_name"
        case displayItemName = "display_item_name"
        case normalizedStoreName = "normalized_store_name"
        case displayStoreName = "display_store_name"
        case assignedParticipants = "assigned_participants"
        case consecutiveHits = "consecutive_hits"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case totalOccurrences = "total_occurrences"
    }
}

// MARK: - PatternConfidence

enum PatternConfidence: String, Codable, Comparable {
    case none = "none"
    case likely = "likely"
    case strong = "strong"
    case veryStrong = "very_strong"

    static func < (lhs: PatternConfidence, rhs: PatternConfidence) -> Bool {
        let order: [PatternConfidence] = [.none, .likely, .strong, .veryStrong]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }

    var displayLabel: String {
        switch self {
        case .none: return ""
        case .likely: return "Suggested"
        case .strong: return "Usually"
        case .veryStrong: return "Always"
        }
    }

    var iconName: String {
        switch self {
        case .none: return ""
        case .likely: return "lightbulb.fill"
        case .strong: return "brain.fill"
        case .veryStrong: return "brain.head.profile.fill"
        }
    }

    var badgeColor: String {
        switch self {
        case .none: return "clear"
        case .likely: return "orange"
        case .strong: return "blue"
        case .veryStrong: return "green"
        }
    }
}

// MARK: - SuggestedAssignment

/// A suggestion for a single item's assignment
struct SuggestedAssignment: Equatable {
    let participants: [String]
    let confidence: PatternConfidence
    let sourcePatternId: UUID
    let isStoreSpecific: Bool
}

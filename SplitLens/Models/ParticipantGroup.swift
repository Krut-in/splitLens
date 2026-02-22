//
//  ParticipantGroup.swift
//  SplitLens
//
//  Domain model representing a saved reusable group of participant names.
//

import Foundation

/// A named, reusable group of participant names
struct ParticipantGroup: Identifiable, Codable, Equatable {

    // MARK: - Stored Properties

    /// Unique identifier
    var id: UUID = UUID()

    /// User-chosen group name (e.g. "Roommates", "Work Lunch Crew")
    var name: String

    /// Ordered list of participant names in this group
    var members: [String]

    /// SF Symbol icon name for visual identity (default: "person.3.fill")
    var iconName: String

    /// When this group was created
    var createdAt: Date = Date()

    /// When this group was last used to populate participants
    var lastUsedAt: Date?

    /// Number of times this group has been used
    var usageCount: Int = 0

    // MARK: - Computed Properties

    /// Formatted member count label (e.g. "3 members")
    var memberCountLabel: String {
        "\(members.count) \(members.count == 1 ? "member" : "members")"
    }

    /// Comma-separated member preview, truncated at 3 + "+ N more" if needed
    var memberPreview: String {
        if members.count <= 3 {
            return members.joined(separator: ", ")
        }
        let firstThree = members.prefix(3).joined(separator: ", ")
        let remaining = members.count - 3
        return "\(firstThree) + \(remaining) more"
    }

    /// First letters of up to 3 members, used for avatar display
    var avatarLetters: [String] {
        members.prefix(3).map { String($0.prefix(1).uppercased()) }
    }

    // MARK: - Equatable

    static func == (lhs: ParticipantGroup, rhs: ParticipantGroup) -> Bool {
        lhs.id == rhs.id
    }
}

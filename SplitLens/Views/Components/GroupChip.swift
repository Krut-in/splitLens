//
//  GroupChip.swift
//  SplitLens
//
//  Tappable chip representing a saved participant group.
//

import SwiftUI

/// A compact chip displaying a saved group, tappable to load its members.
struct GroupChip: View {
    let group: ParticipantGroup
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: group.iconName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(group.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
                Text(group.memberCountLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color.blue.opacity(0.15)
                    : Color(.secondarySystemBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HStack {
        GroupChip(
            group: ParticipantGroup(name: "Roomies", members: ["Krutin", "Rohan", "Nihar"], iconName: "house.fill"),
            isSelected: true
        ) {}

        GroupChip(
            group: ParticipantGroup(name: "Work Crew", members: ["Alice", "Bob", "Charlie", "Dave", "Eve"], iconName: "briefcase.fill"),
            isSelected: false
        ) {}
    }
    .padding()
}

//
//  GroupStore.swift
//  SplitLens
//
//  Protocol and implementations for saved participant group persistence.
//

import Foundation
import SwiftData

// MARK: - Error

enum GroupStoreError: Error, LocalizedError {
    case notFound
    case persistenceFailed(String)
    case decodeFailed(String)
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Group not found."
        case .persistenceFailed(let message):
            return "Could not persist group: \(message)"
        case .decodeFailed(let message):
            return "Could not decode group data: \(message)"
        case .duplicateName(let name):
            return "A group named '\(name)' already exists."
        }
    }
}

// MARK: - Protocol

protocol GroupStoreProtocol {
    /// Save a new or updated group (upsert by id)
    func saveGroup(_ group: ParticipantGroup) async throws

    /// Fetch all groups sorted by most recently used first, then newest created first
    func fetchAllGroups() async throws -> [ParticipantGroup]

    /// Delete a group by ID
    func deleteGroup(id: UUID) async throws

    /// Record that a group was used: increments usageCount and updates lastUsedAt
    func recordGroupUsage(id: UUID) async throws
}

// MARK: - SwiftData Implementation

final class SwiftDataGroupStore: GroupStoreProtocol {
    private let modelContainer: ModelContainer
    private let context: ModelContext
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(modelContainer: ModelContainer) throws {
        self.modelContainer = modelContainer
        self.context = ModelContext(modelContainer)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func saveGroup(_ group: ParticipantGroup) async throws {
        let payload = try encode(group: group)

        let id = group.id
        let fetchDescriptor = FetchDescriptor<StoredGroup>(
            predicate: #Predicate { stored in stored.id == id }
        )
        let existing = try context.fetch(fetchDescriptor).first

        if let existing {
            existing.name = group.name
            existing.memberCount = group.members.count
            existing.createdAt = group.createdAt
            existing.lastUsedAt = group.lastUsedAt
            existing.usageCount = group.usageCount
            existing.payloadData = payload
        } else {
            let stored = StoredGroup(
                id: group.id,
                name: group.name,
                memberCount: group.members.count,
                createdAt: group.createdAt,
                lastUsedAt: group.lastUsedAt,
                usageCount: group.usageCount,
                payloadData: payload
            )
            context.insert(stored)
        }

        do {
            try context.save()
        } catch {
            throw GroupStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    func fetchAllGroups() async throws -> [ParticipantGroup] {
        let fetchDescriptor = FetchDescriptor<StoredGroup>(
            sortBy: [SortDescriptor(\StoredGroup.createdAt, order: .reverse)]
        )
        let storedGroups = try context.fetch(fetchDescriptor)

        var groups: [ParticipantGroup] = []
        groups.reserveCapacity(storedGroups.count)
        for stored in storedGroups {
            do {
                let group = try decode(payloadData: stored.payloadData)
                groups.append(group)
            } catch {
                ErrorHandler.shared.log(error, context: "SwiftDataGroupStore.fetchAllGroups.decode")
            }
        }

        return sortedGroups(groups)
    }

    func deleteGroup(id: UUID) async throws {
        let fetchDescriptor = FetchDescriptor<StoredGroup>(
            predicate: #Predicate { stored in stored.id == id }
        )
        guard let stored = try context.fetch(fetchDescriptor).first else {
            throw GroupStoreError.notFound
        }
        context.delete(stored)
        do {
            try context.save()
        } catch {
            throw GroupStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    func recordGroupUsage(id: UUID) async throws {
        let fetchDescriptor = FetchDescriptor<StoredGroup>(
            predicate: #Predicate { stored in stored.id == id }
        )
        guard let stored = try context.fetch(fetchDescriptor).first else {
            throw GroupStoreError.notFound
        }

        var group = try decode(payloadData: stored.payloadData)
        group.lastUsedAt = Date()
        group.usageCount += 1

        stored.lastUsedAt = group.lastUsedAt
        stored.usageCount = group.usageCount
        stored.payloadData = try encode(group: group)

        do {
            try context.save()
        } catch {
            throw GroupStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func encode(group: ParticipantGroup) throws -> Data {
        do {
            return try encoder.encode(group)
        } catch {
            throw GroupStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    private func decode(payloadData: Data) throws -> ParticipantGroup {
        do {
            return try decoder.decode(ParticipantGroup.self, from: payloadData)
        } catch {
            throw GroupStoreError.decodeFailed(error.localizedDescription)
        }
    }
}

// MARK: - In-Memory Fallback

final class InMemoryGroupStore: GroupStoreProtocol {
    private var storage: [UUID: ParticipantGroup] = [:]

    func saveGroup(_ group: ParticipantGroup) async throws {
        storage[group.id] = group
    }

    func fetchAllGroups() async throws -> [ParticipantGroup] {
        sortedGroups(Array(storage.values))
    }

    func deleteGroup(id: UUID) async throws {
        guard storage[id] != nil else { throw GroupStoreError.notFound }
        storage.removeValue(forKey: id)
    }

    func recordGroupUsage(id: UUID) async throws {
        guard var group = storage[id] else { throw GroupStoreError.notFound }
        group.lastUsedAt = Date()
        group.usageCount += 1
        storage[id] = group
    }
}

// MARK: - Sort Helper

/// Sorts groups: most recently used first (nil lastUsedAt last), then newest created first.
private func sortedGroups(_ groups: [ParticipantGroup]) -> [ParticipantGroup] {
    groups.sorted { a, b in
        switch (a.lastUsedAt, b.lastUsedAt) {
        case let (aDate?, bDate?): return aDate > bDate
        case (.some, .none):      return true
        case (.none, .some):      return false
        case (.none, .none):      return a.createdAt > b.createdAt
        }
    }
}

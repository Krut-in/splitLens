//
//  PatternStore.swift
//  SplitLens
//
//  Protocol and implementations for assignment pattern persistence.
//

import Foundation
import SwiftData

// MARK: - Error

enum PatternStoreError: Error, LocalizedError {
    case notFound
    case persistenceFailed(String)
    case decodeFailed(String)
    case storageLimitReached

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Pattern not found."
        case .persistenceFailed(let msg):
            return "Could not persist pattern: \(msg)"
        case .decodeFailed(let msg):
            return "Could not decode pattern data: \(msg)"
        case .storageLimitReached:
            return "Pattern storage limit reached."
        }
    }
}

// MARK: - Protocol

protocol PatternStoreProtocol {
    func savePattern(_ pattern: AssignmentPattern) async throws
    func savePatterns(_ patterns: [AssignmentPattern]) async throws
    func fetchSuggestablePatterns(storeName: String?) async throws -> [AssignmentPattern]
    func fetchPattern(normalizedItemName: String, normalizedStoreName: String?) async throws -> AssignmentPattern?
    func fetchPatterns(forItem normalizedItemName: String) async throws -> [AssignmentPattern]
    func deletePattern(id: UUID) async throws
    func cleanupStalePatterns() async throws -> Int
    func patternCount() async throws -> Int
    func deleteAllPatterns() async throws
}

// MARK: - SwiftData Implementation

final class SwiftDataPatternStore: PatternStoreProtocol {
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

    func savePattern(_ pattern: AssignmentPattern) async throws {
        try enforceStorageLimit()
        let payload = try encode(pattern)
        let id = pattern.id
        let fetchDescriptor = FetchDescriptor<StoredPattern>(
            predicate: #Predicate { stored in stored.id == id }
        )
        let existing = try context.fetch(fetchDescriptor).first

        if let existing {
            existing.normalizedItemName = pattern.normalizedItemName
            existing.normalizedStoreName = pattern.normalizedStoreName
            existing.consecutiveHits = pattern.consecutiveHits
            existing.lastSeenAt = pattern.lastSeenAt
            existing.payloadData = payload
        } else {
            let stored = StoredPattern(
                id: pattern.id,
                normalizedItemName: pattern.normalizedItemName,
                normalizedStoreName: pattern.normalizedStoreName,
                consecutiveHits: pattern.consecutiveHits,
                lastSeenAt: pattern.lastSeenAt,
                payloadData: payload
            )
            context.insert(stored)
        }
        do {
            try context.save()
        } catch {
            throw PatternStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    func savePatterns(_ patterns: [AssignmentPattern]) async throws {
        for pattern in patterns {
            try await savePattern(pattern)
        }
    }

    func fetchSuggestablePatterns(storeName: String?) async throws -> [AssignmentPattern] {
        let minHits = AppConstants.SmartAssignment.minimumConsecutiveHits
        let fetchDescriptor = FetchDescriptor<StoredPattern>(
            predicate: #Predicate { stored in stored.consecutiveHits >= minHits }
        )
        let storedPatterns = try context.fetch(fetchDescriptor)

        let staleThreshold: TimeInterval = Double(AppConstants.SmartAssignment.stalenessDays) * 24 * 60 * 60
        let cutoff = Date().addingTimeInterval(-staleThreshold)

        var result: [AssignmentPattern] = []
        for stored in storedPatterns {
            guard stored.lastSeenAt >= cutoff else { continue }
            guard let pattern = try? decode(stored.payloadData) else { continue }
            result.append(pattern)
        }
        return result
    }

    func fetchPattern(normalizedItemName: String, normalizedStoreName: String?) async throws -> AssignmentPattern? {
        let fetchDescriptor = FetchDescriptor<StoredPattern>(
            predicate: #Predicate { stored in stored.normalizedItemName == normalizedItemName }
        )
        let matches = try context.fetch(fetchDescriptor)

        let target: StoredPattern?
        if let storeName = normalizedStoreName {
            target = matches.first { $0.normalizedStoreName == storeName }
                ?? matches.first { $0.normalizedStoreName == nil }
        } else {
            target = matches.first { $0.normalizedStoreName == nil }
                ?? matches.first
        }

        guard let target else { return nil }
        return try? decode(target.payloadData)
    }

    func fetchPatterns(forItem normalizedItemName: String) async throws -> [AssignmentPattern] {
        let fetchDescriptor = FetchDescriptor<StoredPattern>(
            predicate: #Predicate { stored in stored.normalizedItemName == normalizedItemName }
        )
        let stored = try context.fetch(fetchDescriptor)
        return stored.compactMap { try? decode($0.payloadData) }
    }

    func deletePattern(id: UUID) async throws {
        let fetchDescriptor = FetchDescriptor<StoredPattern>(
            predicate: #Predicate { stored in stored.id == id }
        )
        guard let stored = try context.fetch(fetchDescriptor).first else {
            throw PatternStoreError.notFound
        }
        context.delete(stored)
        do {
            try context.save()
        } catch {
            throw PatternStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    func cleanupStalePatterns() async throws -> Int {
        let cleanupThreshold: TimeInterval = Double(AppConstants.SmartAssignment.cleanupDays) * 24 * 60 * 60
        let cutoff = Date().addingTimeInterval(-cleanupThreshold)

        let fetchDescriptor = FetchDescriptor<StoredPattern>(
            predicate: #Predicate { stored in stored.lastSeenAt < cutoff }
        )
        let stale = try context.fetch(fetchDescriptor)
        let count = stale.count
        for stored in stale {
            context.delete(stored)
        }
        if count > 0 {
            do {
                try context.save()
            } catch {
                throw PatternStoreError.persistenceFailed(error.localizedDescription)
            }
        }
        return count
    }

    func patternCount() async throws -> Int {
        let fetchDescriptor = FetchDescriptor<StoredPattern>()
        return try context.fetchCount(fetchDescriptor)
    }

    func deleteAllPatterns() async throws {
        let fetchDescriptor = FetchDescriptor<StoredPattern>()
        let all = try context.fetch(fetchDescriptor)
        for stored in all {
            context.delete(stored)
        }
        do {
            try context.save()
        } catch {
            throw PatternStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func enforceStorageLimit() throws {
        let count = (try? context.fetchCount(FetchDescriptor<StoredPattern>())) ?? 0
        guard count >= AppConstants.SmartAssignment.maxPatterns else { return }

        // Evict oldest patterns
        var fetchDescriptor = FetchDescriptor<StoredPattern>(
            sortBy: [SortDescriptor(\StoredPattern.lastSeenAt, order: .forward)]
        )
        fetchDescriptor.fetchLimit = count - AppConstants.SmartAssignment.maxPatterns + 1
        let oldest = (try? context.fetch(fetchDescriptor)) ?? []
        for stored in oldest {
            context.delete(stored)
        }
        try? context.save()
    }

    private func encode(_ pattern: AssignmentPattern) throws -> Data {
        do {
            return try encoder.encode(pattern)
        } catch {
            throw PatternStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    private func decode(_ data: Data) throws -> AssignmentPattern {
        do {
            return try decoder.decode(AssignmentPattern.self, from: data)
        } catch {
            throw PatternStoreError.decodeFailed(error.localizedDescription)
        }
    }
}

// MARK: - In-Memory Fallback

final class InMemoryPatternStore: PatternStoreProtocol {
    private var storage: [UUID: AssignmentPattern] = [:]

    func savePattern(_ pattern: AssignmentPattern) async throws {
        storage[pattern.id] = pattern
    }

    func savePatterns(_ patterns: [AssignmentPattern]) async throws {
        for pattern in patterns {
            storage[pattern.id] = pattern
        }
    }

    func fetchSuggestablePatterns(storeName: String?) async throws -> [AssignmentPattern] {
        storage.values.filter { $0.isSuggestable && !$0.isStale }
    }

    func fetchPattern(normalizedItemName: String, normalizedStoreName: String?) async throws -> AssignmentPattern? {
        let matches = storage.values.filter { $0.normalizedItemName == normalizedItemName }
        if let storeName = normalizedStoreName {
            return matches.first { $0.normalizedStoreName == storeName }
                ?? matches.first { $0.normalizedStoreName == nil }
        }
        return matches.first { $0.normalizedStoreName == nil } ?? matches.first
    }

    func fetchPatterns(forItem normalizedItemName: String) async throws -> [AssignmentPattern] {
        storage.values.filter { $0.normalizedItemName == normalizedItemName }
    }

    func deletePattern(id: UUID) async throws {
        guard storage[id] != nil else { throw PatternStoreError.notFound }
        storage.removeValue(forKey: id)
    }

    func cleanupStalePatterns() async throws -> Int {
        let cleanupThreshold: TimeInterval = Double(AppConstants.SmartAssignment.cleanupDays) * 24 * 60 * 60
        let cutoff = Date().addingTimeInterval(-cleanupThreshold)
        let stale = storage.values.filter { $0.lastSeenAt < cutoff }
        for pattern in stale { storage.removeValue(forKey: pattern.id) }
        return stale.count
    }

    func patternCount() async throws -> Int {
        storage.count
    }

    func deleteAllPatterns() async throws {
        storage.removeAll()
    }
}

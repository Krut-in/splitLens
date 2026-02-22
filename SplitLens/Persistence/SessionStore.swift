//
//  SessionStore.swift
//  SplitLens
//
//  Local session persistence interfaces and implementations.
//

import Foundation
import SwiftData

protocol SessionStoreProtocol {
    func saveSession(_ session: ReceiptSession) async throws
    func fetchSession(id: UUID) async throws -> ReceiptSession
    func fetchAllSessions(limit: Int?) async throws -> [ReceiptSession]
    func deleteSession(id: UUID) async throws
    func fetchRecentSessions(count: Int) async throws -> [ReceiptSession]
}

enum SessionStoreError: Error, LocalizedError {
    case notFound
    case persistenceFailed(String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Session not found."
        case .persistenceFailed(let message):
            return "Could not persist session: \(message)"
        case .decodeFailed(let message):
            return "Could not decode session data: \(message)"
        }
    }
}

private struct StoredSessionEnvelope: Codable {
    let schemaVersion: Int
    let session: ReceiptSession
}

final class SwiftDataSessionStore: SessionStoreProtocol {
    private static let currentSchemaVersion = 1

    private let modelContainer: ModelContainer
    private let context: ModelContext
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(modelContainer: ModelContainer? = nil) throws {
        if let modelContainer {
            self.modelContainer = modelContainer
        } else {
            self.modelContainer = try ModelContainer(for: StoredSession.self)
        }

        context = ModelContext(self.modelContainer)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func saveSession(_ session: ReceiptSession) async throws {
        let payload = try encode(session: session)

        let fetchDescriptor = FetchDescriptor<StoredSession>(
            predicate: #Predicate { stored in
                stored.id == session.id
            }
        )
        let existing = try context.fetch(fetchDescriptor).first

        if let existing {
            existing.receiptDate = session.receiptDate
            existing.totalAmount = session.totalAmount
            existing.paidBy = session.paidBy
            existing.createdAt = session.createdAt
            existing.schemaVersion = Self.currentSchemaVersion
            existing.payloadData = payload
        } else {
            let stored = StoredSession(
                id: session.id,
                receiptDate: session.receiptDate,
                totalAmount: session.totalAmount,
                paidBy: session.paidBy,
                createdAt: session.createdAt,
                schemaVersion: Self.currentSchemaVersion,
                payloadData: payload
            )
            context.insert(stored)
        }

        do {
            try context.save()
        } catch {
            throw SessionStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    func fetchSession(id: UUID) async throws -> ReceiptSession {
        let fetchDescriptor = FetchDescriptor<StoredSession>(
            predicate: #Predicate { stored in
                stored.id == id
            }
        )

        guard let stored = try context.fetch(fetchDescriptor).first else {
            throw SessionStoreError.notFound
        }

        return try decode(payloadData: stored.payloadData)
    }

    func fetchAllSessions(limit: Int?) async throws -> [ReceiptSession] {
        var fetchDescriptor = FetchDescriptor<StoredSession>(
            sortBy: [SortDescriptor(\StoredSession.receiptDate, order: .reverse)]
        )
        if let limit {
            fetchDescriptor.fetchLimit = limit
        }

        let storedSessions = try context.fetch(fetchDescriptor)
        var sessions: [ReceiptSession] = []
        sessions.reserveCapacity(storedSessions.count)

        for stored in storedSessions {
            do {
                let session = try decode(payloadData: stored.payloadData)
                sessions.append(session)
            } catch {
                ErrorHandler.shared.log(error, context: "SwiftDataSessionStore.fetchAllSessions.decode")
            }
        }

        return sessions
    }

    func deleteSession(id: UUID) async throws {
        let fetchDescriptor = FetchDescriptor<StoredSession>(
            predicate: #Predicate { stored in
                stored.id == id
            }
        )

        guard let stored = try context.fetch(fetchDescriptor).first else {
            throw SessionStoreError.notFound
        }

        context.delete(stored)
        do {
            try context.save()
        } catch {
            throw SessionStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    func fetchRecentSessions(count: Int) async throws -> [ReceiptSession] {
        try await fetchAllSessions(limit: count)
    }

    private func encode(session: ReceiptSession) throws -> Data {
        let envelope = StoredSessionEnvelope(
            schemaVersion: Self.currentSchemaVersion,
            session: session
        )
        do {
            return try encoder.encode(envelope)
        } catch {
            throw SessionStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    private func decode(payloadData: Data) throws -> ReceiptSession {
        do {
            let envelope = try decoder.decode(StoredSessionEnvelope.self, from: payloadData)
            return envelope.session
        } catch {
            // Backward compatibility for any pre-envelope payloads.
            if let legacySession = try? decoder.decode(ReceiptSession.self, from: payloadData) {
                return legacySession
            }
            throw SessionStoreError.decodeFailed(error.localizedDescription)
        }
    }
}

final class InMemorySessionStore: SessionStoreProtocol {
    private var storage: [UUID: ReceiptSession]

    init(sampleSessions: [ReceiptSession] = []) {
        storage = [:]
        for session in sampleSessions {
            storage[session.id] = session
        }
    }

    func saveSession(_ session: ReceiptSession) async throws {
        storage[session.id] = session
    }

    func fetchSession(id: UUID) async throws -> ReceiptSession {
        guard let session = storage[id] else {
            throw SessionStoreError.notFound
        }
        return session
    }

    func fetchAllSessions(limit: Int?) async throws -> [ReceiptSession] {
        let all = storage.values.sorted { $0.receiptDate > $1.receiptDate }
        guard let limit else {
            return all
        }
        return Array(all.prefix(limit))
    }

    func deleteSession(id: UUID) async throws {
        guard storage[id] != nil else {
            throw SessionStoreError.notFound
        }
        storage.removeValue(forKey: id)
    }

    func fetchRecentSessions(count: Int) async throws -> [ReceiptSession] {
        try await fetchAllSessions(limit: count)
    }
}

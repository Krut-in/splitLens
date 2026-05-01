//
//  PatternLearningEngine.swift
//  SplitLens
//
//  Core intelligence for Smart Assignments — learns and applies item assignment patterns.
//

import Foundation

// MARK: - Protocol

protocol PatternLearningEngineProtocol {
    func learnPatterns(from session: ReceiptSession, storeName: String?) async throws
    func suggestAssignments(
        for items: [ReceiptItem],
        participants: [String],
        storeName: String?
    ) async throws -> [UUID: SuggestedAssignment]
    func bootstrapFromHistory(sessions: [ReceiptSession]) async throws
}

// MARK: - Implementation

final class PatternLearningEngine: PatternLearningEngineProtocol {

    private let patternStore: PatternStoreProtocol

    init(patternStore: PatternStoreProtocol) {
        self.patternStore = patternStore
    }

    // MARK: - learnPatterns

    func learnPatterns(from session: ReceiptSession, storeName: String?) async throws {
        let normalizedStore = storeName.flatMap { s in
            s.isEmpty ? nil : Self.normalizeStoreName(s)
        }

        // Clean up stale patterns opportunistically
        _ = try? await patternStore.cleanupStalePatterns()

        for item in session.items {
            guard item.isAssigned else { continue }
            guard item.name.count <= AppConstants.SmartAssignment.maxItemNameLength else { continue }

            // Skip items assigned to ALL participants — not meaningful signals
            let sortedAssignees = item.assignedTo.sorted()
            let sortedParticipants = session.participants.sorted()
            if sortedAssignees == sortedParticipants && session.participants.count > 1 { continue }

            let normalizedName = Self.normalizeItemName(item.name)
            guard !normalizedName.isEmpty else { continue }

            if var existing = try await patternStore.fetchPattern(
                normalizedItemName: normalizedName,
                normalizedStoreName: normalizedStore
            ) {
                if existing.assignedParticipants == sortedAssignees {
                    existing.consecutiveHits += 1
                    existing.totalOccurrences += 1
                    existing.lastSeenAt = Date()
                    existing.displayItemName = item.name
                    try await patternStore.savePattern(existing)
                } else {
                    existing.assignedParticipants = sortedAssignees
                    existing.consecutiveHits = 1
                    existing.totalOccurrences += 1
                    existing.lastSeenAt = Date()
                    existing.displayItemName = item.name
                    try await patternStore.savePattern(existing)
                }
            } else {
                let newPattern = AssignmentPattern(
                    normalizedItemName: normalizedName,
                    displayItemName: item.name,
                    normalizedStoreName: normalizedStore,
                    displayStoreName: storeName,
                    assignedParticipants: sortedAssignees,
                    consecutiveHits: 1,
                    totalOccurrences: 1
                )
                try await patternStore.savePattern(newPattern)
            }
        }
    }

    // MARK: - suggestAssignments

    func suggestAssignments(
        for items: [ReceiptItem],
        participants: [String],
        storeName: String?
    ) async throws -> [UUID: SuggestedAssignment] {
        let normalizedStore = storeName.flatMap { s in
            s.isEmpty ? nil : Self.normalizeStoreName(s)
        }

        let allPatterns = try await patternStore.fetchSuggestablePatterns(storeName: normalizedStore)
        guard !allPatterns.isEmpty else { return [:] }

        var suggestions: [UUID: SuggestedAssignment] = [:]

        for item in items where !item.isAssigned {
            let normalizedName = Self.normalizeItemName(item.name)
            guard !normalizedName.isEmpty else { continue }

            var bestMatch: AssignmentPattern?
            var bestSimilarity: Double = 0.0

            for pattern in allPatterns {
                let similarity = Self.levenshteinSimilarity(normalizedName, pattern.normalizedItemName)
                if similarity >= AppConstants.SmartAssignment.nameSimilarityThreshold {
                    if let current = bestMatch {
                        if patternHasHigherPriority(pattern, than: current, forStoreName: normalizedStore) {
                            bestMatch = pattern
                            bestSimilarity = similarity
                        }
                    } else {
                        bestMatch = pattern
                        bestSimilarity = similarity
                    }
                }
            }

            if let match = bestMatch, match.isSuggestable, bestSimilarity > 0 {
                // All suggested participants must exist in current session
                let valid = match.assignedParticipants.filter { participants.contains($0) }
                if valid == match.assignedParticipants {
                    suggestions[item.id] = SuggestedAssignment(
                        participants: match.assignedParticipants,
                        confidence: match.confidence,
                        sourcePatternId: match.id,
                        isStoreSpecific: match.isStoreSpecific
                    )
                }
            }
        }

        return suggestions
    }

    // MARK: - bootstrapFromHistory

    func bootstrapFromHistory(sessions: [ReceiptSession]) async throws {
        let sorted = sessions.sorted { $0.receiptDate < $1.receiptDate }
        for session in sorted {
            try await learnPatterns(from: session, storeName: session.storeName)
        }
    }

    // MARK: - Priority Comparison

    private func patternHasHigherPriority(
        _ candidate: AssignmentPattern,
        than current: AssignmentPattern,
        forStoreName storeName: String?
    ) -> Bool {
        let candidateIsStore = candidate.normalizedStoreName == storeName && storeName != nil
        let currentIsStore = current.normalizedStoreName == storeName && storeName != nil

        if candidateIsStore != currentIsStore {
            return candidateIsStore
        }
        if candidate.consecutiveHits != current.consecutiveHits {
            return candidate.consecutiveHits > current.consecutiveHits
        }
        return candidate.lastSeenAt > current.lastSeenAt
    }

    // MARK: - Normalisation

    /// Normalises an item name for pattern storage and matching
    static func normalizeItemName(_ name: String) -> String {
        var normalized = name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized.replacingOccurrences(of: "[*#@]", with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "[-_]", with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalises a store name for pattern matching
    static func normalizeStoreName(_ name: String) -> String {
        var normalized = name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized.replacingOccurrences(of: "#\\d+", with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(
            of: "\\b(no\\.?|store)\\s*\\d+",
            with: "",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: "\\b(inc\\.?|llc\\.?|corp\\.?|ltd\\.?)\\b",
            with: "",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(of: "[-_]", with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Levenshtein Similarity

    /// Computes similarity ratio (0.0-1.0) between two strings using Levenshtein distance
    static func levenshteinSimilarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1.0 }
        let aChars = Array(a)
        let bChars = Array(b)
        let aLen = aChars.count
        let bLen = bChars.count

        if aLen == 0 || bLen == 0 {
            return aLen == bLen ? 1.0 : 0.0
        }

        var dp = Array(repeating: Array(repeating: 0, count: bLen + 1), count: aLen + 1)
        for i in 0...aLen { dp[i][0] = i }
        for j in 0...bLen { dp[0][j] = j }

        for i in 1...aLen {
            for j in 1...bLen {
                if aChars[i - 1] == bChars[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
                }
            }
        }

        let distance = dp[aLen][bLen]
        let maxLen = max(aLen, bLen)
        return 1.0 - Double(distance) / Double(maxLen)
    }
}

// MARK: - Bootstrap Helper

extension PatternLearningEngine {
    private static let bootstrapKey = "smartAssignment.bootstrapCompleted"

    func bootstrapIfNeeded(sessionStore: SessionStoreProtocol) async {
        guard !UserDefaults.standard.bool(forKey: Self.bootstrapKey) else { return }

        do {
            let sessions = try await sessionStore.fetchAllSessions(limit: nil)
            try await bootstrapFromHistory(sessions: sessions)
            UserDefaults.standard.set(true, forKey: Self.bootstrapKey)
        } catch {
            ErrorHandler.shared.log(error, context: "PatternLearningEngine.bootstrap")
        }
    }
}

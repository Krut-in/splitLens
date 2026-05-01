//
//  ScanDraftStore.swift
//  SplitLens
//
//  In-memory cache for in-progress scan data so that downstream screens
//  preserve their state when the user navigates backward and forward
//  through the scan flow. Cleared on session save or app restart.
//

import Foundation

// MARK: - ScanDraft

/// Snapshot of in-progress data for a single scan, keyed by `ScanMetadata.id`.
/// Each downstream view model writes to the relevant fields as the user
/// edits, and reads back any prior values when the view is reconstructed.
struct ScanDraft {
    /// Identifier of the scan this draft belongs to.
    let scanId: UUID

    /// Latest edited items, including any per-item assignments.
    var items: [ReceiptItem]?

    /// Latest list of fees (after user edits in ItemsEditor).
    var fees: [Fee]?

    /// Participant names entered on ParticipantsEntryView.
    var participants: [String]?

    /// Selected payer name.
    var paidBy: String?

    /// Total bill amount confirmed on the participants screen.
    var totalAmount: Double?

    /// Allocations chosen on the tax/tip screen.
    var feeAllocations: [FeeAllocation]?

    /// Wall-clock time of the last write. Used for diagnostic purposes only.
    var lastUpdated: Date

    init(scanId: UUID, lastUpdated: Date = Date()) {
        self.scanId = scanId
        self.lastUpdated = lastUpdated
    }
}

// MARK: - ScanDraftStoreProtocol

protocol ScanDraftStoreProtocol: AnyObject {
    /// Returns the current draft for the given scan, if one exists.
    func draft(for scanId: UUID) -> ScanDraft?

    /// Mutates the draft for the given scan. Creates a new empty draft
    /// if one does not yet exist.
    func update(scanId: UUID, mutation: (inout ScanDraft) -> Void)

    /// Clears the draft for the given scan. Called after a successful save.
    func clear(scanId: UUID)

    /// Clears every cached draft. Useful for tests or a hard reset.
    func clearAll()
}

// MARK: - InMemoryScanDraftStore

/// Thread-safe in-memory implementation. Drafts live for the lifetime of the
/// app process; restarting the app discards all drafts.
final class InMemoryScanDraftStore: ScanDraftStoreProtocol {

    private var drafts: [UUID: ScanDraft] = [:]
    private let lock = NSLock()

    func draft(for scanId: UUID) -> ScanDraft? {
        lock.lock()
        defer { lock.unlock() }
        return drafts[scanId]
    }

    func update(scanId: UUID, mutation: (inout ScanDraft) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var draft = drafts[scanId] ?? ScanDraft(scanId: scanId)
        mutation(&draft)
        draft.lastUpdated = Date()
        drafts[scanId] = draft
    }

    func clear(scanId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        drafts.removeValue(forKey: scanId)
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        drafts.removeAll()
    }
}

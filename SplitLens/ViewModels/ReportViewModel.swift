//
//  ReportViewModel.swift
//  SplitLens
//
//  ViewModel for final report generation and session saving
//

import Foundation
import SwiftUI

@MainActor
final class ReportViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The complete receipt session
    @Published var session: ReceiptSession

    /// Loading state for save operation
    @Published var isSaving = false
    
    /// Success message
    @Published var successMessage: String?
    
    /// Error message
    @Published var errorMessage: String?
    
    /// Warnings from bill split calculation
    @Published var warnings: [BillSplitWarning] = []

    /// Show success toast
    @Published var showSuccessToast = false
    
    /// Success toast message
    @Published var toastMessage = ""
    
    // MARK: - Dependencies
    
    private let billSplitEngine: BillSplitEngineProtocol
    private let reportEngine: ReportGenerationEngineProtocol
    private let sessionStore: SessionStoreProtocol
    private let receiptImageStore: ReceiptImageStoreProtocol
    private let scanMetadata: ScanMetadata
    private let patternLearningEngine: PatternLearningEngineProtocol?
    private let scanDraftStore: ScanDraftStoreProtocol
    
    // MARK: - Computed Properties
    
    /// Formatted splits for display
    var formattedSplits: [SplitLog] {
        session.computedSplits
    }
    
    /// Whether the session has been saved
    @Published var isSaved = false
    
    // MARK: - Initialization
    
    init(
        session: ReceiptSession,
        scanMetadata: ScanMetadata,
        billSplitEngine: BillSplitEngineProtocol = DependencyContainer.shared.billSplitEngine,
        reportEngine: ReportGenerationEngineProtocol = DependencyContainer.shared.reportEngine,
        sessionStore: SessionStoreProtocol = DependencyContainer.shared.sessionStore,
        receiptImageStore: ReceiptImageStoreProtocol = DependencyContainer.shared.receiptImageStore,
        patternLearningEngine: PatternLearningEngineProtocol? = DependencyContainer.shared.patternLearningEngine,
        scanDraftStore: ScanDraftStoreProtocol = DependencyContainer.shared.scanDraftStore
    ) {
        self.session = session
        self.scanMetadata = scanMetadata
        self.billSplitEngine = billSplitEngine
        self.reportEngine = reportEngine
        self.sessionStore = sessionStore
        self.receiptImageStore = receiptImageStore
        self.patternLearningEngine = patternLearningEngine
        self.scanDraftStore = scanDraftStore

        // Compute splits on initialization
        computeSplits()
    }
    
    // MARK: - Split Calculation
    
    /// Computes the bill splits
    func computeSplits() {
        do {
            let result = try billSplitEngine.computeSplits(session: session)
            session.computedSplits = result.splits
            session.personBreakdowns = result.personBreakdowns
            warnings = result.warnings
            
            // Clear any previous errors
            errorMessage = nil

        } catch let error as BillSplitError {
            ErrorHandler.shared.log(error, context: "ReportViewModel.computeSplits")
            errorMessage = error.localizedDescription
            session.computedSplits = []
            warnings = []
            
        } catch {
            ErrorHandler.shared.log(error, context: "ReportViewModel.computeSplits")
            errorMessage = "Failed to calculate bill splits"
            session.computedSplits = []
            warnings = []
        }
    }
    
    // MARK: - Share Summary

    /// Gets the rich-text shareable summary used by the Share button.
    func getShareableSummary() -> String {
        reportEngine.generateShareableSummary(for: session)
    }
    
    // MARK: - Session Management
    
    /// Saves the session to the database
    func saveSession() async {
        guard !isSaving else { return }
        
        isSaving = true
        errorMessage = nil
        successMessage = nil
        var shouldCleanupImages = false

        do {
            let imagePaths = try receiptImageStore.saveCompressedImages(
                scanMetadata.selectedImages,
                sessionId: session.id
            )
            shouldCleanupImages = true

            var updatedSession = session
            let resolvedReceiptDate = scanMetadata.ocrReceiptDate ?? scanMetadata.scanCapturedAt
            let resolvedSource: ReceiptDateSource = scanMetadata.ocrReceiptDate == nil
                ? .scanTimestampFallback
                : .ocrExtracted
            let resolvedHasTime = scanMetadata.ocrReceiptDate == nil
                ? true
                : scanMetadata.ocrReceiptDateHasTime

            updatedSession.receiptDate = resolvedReceiptDate
            updatedSession.receiptDateSource = resolvedSource
            updatedSession.receiptDateHasTime = resolvedHasTime
            updatedSession.receiptImagePaths = imagePaths

            try await sessionStore.saveSession(updatedSession)

            session = updatedSession
            isSaved = true
            successMessage = "Session saved successfully!"

            // The scan draft is no longer needed once the session is saved.
            // Clearing prevents the next scan with a recycled metadata id from
            // accidentally restoring this session's items, fees, or assignments.
            scanDraftStore.clear(scanId: scanMetadata.id)

            // Learn assignment patterns from this session (fire-and-forget)
            if let engine = patternLearningEngine {
                Task {
                    try? await engine.learnPatterns(
                        from: updatedSession,
                        storeName: scanMetadata.storeName
                    )
                }
            }

        } catch let error as ReceiptImageStoreError {
            ErrorHandler.shared.log(error, context: "ReportViewModel.saveSession.imageStore")
            errorMessage = error.localizedDescription
        } catch let error as SessionStoreError {
            if shouldCleanupImages {
                try? receiptImageStore.deleteImages(for: session.id)
            }
            ErrorHandler.shared.log(error, context: "ReportViewModel.saveSession.sessionStore")
            errorMessage = error.localizedDescription
        } catch {
            if shouldCleanupImages {
                try? receiptImageStore.deleteImages(for: session.id)
            }
            ErrorHandler.shared.log(error, context: "ReportViewModel.saveSession")
            errorMessage = "Failed to save session"
        }
        
        isSaving = false
    }
    
    // MARK: - Per-participant helpers

    /// Gets total owed by a participant
    func totalOwed(by participant: String) -> String {
        let amount = session.totalOwed(by: participant)
        return CurrencyFormatter.shared.format(amount)
    }

    /// Gets splits for a specific participant
    func splitsFor(participant: String) -> [SplitLog] {
        session.splits(for: participant)
    }

    // MARK: - Chart Data
    
    /// Gets per-person totals for pie chart
    func getPersonTotals() -> [String: Double] {
        var totals: [String: Double] = [:]
        for participant in session.participants {
            totals[participant] = session.totalOwed(by: participant)
        }
        return totals
    }
    
    /// Gets balance data for balance chart
    func getBalances() -> [String: Double] {
        var balances: [String: Double] = [:]
        for participant in session.participants {
            let owed = session.totalOwed(by: participant)
            let balance: Double
            
            if participant == session.paidBy {
                // Payer's balance = total - their consumption
                balance = session.totalAmount - owed
            } else {
                // Others owe money (negative balance)
                balance = -owed
            }
            
            balances[participant] = balance
        }
        return balances
    }
    
    /// Gets owe/lent data for bar chart
    func getOweLentData() -> [(String, Double)] {
        getBalances().sorted { $0.key < $1.key }
    }
    
    /// Gets items for a specific split (for drill-down)
    func getItemsForSplit(_ split: SplitLog) -> [ReceiptItem] {
        session.items.filter { $0.isAssigned(to: split.from) }
    }
}


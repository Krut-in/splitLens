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
    
    /// Generated report text
    @Published var reportText: String = ""
    
    /// Loading state for save operation
    @Published var isSaving = false
    
    /// Success message
    @Published var successMessage: String?
    
    /// Error message
    @Published var errorMessage: String?
    
    /// Warnings from bill split calculation
    @Published var warnings: [BillSplitWarning] = []
    
    /// Whether to show share sheet
    @Published var showShareSheet = false
    
    // MARK: - Dependencies
    
    private let billSplitEngine: BillSplitEngineProtocol
    private let reportEngine: ReportGenerationEngineProtocol
    private let supabaseService: SupabaseServiceProtocol
    
    // MARK: - Computed Properties
    
    /// Formatted splits for display
    var formattedSplits: [SplitLog] {
        session.computedSplits
    }
    
    /// Whether the session has been saved
    var isSaved = false
    
    // MARK: - Initialization
    
    init(
        session: ReceiptSession,
        billSplitEngine: BillSplitEngineProtocol = DependencyContainer.shared.billSplitEngine,
        reportEngine: ReportGenerationEngineProtocol = DependencyContainer.shared.reportEngine,
        supabaseService: SupabaseServiceProtocol = DependencyContainer.shared.supabaseService
    ) {
        self.session = session
        self.billSplitEngine = billSplitEngine
        self.reportEngine = reportEngine
        self.supabaseService = supabaseService
        
        // Compute splits on initialization
        computeSplits()
    }
    
    // MARK: - Split Calculation
    
    /// Computes the bill splits
    func computeSplits() {
        do {
            let result = try billSplitEngine.computeSplits(session: session)
            session.computedSplits = result.splits
            warnings = result.warnings
            
            // Clear any previous errors
            errorMessage = nil
            
            // Generate report text
            regenerateReport()
            
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
    
    /// Regenerates the report text
    func regenerateReport() {
        reportText = reportEngine.generateDetailedReport(for: session)
    }
    
    // MARK: - Report Formats
    
    /// Gets text report
    func getTextReport() -> String {
        reportEngine.generateTextReport(for: session)
    }
    
    /// Gets detailed report
    func getDetailedReport() -> String {
        reportEngine.generateDetailedReport(for: session)
    }
    
    /// Gets shareable summary
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
        
        do {
            try await supabaseService.saveSession(session)
            isSaved = true
            successMessage = "Session saved successfully!"
            
        } catch let error as DatabaseError {
            ErrorHandler.shared.log(error, context: "ReportViewModel.saveSession")
            errorMessage = error.userMessage
            
        } catch {
            ErrorHandler.shared.log(error, context: "ReportViewModel.saveSession")
            errorMessage = "Failed to save session"
        }
        
        isSaving = false
    }
    
    // MARK: - Sharing
    
    /// Prepares data for sharing
    func shareReport() {
        reportText = getShareableSummary()
        showShareSheet = true
    }
    
    /// Gets items for activity view controller
    func getShareItems() -> [Any] {
        [getShareableSummary()]
    }
    
    // MARK: - Export
    
    /// Exports as CSV
    func exportAsCSV() -> String {        return reportEngine.generateCSV(for: session)
    }
    
    /// Exports as JSON
    func exportAsJSON() -> String? {
        do {
            let data = try reportEngine.generateJSON(for: session)
            return String(data: data, encoding: .utf8)
        } catch {
            ErrorHandler.shared.log(error, context: "ReportViewModel.exportAsJSON")
            return nil
        }
    }
    
    /// Gets total owed by a participant
    func totalOwed(by participant: String) -> String {
        let amount = session.totalOwed(by: participant)
        return CurrencyFormatter.shared.format(amount)
    }
    
    /// Gets splits for a specific participant
    func splitsFor(participant: String) -> [SplitLog] {
        session.splits(for: participant)
    }
}

// MARK: - Report Types

extension ReportViewModel {
    enum ReportType {
        case text
        case detailed
        case shareable
        case csv
        case json
        
        var title: String {
            switch self {
            case .text: return "Simple Report"
            case .detailed: return "Detailed Report"
            case .shareable: return "Share Summary"
            case .csv: return "CSV Export"
            case .json: return "JSON Export"
            }
        }
    }
    
    /// Gets report for a specific type
    func getReport(type: ReportType) -> String {
        switch type {
        case .text:
            return getTextReport()
        case .detailed:
            return getDetailedReport()
        case .shareable:
            return getShareableSummary()
        case .csv:
            return exportAsCSV()
        case .json:
            return exportAsJSON() ?? "{}"
        }
    }
}

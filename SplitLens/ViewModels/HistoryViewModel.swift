//
//  HistoryViewModel.swift
//  SplitLens
//
//  ViewModel for viewing and managing session history
//

import Foundation
import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// List of all sessions
    @Published var sessions: [ReceiptSession] = []
    
    /// Filtered/searched sessions
    @Published var filteredSessions: [ReceiptSession] = []
    
    /// Search query
    @Published var searchQuery: String = "" {
        didSet {
            applyFilters()
        }
    }
    
    /// Loading state
    @Published var isLoading = false
    
    /// Error message
    @Published var errorMessage: String?
    
    /// Selected session for detail view
    @Published var selectedSession: ReceiptSession?
    
    // MARK: - Filter Options
    
    enum SortOption {
        case dateNewest
        case dateOldest
        case amountHighest
        case amountLowest
        
        var title: String {
            switch self {
            case .dateNewest: return "Newest First"
            case .dateOldest: return "Oldest First"
            case .amountHighest: return "Highest Amount"
            case .amountLowest: return "Lowest Amount"
            }
        }
    }
    
    @Published var sortOption: SortOption = .dateNewest {
        didSet {
            applyFilters()
        }
    }
    
    // MARK: - Dependencies
    
    private let sessionStore: SessionStoreProtocol
    private let receiptImageStore: ReceiptImageStoreProtocol
    
    // MARK: - Computed Properties
    
    /// Total number of sessions
    var totalSessions: Int {
        sessions.count
    }
    
    /// Whether there are any sessions
    var hasSessions: Bool {
        !sessions.isEmpty
    }
    
    /// Total amount across all sessions
    var totalAmount: Double {
        sessions.reduce(0.0) { $0 + $1.totalAmount }
    }
    
    /// Formatted total amount
    var formattedTotalAmount: String {
        CurrencyFormatter.shared.format(totalAmount)
    }
    
    // MARK: - Initialization
    
    init(
        sessionStore: SessionStoreProtocol = DependencyContainer.shared.sessionStore,
        receiptImageStore: ReceiptImageStoreProtocol = DependencyContainer.shared.receiptImageStore
    ) {
        self.sessionStore = sessionStore
        self.receiptImageStore = receiptImageStore
    }
    
    // MARK: - Data Loading
    
    /// Fetches all sessions from the database
    func loadSessions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedSessions = try await sessionStore.fetchAllSessions(limit: nil)
            sessions = fetchedSessions
            applyFilters()
            
        } catch let error as SessionStoreError {
            ErrorHandler.shared.log(error, context: "HistoryViewModel.loadSessions")
            errorMessage = error.localizedDescription
            
        } catch {
            ErrorHandler.shared.log(error, context: "HistoryViewModel.loadSessions")
            errorMessage = "Failed to load sessions"
        }
        
        isLoading = false
    }
    
    /// Fetches recent sessions (limited count)
    func loadRecentSessions(count: Int = 20) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedSessions = try await sessionStore.fetchRecentSessions(count: count)
            sessions = fetchedSessions
            applyFilters()
            
        } catch let error as SessionStoreError {
            ErrorHandler.shared.log(error, context: "HistoryViewModel.loadRecentSessions")
            errorMessage = error.localizedDescription
            
        } catch {
            ErrorHandler.shared.log(error, context: "HistoryViewModel.loadRecentSessions")
            errorMessage = "Failed to load sessions"
        }
        
        isLoading = false
    }
    
    /// Refreshes the session list
    func refresh() async {
        await loadSessions()
    }
    
    // MARK: - Session Management
    
    /// Deletes a session
    func deleteSession(_ session: ReceiptSession) async {
        errorMessage = nil

        do {
            let sessionSnapshot = session
            try await sessionStore.deleteSession(id: session.id)

            do {
                try receiptImageStore.deleteImages(for: session.id)
            } catch {
                ErrorHandler.shared.log(error, context: "HistoryViewModel.deleteSession.imageStore")

                do {
                    try await sessionStore.saveSession(sessionSnapshot)
                    errorMessage = "Could not delete receipt images. Session was restored to keep history consistent."
                } catch {
                    ErrorHandler.shared.log(error, context: "HistoryViewModel.deleteSession.rollback")
                    errorMessage = "Critical delete failure. Session could not be safely rolled back."
                }
                return
            }

            sessions.removeAll { $0.id == session.id }
            applyFilters()
            
        } catch let error as SessionStoreError {
            ErrorHandler.shared.log(error, context: "HistoryViewModel.deleteSession")
            errorMessage = error.localizedDescription
            
        } catch {
            ErrorHandler.shared.log(error, context: "HistoryViewModel.deleteSession")
            errorMessage = "Failed to delete session"
        }
    }
    
    /// Deletes sessions at specified indices
    func deleteSessions(at offsets: IndexSet) async {
        let sessionsToDelete = offsets.map { filteredSessions[$0] }
        
        for session in sessionsToDelete {
            await deleteSession(session)
        }
    }
    
    // MARK: - Search & Filter
    
    /// Applies current filters and search to the sessions list
    func applyFilters() {
        var result = sessions
        
        // Apply search
        if !searchQuery.isEmpty {
            result = result.filter { session in
                // Search in participants
                let participantsMatch = session.participants.contains { participant in
                    participant.localizedCaseInsensitiveContains(searchQuery)
                }
                
                // Search in items
                let itemsMatch = session.items.contains { item in
                    item.name.localizedCaseInsensitiveContains(searchQuery)
                }
                
                // Search in amount
                let amountMatch = session.formattedTotal.contains(searchQuery)
                
                return participantsMatch || itemsMatch || amountMatch
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateNewest:
            result.sort { $0.receiptDate > $1.receiptDate }
        case .dateOldest:
            result.sort { $0.receiptDate < $1.receiptDate }
        case .amountHighest:
            result.sort { $0.totalAmount > $1.totalAmount }
        case .amountLowest:
            result.sort { $0.totalAmount < $1.totalAmount }
        }
        
        filteredSessions = result
    }
    
    /// Clears search and filters
    func clearFilters() {
        searchQuery = ""
        sortOption = .dateNewest
    }
    
    // MARK: - Selection
    
    /// Selects a session for viewing details
    func selectSession(_ session: ReceiptSession) {
        selectedSession = session
    }
    
    /// Clears selection
    func clearSelection() {
        selectedSession = nil
    }
    
    // MARK: - Statistics
    
    /// Gets sessions for a specific date range
    func sessions(in dateRange: ClosedRange<Date>) -> [ReceiptSession] {
        sessions.filter { dateRange.contains($0.receiptDate) }
    }
    
    /// Gets total spent in a date range
    func totalSpent(in dateRange: ClosedRange<Date>) -> Double {
        sessions(in: dateRange).reduce(0.0) { $0 + $1.totalAmount }
    }
    
}

// MARK: - Sample Data

extension HistoryViewModel {
    /// Creates a view model with sample data for previews
   static func sample() -> HistoryViewModel {
        let vm = HistoryViewModel(
            sessionStore: InMemorySessionStore(sampleSessions: ReceiptSession.samples),
            receiptImageStore: LocalReceiptImageStore()
        )
        Task {
            await vm.loadSessions()
        }
        return vm
    }
}

//
//  HistoryView.swift
//  SplitLens
//
//  Session history list with liquid glass design
//

import SwiftUI

/// Screen for viewing session history
struct HistoryView: View {
    // MARK: - Navigation
    
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = HistoryViewModel()
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                LoadingOverlay(message: "Loading history...")
            } else if !viewModel.hasSessions {
                emptyStateView
            } else {
                sessionsList
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchQuery, prompt: "Search sessions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach([
                        HistoryViewModel.SortOption.dateNewest,
                        .dateOldest,
                        .amountHighest,
                        .amountLowest
                    ], id: \.self) { option in
                        Button(action: {
                            viewModel.sortOption = option
                        }) {
                            HStack {
                                Text(option.title)
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: 18))
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadSessions()
        }
    }
    
    // MARK: - Sections
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "folder.fill",
            message: "No past receipts found.\nStart your first scan!",
            actionLabel: "New Scan"
        ) {
            dismiss()
        }
    }
    
    private var sessionsList: some View {
        List {
            Section {
                ForEach(viewModel.filteredSessions) { session in
                    Button(action: {
                        navigationPath.append(Route.sessionDetail(session))
                    }) {
                        HistoryRow(session: session)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
                .onDelete { indexSet in
                    Task {
                        await viewModel.deleteSessions(at: indexSet)
                    }
                }
            } header: {
                HStack {
                    Text("\(viewModel.filteredSessions.count) Sessions")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Spacer()
                    
                    Text("Total: \(viewModel.formattedTotalAmount)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.green)
                }
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let session: ReceiptSession
    
    var body: some View {
        HStack(spacing: 14) {
            // Date badge
            VStack(spacing: 2) {
                Text(dateComponents.day)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(dateComponents.month)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 50, height: 50)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Session info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.paidBy)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("paid")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(session.formattedTotal)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
                
                HStack(spacing: 12) {
                    Label("\(session.participantCount) people", systemImage: "person.2.fill")
                    Label("\(session.itemCount) items", systemImage: "list.bullet")
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var dateComponents: (day: String, month: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        let day = formatter.string(from: session.createdAt)
        
        formatter.dateFormat = "MMM"
        let month = formatter.string(from: session.createdAt)
        
        return (day, month)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HistoryView(navigationPath: .constant(NavigationPath()))
    }
}

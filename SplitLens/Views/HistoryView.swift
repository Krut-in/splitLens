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
        .alert(
            "History Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unexpected error occurred.")
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
                    Task { await viewModel.deleteSessions(at: indexSet) }
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

    @State private var thumbnail: UIImage? = nil

    private let receiptImageStore = DependencyContainer.shared.receiptImageStore

    var body: some View {
        HStack(spacing: 14) {
            // Left: thumbnail (lazy-loaded) or date badge fallback
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
            } else {
                dateBadge
            }

            // Right: session info
            VStack(alignment: .leading, spacing: 5) {
                // Payer + amount
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

                // Date · People · Items
                HStack(spacing: 12) {
                    Label(session.formattedHistoryDate, systemImage: "calendar")
                    Label("\(session.participantCount) people", systemImage: "person.2.fill")
                    Label("\(session.itemCount) items", systemImage: "list.bullet")
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)

                // Per-person quick-glance (if breakdown data available)
                if !session.personBreakdowns.isEmpty {
                    Text(summaryLine)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .task(id: session.id) {
            await loadThumbnail()
        }
    }

    // MARK: - Date Badge (fallback when no image)

    private var dateBadge: some View {
        VStack(spacing: 2) {
            Text(dateComponents.day)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(dateComponents.month)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: 50, height: 60)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnail() async {
        guard let firstPath = session.receiptImagePaths.first else { return }
        guard let fullImage = receiptImageStore.loadImage(atPath: firstPath) else { return }
        let targetSize = CGSize(width: 100, height: 120) // 2× display size for sharpness
        thumbnail = await fullImage.byPreparingThumbnail(ofSize: targetSize) ?? fullImage
    }

    // MARK: - Helpers

    private var summaryLine: String {
        let sorted = session.personBreakdowns.sorted { $0.person < $1.person }
        let showing = Array(sorted.prefix(3))
        let more = sorted.count - showing.count
        var parts = showing.map { "\($0.person): \(CurrencyFormatter.shared.format($0.totalAmount))" }
        if more > 0 { parts.append("+\(more) more") }
        return parts.joined(separator: " · ")
    }

    private var dateComponents: (day: String, month: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        let day = formatter.string(from: session.receiptDate)
        formatter.dateFormat = "MMM"
        let month = formatter.string(from: session.receiptDate)
        return (day, month)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HistoryView(navigationPath: .constant(NavigationPath()))
    }
}

//
//  FinalReportView.swift
//  SplitLens
//
//  Final bill split report with export options and liquid glass design
//

import SwiftUI

/// Screen for displaying final bill split report
struct FinalReportView: View {
    // MARK: - Navigation
    
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel: ReportViewModel
    
    // MARK: - State
    
    @State private var showShareSheet = false
    @State private var shareText = ""
    
    // MARK: - Initialization
    
    init(session: ReceiptSession, navigationPath: Binding<NavigationPath>) {
        _viewModel = StateObject(wrappedValue: ReportViewModel(session: session))
        _navigationPath = navigationPath
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.green.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Success icon
                    successBanner
                    
                    // Summary cards
                    summarySection
                    
                    // Warnings (if any)
                    warningsSection
                    
                    // Settlement list
                    settlementSection
                    
                    // Action buttons
                    actionsSection
                    
                    Spacer (minLength: 20)
                }
                .padding()
            }
        }
        .navigationTitle("Split Report")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
    }
    
    // MARK: - Sections
    
    private var successBanner: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.2),
                                Color.green.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
            }
            
            Text("Split Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Here's who owes what")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
    
    private var summarySection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            SummaryCard(
                title: "Total",
                value: viewModel.session.formattedTotal,
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            SummaryCard(
                title: "People",
                value: "\(viewModel.session.participantCount)",
                icon: "person.3.fill",
                color: .blue
            )
            
            SummaryCard(
                title: "Items",
                value: "\(viewModel.session.itemCount)",
                icon: "list.bullet",
                color: .orange
            )
            
            SummaryCard(
                title: "Paid By",
                value: viewModel.session.paidBy,
                icon: "creditcard.fill",
                color: .purple
            )
        }
    }
    
    @ViewBuilder
    private var warningsSection: some View {
        if !viewModel.warnings.isEmpty {
            VStack(spacing: 10) {
                ForEach(viewModel.warnings, id: \.message) { warning in
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        
                        Text(warning.message)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var settlementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settlements")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            
            if viewModel.formattedSplits.isEmpty {
                Text("Everyone paid their fair share!")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.formattedSplits) { split in
                        SplitLogRow(log: split) {
                            // Show detail modal
                        }
                    }
                }
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 14) {
            // Save button
            ActionButton(
                icon: "square.and.arrow.down.fill",
                title: viewModel.isSaved ? "Saved!" : "Save to History",
                color: viewModel.isSaved ? .green : .blue
            ) {
                Task {
                    await viewModel.saveSession()
                }
            }
            .disabled(viewModel.isSaved || viewModel.isSaving)
            
            // Share button
            ActionButton(
                icon: "square.and.arrow.up.fill",
                title: "Share Report",
                color: .purple
            ) {
                shareText =viewModel.getShareableSummary()
                showShareSheet = true
            }
            
            // Done button
            Button(action: {
                // Return to home
                navigationPath.removeLast(navigationPath.count)
            }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FinalReportView(
            session: ReceiptSession.sample,
            navigationPath: .constant(NavigationPath())
        )
    }
}

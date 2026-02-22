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
    @State private var selectedSplit: SplitLog?
    @State private var showExportMenu = false
    @State private var selectedChartTab = 0
    @State private var shareItems: [Any] = []
    
    // MARK: - Initialization
    
    init(session: ReceiptSession, scanMetadata: ScanMetadata, navigationPath: Binding<NavigationPath>) {
        _viewModel = StateObject(wrappedValue: ReportViewModel(session: session, scanMetadata: scanMetadata))
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
                    
                    // Per-person breakdown
                    perPersonBreakdownSection
                    
                    // Charts section
                    chartsSection
                    
                    // Settlement list
                    settlementSection
                    
                    // Action buttons
                    actionsSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .navigationTitle("Split Report")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(item: $selectedSplit) { split in
            SettlementDetailModal(split: split, session: viewModel.session)
        }
        .confirmationDialog("Export Format", isPresented: $showExportMenu) {
            ForEach(ReportViewModel.ExportFormat.allCases) { format in
                Button(action: {
                    handleExport(format: format)
                }) {
                    Label(format.rawValue, systemImage: format.icon)
                }
            }
        }
        .successToast(message: viewModel.toastMessage, isShowing: $viewModel.showSuccessToast)
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
    
    private var perPersonBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Person Breakdown")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            if !viewModel.session.personBreakdowns.isEmpty {
                VStack(spacing: 10) {
                    ForEach(viewModel.session.personBreakdowns.sorted {
                        if $0.person == viewModel.session.paidBy { return true }
                        if $1.person == viewModel.session.paidBy { return false }
                        return $0.person < $1.person
                    }) { breakdown in
                        ReportPersonBreakdownRow(
                            breakdown: breakdown,
                            paidBy: viewModel.session.paidBy
                        )
                    }
                }
            } else {
                // Fallback: simple rows using totalOwed (legacy / no breakdown data yet)
                VStack(spacing: 12) {
                    ForEach(viewModel.session.participants.sorted(), id: \.self) { person in
                        legacyPersonBreakdownRow(person)
                    }
                }
            }
        }
    }

    private func legacyPersonBreakdownRow(_ person: String) -> some View {
        let total = viewModel.session.totalOwed(by: person)
        let balance = viewModel.getBalances()[person] ?? 0

        return HStack(spacing: 12) {
            Circle()
                .fill(balance >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(person.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(balance >= 0 ? .green : .red)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(person)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(person == viewModel.session.paidBy ? "Paid the bill" : "Participant")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.shared.format(total))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if balance != 0 {
                    Text(balance > 0 ? "Owed \(CurrencyFormatter.shared.format(balance))" : "Owes \(CurrencyFormatter.shared.format(abs(balance)))")
                        .font(.system(size: 12))
                        .foregroundStyle(balance > 0 ? .green : .red)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visualizations")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            
            Picker("Chart Type", selection: $selectedChartTab) {
                Text("Spending").tag(0)
                Text("Balance").tag(1)
                Text("Owe/Lent").tag(2)
            }
            .pickerStyle(.segmented)
            
            TabView(selection: $selectedChartTab) {
                SpendingPieChart(personTotals: viewModel.getPersonTotals())
                    .tag(0)
                
                BalanceChart(balances: viewModel.getBalances())
                    .tag(1)
                
                OweLentChart(oweLentData: viewModel.getOweLentData())
                    .tag(2)
            }
            .frame(height: 400)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: selectedChartTab)
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
                            selectedSplit = split
                        }
                    }
                }
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 14) {
            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Save button
            ActionButton(
                icon: "square.and.arrow.down.fill",
                title: viewModel.isSaved ? "Saved!" : "Save to History",
                color: viewModel.isSaved ? .green : .blue,
                isLoading: viewModel.isSaving,
                isDisabled: viewModel.isSaved || viewModel.isSaving
            ) {
                Task {
                    await viewModel.saveSession()
                }
            }
            
            // Export button
            ActionButton(
                icon: "square.and.arrow.up.fill",
                title: "Export Report",
                color: .purple,
                isLoading: viewModel.isGeneratingPDF
            ) {
                showExportMenu = true
            }
            
            // Done button
            Button(action: {
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
    
    // MARK: - Export Handling
    
    private func handleExport(format: ReportViewModel.ExportFormat) {
        Task {
            switch format {
            case .pdf:
                if let pdfData = await viewModel.exportAsPDF() {
                    // Save to temp file for sharing
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("SplitLens_Report.pdf")
                    try? pdfData.write(to: tempURL)
                    shareItems = [tempURL]
                    showShareSheet = true
                }
                
            case .csv:
                shareText = viewModel.exportAsCSV()
                shareItems = [shareText]
                showShareSheet = true
                
            case .text:
                shareText = viewModel.getShareableSummary()
                shareItems = [shareText]
                showShareSheet = true
                
            case .json:
                if let jsonText = viewModel.exportAsJSON() {
                    shareItems = [jsonText]
                    showShareSheet = true
                }
            }
        }
    }
}

// MARK: - ReportPersonBreakdownRow

/// Expandable per-person breakdown row used in FinalReportView.
private struct ReportPersonBreakdownRow: View {
    let breakdown: PersonBreakdown
    let paidBy: String

    @State private var isExpanded = false

    private var isPayer: Bool { breakdown.person == paidBy }

    private var avatarColor: Color {
        let hash = abs(breakdown.person.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(avatarColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(breakdown.person.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(avatarColor)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(breakdown.person)
                        .font(.system(size: 16, weight: .semibold))
                    Text(isPayer ? "Paid the bill" : "Participant")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isPayer ? .green : .secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormatter.shared.format(breakdown.totalAmount))
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    if !breakdown.itemCharges.isEmpty || !breakdown.feeCharges.isEmpty {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                if !breakdown.itemCharges.isEmpty || !breakdown.feeCharges.isEmpty {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            }

            if isExpanded {
                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(breakdown.itemCharges) { charge in
                        HStack {
                            Text(charge.itemName)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            Spacer()
                            if charge.splitAmong > 1 {
                                Text("÷\(charge.splitAmong)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Text(CurrencyFormatter.shared.format(charge.amount))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                    }

                    if !breakdown.feeCharges.isEmpty {
                        Divider().padding(.horizontal, 16).padding(.vertical, 2)
                        ForEach(breakdown.feeCharges) { charge in
                            HStack {
                                Text(charge.feeName)
                                    .font(.system(size: 13))
                                Text("(\(charge.strategy.displayName))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(CurrencyFormatter.shared.format(charge.amount))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.purple)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FinalReportView(
            session: ReceiptSession.sample,
            scanMetadata: .empty,
            navigationPath: .constant(NavigationPath())
        )
    }
}

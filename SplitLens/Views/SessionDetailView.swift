//
//  SessionDetailView.swift
//  SplitLens
//
//  Read-only session detail view with per-person expandable breakdowns.
//

import SwiftUI

// MARK: - SessionDetailView

struct SessionDetailView: View {

    // MARK: - Properties

    let session: ReceiptSession

    // MARK: - State

    @State private var showShareSheet = false
    @State private var shareText = ""
    @State private var displayBreakdowns: [PersonBreakdown] = []
    @State private var showRecomputedBanner = false
    @State private var fullScreenImages: [UIImage] = []
    @State private var fullScreenInitialIndex = 0
    @State private var showFullScreen = false

    @Environment(\.dismiss) private var dismiss
    private let receiptImageStore = DependencyContainer.shared.receiptImageStore

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.blue.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Section A: Receipt Photos
                    if !session.receiptImagePaths.isEmpty {
                        receiptImagesSection
                    }

                    // Recomputed banner (legacy sessions)
                    if showRecomputedBanner {
                        recomputedBanner
                    }

                    // Section B: Per-Person Breakdown Cards
                    if !displayBreakdowns.isEmpty {
                        perPersonSection
                    }

                    // Section C: Summary + Settlements
                    summarySection
                    metadataSection

                    if !session.computedSplits.isEmpty {
                        splitsSection
                    }

                    // Items list
                    itemsSection

                    // Total accounted footer
                    if !displayBreakdowns.isEmpty {
                        totalAccountedFooter
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    let reportEngine = DependencyContainer.shared.reportEngine
                    shareText = reportEngine.generateShareableSummary(for: session)
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenImageViewer(images: fullScreenImages, initialIndex: fullScreenInitialIndex)
        }
        .task {
            await loadBreakdowns()
        }
    }

    // MARK: - Breakdown Loading

    private func loadBreakdowns() async {
        if session.personBreakdowns.isEmpty && !session.items.isEmpty && !session.participants.isEmpty {
            let engine = AdvancedBillSplitEngine()
            if let result = try? engine.computeSplits(session: session) {
                displayBreakdowns = result.personBreakdowns
                showRecomputedBanner = !result.personBreakdowns.isEmpty
            }
        } else {
            displayBreakdowns = session.personBreakdowns
        }
    }

    // MARK: - Section A: Receipt Images

    private var receiptImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Receipt Images")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Text("\(session.receiptImagePaths.count) page\(session.receiptImagePaths.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(session.receiptImagePaths.enumerated()), id: \.offset) { index, path in
                        receiptImageCard(path: path, index: index)
                    }
                }
                .padding(.vertical, 2)
            }

            if missingImageCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(missingImageCount) image(s) unavailable on this device.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func receiptImageCard(path: String, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = receiptImageStore.loadImage(atPath: path) {
                Button(action: {
                    // Load all available images for full-screen viewer
                    fullScreenImages = session.receiptImagePaths.compactMap {
                        receiptImageStore.loadImage(atPath: $0)
                    }
                    fullScreenInitialIndex = index
                    showFullScreen = true
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 160, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if session.receiptImagePaths.count > 1 {
                            Text("\(index + 1) of \(session.receiptImagePaths.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(8)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 160, height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                            Text("Unavailable")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            Text("Page \(index + 1)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Recomputed Banner

    private var recomputedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text("Breakdown reconstructed from saved items")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Section B: Per-Person Breakdown Cards

    private var perPersonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown by Person")
                .font(.system(size: 20, weight: .bold))

            VStack(spacing: 10) {
                ForEach(displayBreakdowns.sorted { a, b in
                    // Payer first, then alphabetical
                    if a.person == session.paidBy { return true }
                    if b.person == session.paidBy { return false }
                    return a.person < b.person
                }) { breakdown in
                    PersonBreakdownCard(
                        breakdown: breakdown,
                        paidBy: session.paidBy
                    )
                }
            }
        }
    }

    // MARK: - Total Accounted Footer

    private var totalAccountedFooter: some View {
        let total = displayBreakdowns.reduce(0) { $0 + $1.totalAmount }
        let diff = abs(total - session.totalAmount)

        return HStack {
            Image(systemName: diff <= 0.02 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(diff <= 0.02 ? .green : .orange)
            Text("Total accounted: \(CurrencyFormatter.shared.format(total))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Section C: Metadata

    private var metadataSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(session.formattedDate)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            if session.hasTotalDiscrepancy {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Total discrepancy: \(CurrencyFormatter.shared.format(abs(session.totalDiscrepancy)))")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var summarySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryCard(title: "Total", value: session.formattedTotal, icon: "dollarsign.circle.fill", color: .green)
            SummaryCard(title: "People", value: "\(session.participantCount)", icon: "person.3.fill", color: .blue)
            SummaryCard(title: "Items", value: "\(session.itemCount)", icon: "list.bullet", color: .orange)
            SummaryCard(title: "Paid By", value: session.paidBy, icon: "creditcard.fill", color: .purple)
        }
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.system(size: 20, weight: .bold))

            VStack(spacing: 10) {
                ForEach(session.items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 16, weight: .medium))
                                .lineLimit(2)

                            if item.quantity > 1 {
                                HStack(spacing: 4) {
                                    Text("Qty:")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text("\(item.quantity)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue.opacity(0.1)))
                            }

                            if !item.assignedTo.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(item.assignedTo, id: \.self) { person in
                                        Text(person)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.blue)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                        }

                        Spacer()

                        Text(CurrencyFormatter.shared.format(item.totalPrice))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Splits Section

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settlements")
                .font(.system(size: 20, weight: .bold))

            VStack(spacing: 12) {
                ForEach(session.computedSplits) { split in
                    SplitLogRow(log: split, onTap: nil)
                }
            }
        }
    }

    // MARK: - Helpers

    private var missingImageCount: Int {
        session.receiptImagePaths.reduce(0) { total, path in
            total + (receiptImageStore.loadImage(atPath: path) == nil ? 1 : 0)
        }
    }
}

// MARK: - PersonBreakdownCard

private struct PersonBreakdownCard: View {

    let breakdown: PersonBreakdown
    let paidBy: String

    @State private var isExpanded = false

    private var isPayer: Bool { breakdown.person == paidBy }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed header — always visible
            headerRow
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemBackground))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 12) {
            // Avatar circle
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

                Text(roleLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isPayer ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((isPayer ? Color.green : Color.secondary).opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.shared.format(breakdown.totalAmount))
                    .font(.system(size: 17, weight: .bold, design: .rounded))

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Items subsection
            if !breakdown.itemCharges.isEmpty {
                itemsSubsection
            } else {
                Text("No items")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            // Fees subsection
            if !breakdown.feeCharges.isEmpty {
                Divider().padding(.horizontal, 16)
                feesSubsection
            }

            Divider().padding(.horizontal, 16)

            // Total + settlement row
            settlementRow
                .padding(.bottom, 16)
        }
    }

    private var itemsSubsection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Items")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ForEach(breakdown.itemCharges) { charge in
                itemChargeRow(charge)
            }

            // Items subtotal
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Divider().frame(width: 80)
                    Text("Items subtotal: \(CurrencyFormatter.shared.format(breakdown.itemCharges.reduce(0) { $0 + $1.amount }))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func itemChargeRow(_ charge: ItemCharge) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(charge.itemName)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                if charge.splitAmong > 1 {
                    Text("\(CurrencyFormatter.shared.format(charge.itemFullPrice)) ÷ \(charge.splitAmong)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text(CurrencyFormatter.shared.format(charge.amount))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private var feesSubsection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "percent")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.purple)
                Text("Fees")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            ForEach(breakdown.feeCharges) { charge in
                feeChargeRow(charge)
            }

            // Fees subtotal
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Divider().frame(width: 80)
                    Text("Fees subtotal: \(CurrencyFormatter.shared.format(breakdown.feeCharges.reduce(0) { $0 + $1.amount }))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func feeChargeRow(_ charge: FeeCharge) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(charge.feeName)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                Text(charge.strategy.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Capsule())
            }

            Spacer()

            Text(CurrencyFormatter.shared.format(charge.amount))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.purple)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private var settlementRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(isPayer ? .green : .orange)
                Text("\(breakdown.person)'s total: \(CurrencyFormatter.shared.format(breakdown.totalAmount))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }

            settlementStatusText
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var settlementStatusText: some View {
        if isPayer && breakdown.settlementAmount < -0.005 {
            Label(
                "Paid the bill — is owed \(CurrencyFormatter.shared.format(abs(breakdown.settlementAmount))) from others",
                systemImage: "checkmark.seal.fill"
            )
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.green)
        } else if isPayer {
            Label(
                "Solo bill — no split needed.",
                systemImage: "checkmark.seal.fill"
            )
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.green)
        } else if breakdown.settlementAmount > 0.005 {
            Label(
                "Owes \(paidBy) \(CurrencyFormatter.shared.format(breakdown.settlementAmount))",
                systemImage: "arrow.right.circle.fill"
            )
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.orange)
        } else {
            Label("All settled!", systemImage: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.green)
        }
    }

    // MARK: - Helpers

    private var roleLabel: String {
        isPayer ? "Paid the bill" : "Participant"
    }

    private var avatarColor: Color {
        let hash = abs(breakdown.person.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionDetailView(session: ReceiptSession.sample)
    }
}

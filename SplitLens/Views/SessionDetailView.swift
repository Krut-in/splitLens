//
//  SessionDetailView.swift
//  SplitLens
//
//  Read-only session detail view with liquid glass design
//

import SwiftUI

/// Screen for viewing saved session details
struct SessionDetailView: View {
    // MARK: - Properties
    
    let session: ReceiptSession
    
    // MARK: - State
    
    @State private var showShareSheet = false
    @State private var shareText = ""
    @Environment(\.dismiss) private var dismiss
    private let receiptImageStore = DependencyContainer.shared.receiptImageStore
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Session metadata
                    metadataSection
                    
                    // Summary cards
                    summarySection

                    // Receipt images (if available)
                    if !session.receiptImagePaths.isEmpty {
                        receiptImagesSection
                    }
                    
                    // Items list
                    itemsSection
                    
                    // Splits
                    if !session.computedSplits.isEmpty {
                        splitsSection
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
    }
    
    // MARK: - Sections
    
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
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            SummaryCard(
                title: "Total",
                value: session.formattedTotal,
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            SummaryCard(
                title: "People",
                value: "\(session.participantCount)",
                icon: "person.3.fill",
                color: .blue
            )
            
            SummaryCard(
                title: "Items",
                value: "\(session.itemCount)",
                icon: "list.bullet",
                color: .orange
            )
            
            SummaryCard(
                title: "Paid By",
                value: session.paidBy,
                icon: "creditcard.fill",
                color: .purple
            )
        }
    }

    private var receiptImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Receipt Images")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(session.receiptImagePaths.count) page(s)")
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
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 160, height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                            Text("Missing")
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
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            
            VStack(spacing: 10) {
                ForEach(session.items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                            
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
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.blue.opacity(0.1))
                                )
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
    
    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settlements")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            
            VStack(spacing: 12) {
                ForEach(session.computedSplits) { split in
                    SplitLogRow(log: split, onTap: nil)
                }
            }
        }
    }

    private var missingImageCount: Int {
        session.receiptImagePaths.reduce(0) { total, path in
            total + (receiptImageStore.loadImage(atPath: path) == nil ? 1 : 0)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionDetailView(session: ReceiptSession.sample)
    }
}

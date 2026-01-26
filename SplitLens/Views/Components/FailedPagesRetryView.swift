//
//  FailedPagesRetryView.swift
//  SplitLens
//
//  Component for displaying and retrying failed page processing
//

import SwiftUI

/// View displaying failed pages with retry options
struct FailedPagesRetryView: View {
    // MARK: - Properties
    
    let failedPageIndices: [Int]
    let pageResults: [PageProcessingResult]
    let totalPages: Int
    let retryingPageIndex: Int?
    let onRetryPage: (Int) async -> Void
    let onRetryAll: () async -> Void
    
    // MARK: - State
    
    @State private var isRetryingAll = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection
            
            // Failed pages list
            failedPagesListSection
            
            // Retry all button
            if failedPageIndices.count > 1 {
                retryAllButton
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Some Pages Failed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("\(failedPageIndices.count) of \(totalPages) page(s) couldn't be processed")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var failedPagesListSection: some View {
        VStack(spacing: 8) {
            ForEach(failedPageIndices, id: \.self) { pageIndex in
                failedPageRow(pageIndex: pageIndex)
            }
        }
    }
    
    private func failedPageRow(pageIndex: Int) -> some View {
        HStack(spacing: 12) {
            // Page indicator
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Text("\(pageIndex + 1)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            
            // Error info
            VStack(alignment: .leading, spacing: 2) {
                Text("Page \(pageIndex + 1)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                
                if let result = pageResults.first(where: { $0.pageIndex == pageIndex }),
                   let error = result.error {
                    Text(error.userMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Retry button for this page
            Button {
                Task {
                    await onRetryPage(pageIndex)
                }
            } label: {
                if retryingPageIndex == pageIndex {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 70)
                } else {
                    Text("Retry")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.15))
                        )
                }
            }
            .disabled(retryingPageIndex != nil)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var retryAllButton: some View {
        Button {
            Task {
                isRetryingAll = true
                await onRetryAll()
                isRetryingAll = false
            }
        } label: {
            HStack(spacing: 8) {
                if isRetryingAll {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                
                Text("Retry All Failed Pages")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange)
            )
        }
        .disabled(retryingPageIndex != nil || isRetryingAll)
        .opacity((retryingPageIndex != nil || isRetryingAll) ? 0.7 : 1.0)
    }
}

// MARK: - Compact Version

/// Compact banner for showing failed pages with quick action
struct FailedPagesBanner: View {
    let failedCount: Int
    let totalCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                
                Text("\(failedCount) page(s) failed")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("Tap to retry")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Failed Pages View") {
    let sampleResults = [
        PageProcessingResult(
            pageIndex: 1,
            items: nil,
            fees: nil,
            total: nil,
            storeName: nil,
            error: .networkError(URLError(.timedOut))
        ),
        PageProcessingResult(
            pageIndex: 3,
            items: nil,
            fees: nil,
            total: nil,
            storeName: nil,
            error: .ocrServiceUnavailable
        )
    ]
    
    return VStack {
        FailedPagesRetryView(
            failedPageIndices: [1, 3],
            pageResults: sampleResults,
            totalPages: 4,
            retryingPageIndex: nil,
            onRetryPage: { _ in },
            onRetryAll: {}
        )
        .padding()
        
        FailedPagesBanner(
            failedCount: 2,
            totalCount: 4,
            onTap: {}
        )
        .padding()
    }
}

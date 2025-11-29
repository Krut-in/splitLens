//
//  SplitLogRow.swift
//  SplitLens
//
//  Row component for displaying split payment information with liquid glass design
//

import SwiftUI

/// A row component for displaying split payment details
struct SplitLogRow: View {
    // MARK: - Properties
    
    let log: SplitLog
    let onTap: (() -> Void)?
    
    // MARK: - Initialization
    
    init(log: SplitLog, onTap: (() -> Void)? = nil) {
        self.log = log
        self.onTap = onTap
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            if let onTap = onTap {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onTap()
            }
        }) {
            HStack(spacing: 16) {
                // From person avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(log.from.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    )
                
                // Payment details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(log.from)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        Text(log.to)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    
                    if !log.explanation.isEmpty {
                        Text(log.explanation)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Amount
                VStack(alignment: .trailing, spacing: 2) {
                    Text(log.formattedAmount)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    
                    if onTap != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.systemBackground).opacity(0.8),
                                    Color(.systemBackground).opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                }
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(log.from) owes \(log.to) \(log.formattedAmount)")
        .accessibilityHint(log.explanation.isEmpty ? "" : log.explanation)
    }
}

// MARK: - Preview

#Preview("Single Row") {
    SplitLogRow(log: SplitLog.sample) {
        print("Tapped")
    }
    .padding()
}

#Preview("List of Rows") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(SplitLog.samples) { log in
                SplitLogRow(log: log) {
                    print("Tapped \(log.from)")
                }
            }
        }
        .padding()
    }
}

#Preview("Without Tap Action") {
    VStack(spacing: 12) {
        ForEach(SplitLog.samples) { log in
            SplitLogRow(log: log, onTap: nil)
        }
    }
    .padding()
}

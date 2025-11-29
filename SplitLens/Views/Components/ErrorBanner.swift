//
//  ErrorBanner.swift
//  SplitLens
//
//  Error display banner with retry button and liquid glass design
//

import SwiftUI

/// An error banner with optional retry action
struct ErrorBanner: View {
    // MARK: - Properties
    
    let error: Error
    let retryAction: (() -> Void)?
    
    // MARK: - Computed Properties
    
    private var errorMessage: String {
        if let ocrError = error as? OCRError {
            return ocrError.userMessage
        } else if let dbError = error as? DatabaseError {
            return dbError.userMessage
        } else if let splitError = error as? BillSplitError {
            return splitError.localizedDescription
        } else {
            return error.localizedDescription
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 14) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.red)
            
            // Error message
            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Retry button
            if let retry = retryAction {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    retry()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        
                        Text("Retry")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.8),
                                Color.red.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.08),
                                Color.red.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            }
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.red.opacity(0.1), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(errorMessage)")
        .accessibilityHint(retryAction != nil ? "Double tap retry button to try again" : "")
    }
}

// MARK: - Preview

#Preview("With Retry") {
    VStack(spacing: 20) {
        ErrorBanner(
            error: OCRError.noTextDetected,
            retryAction: {
                print("Retrying...")
            }
        )
        
        ErrorBanner(
            error: OCRError.imageProcessingFailed,
            retryAction: {
                print("Retrying...")
            }
        )
    }
    .padding()
}

#Preview("Without Retry") {
    ErrorBanner(
        error: BillSplitError.noParticipants,
        retryAction: nil
    )
    .padding()
}

#Preview("Different Errors") {
    ScrollView {
        VStack(spacing: 16) {
            ErrorBanner(
                error: OCRError.noTextDetected,
                retryAction: {}
            )
            
            ErrorBanner(
                error: DatabaseError.saveFailed("Network connection lost"),
                retryAction: {}
            )
            
            ErrorBanner(
                error: BillSplitError.noParticipants,
                retryAction: nil
            )
            
            ErrorBanner(
                error: NSError(
                    domain: "TestError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "An unexpected error occurred. Please try again."]
                ),
                retryAction: {}
            )
        }
        .padding()
    }
}

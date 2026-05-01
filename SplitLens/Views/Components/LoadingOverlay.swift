//
//  LoadingOverlay.swift
//  SplitLens
//
//  Animated scan-progress card. Works as a full-screen overlay or an inline card.
//  Dark-mode adaptive. Material is rendered first so glassmorphism is visible.
//

import SwiftUI

/// Visual style for `LoadingOverlay`.
enum LoadingOverlayStyle {
    /// Full-screen scrim with a centered modal card. Used while a single
    /// receipt image is being processed.
    case fullScreen

    /// Inline card with no backdrop. Used inside scrolling content to show
    /// per-page progress during multi-image OCR.
    case inline
}

/// Animated loader specifically designed for the receipt-scanning flow.
/// Renders a stylized receipt with a moving scan line, the current
/// state label, and an optional determinate progress bar.
struct LoadingOverlay: View {
    // MARK: - Public API

    let message: String
    var subMessage: String? = nil
    var progress: Double? = nil
    var style: LoadingOverlayStyle = .fullScreen

    // MARK: - Convenience initializers

    init(message: String) {
        self.message = message
    }

    init(
        message: String,
        subMessage: String? = nil,
        progress: Double? = nil,
        style: LoadingOverlayStyle = .fullScreen
    ) {
        self.message = message
        self.subMessage = subMessage
        self.progress = progress
        self.style = style
    }

    // MARK: - Animation state

    @State private var scanOffset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        switch style {
        case .fullScreen:
            ZStack {
                Color.black.opacity(colorScheme == .dark ? 0.55 : 0.35)
                    .ignoresSafeArea()
                card
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)

        case .inline:
            card
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityDescription)
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 18) {
            scanArtwork

            VStack(spacing: 6) {
                Text(message)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                if let subMessage, !subMessage.isEmpty {
                    Text(subMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let progress {
                ProgressBar(progress: progress)
                    .frame(height: 6)
                    .padding(.horizontal, 4)
            }
        }
        .padding(28)
        .frame(minWidth: 240, maxWidth: 340)
        // Material BEFORE the gradient overlay so glassmorphism is actually visible.
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.teal.opacity(colorScheme == .dark ? 0.55 : 0.35),
                            Color.indigo.opacity(colorScheme == .dark ? 0.45 : 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.18),
            radius: 24,
            x: 0,
            y: 12
        )
    }

    // MARK: - Scan Artwork

    /// A stylized receipt with a horizontal scan line that loops top-to-bottom.
    private var scanArtwork: some View {
        let width: CGFloat = 96
        let height: CGFloat = 110

        return ZStack {
            // Brand gradient backdrop
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.teal, Color.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width + 28, height: height + 28)
                .opacity(0.18)

            // Receipt
            ReceiptShape()
                .fill(Color(.systemBackground))
                .frame(width: width, height: height)
                .overlay(
                    ReceiptShape()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .overlay(
                    receiptLines
                        .frame(width: width * 0.7, height: height * 0.55)
                        .offset(y: -8)
                )
                .overlay(
                    // Scan line — stays clipped to the receipt shape so it
                    // moves only across the visible receipt area.
                    GeometryReader { geo in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.teal.opacity(0),
                                        Color.teal.opacity(0.85),
                                        Color.indigo.opacity(0.85),
                                        Color.indigo.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width, height: 4)
                            .offset(y: scanOffset * geo.size.height)
                            .shadow(color: Color.teal.opacity(0.5), radius: 4)
                    }
                    .clipShape(ReceiptShape())
                )
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
            ) {
                scanOffset = 0.95
            }
        }
    }

    /// Three horizontal "line items" rendered inside the receipt.
    private var receiptLines: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach([0.85, 0.6, 0.78], id: \.self) { ratio in
                Capsule()
                    .fill(Color.primary.opacity(0.55))
                    .frame(height: 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: ratio, y: 1.0, anchor: .leading)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        if let progress {
            let percent = Int((progress * 100).rounded())
            return "\(message). \(percent) percent complete."
        }
        return message
    }
}

// MARK: - Receipt Shape

/// Rounded rectangle on top, zigzag torn edge on the bottom.
private struct ReceiptShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 6
        let teethCount = 8
        let toothDepth: CGFloat = 6
        let teethWidth = rect.width / CGFloat(teethCount)

        // Start at top-left below the corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))

        // Top-left corner
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            radius: cornerRadius
        )
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        // Top-right corner
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
            radius: cornerRadius
        )
        // Right edge to just above the zigzag
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - toothDepth))

        // Zigzag bottom (right to left)
        for i in (0..<teethCount).reversed() {
            let xMid = rect.minX + CGFloat(i) * teethWidth + teethWidth / 2
            let xLeft = rect.minX + CGFloat(i) * teethWidth
            path.addLine(to: CGPoint(x: xMid, y: rect.maxY))
            path.addLine(to: CGPoint(x: xLeft, y: rect.maxY - toothDepth))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Progress Bar

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.teal, Color.indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
    }
}

// MARK: - Previews

#Preview("Full-screen, light") {
    ZStack {
        VStack { Text("Background content"); Image(systemName: "photo") }
        LoadingOverlay(
            message: "Analyzing receipt…",
            subMessage: "1 of 3 pages",
            progress: 0.42,
            style: .fullScreen
        )
    }
}

#Preview("Full-screen, dark") {
    ZStack {
        VStack { Text("Background content"); Image(systemName: "photo") }
        LoadingOverlay(
            message: "Analyzing receipt…",
            subMessage: "1 of 3 pages",
            progress: 0.42,
            style: .fullScreen
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Inline card") {
    LoadingOverlay(
        message: "Extracting items…",
        subMessage: nil,
        progress: 0.78,
        style: .inline
    )
    .padding()
}

#Preview("Indeterminate") {
    LoadingOverlay(message: "Saving session…")
}

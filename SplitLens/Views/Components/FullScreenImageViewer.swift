//
//  FullScreenImageViewer.swift
//  SplitLens
//
//  Reusable full-screen image viewer with pinch-to-zoom, double-tap, and swipe-between-pages.
//

import SwiftUI

/// Presents a paginated, zoomable receipt image gallery.
/// Present via `.fullScreenCover` with `images` and `initialIndex`.
struct FullScreenImageViewer: View {

    // MARK: - Properties

    let images: [UIImage]
    let initialIndex: Int

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(images: [UIImage], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: max(0, min(initialIndex, images.count - 1)))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Paginated image carousel
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ZoomableImageView(image: image)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Overlay controls
            VStack {
                // Close button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.leading, 20)
                    .padding(.top, 60)

                    Spacer()
                }

                Spacer()

                // Page indicator
                if images.count > 1 {
                    Text("\(currentIndex + 1) of \(images.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 44)
                }
            }
        }
        .statusBarHidden(true)
    }
}

// MARK: - Zoomable Image

private struct ZoomableImageView: View {

    let image: UIImage

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnifyGesture)
            .simultaneousGesture(panGesture)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    if scale > 1.0 {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Gestures

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = lastScale * value
                scale = max(1.0, min(5.0, proposed))
            }
            .onEnded { value in
                lastScale = max(1.0, min(5.0, lastScale * value))
                scale = lastScale
                if scale <= 1.01 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1.0 else { return }
                lastOffset = offset
            }
    }
}

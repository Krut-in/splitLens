//
//  ImageUploadView.swift
//  SplitLens
//
//  Image capture and OCR processing screen with multi-image carousel support
//

import SwiftUI
import PhotosUI

/// Screen for image selection and OCR processing with multi-image support
struct ImageUploadView: View {
    // MARK: - Navigation
    
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = ImageUploadViewModel()
    
    // MARK: - State
    
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var showFailedPagesSheet = false
    @State private var showReorderSheet = false
    @State private var showCostWarning = false
    
    // MARK: - Constants
    
    private let maxImageCount = 10
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
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
                    // Image preview carousel or placeholder
                    if viewModel.hasImages {
                        imageCarouselSection
                    } else {
                        emptyImageSection
                    }
                    
                    // Action buttons (only show if no images OR processing failed)
                    if !viewModel.hasImages || viewModel.errorMessage != nil {
                        actionButtonsSection
                    } else if viewModel.imageCount < maxImageCount {
                        addMoreImagesSection
                    }
                    
                    // Failed pages retry banner
                    if viewModel.hasRetriablePages && !viewModel.isProcessing {
                        FailedPagesBanner(
                            failedCount: viewModel.failedPageIndices.count,
                            totalCount: viewModel.imageCount,
                            onTap: {
                                showFailedPagesSheet = true
                            }
                        )
                        .padding(.horizontal)
                    }
                    
                    // Error banner (for non-page-specific errors)
                    if let error = viewModel.errorMessage, !viewModel.hasRetriablePages {
                        ErrorBanner(
                            error: NSError(
                                domain: "OCRError",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: error]
                            ),
                            retryAction: {
                                Task {
                                    await viewModel.retryProcessing()
                                }
                            }
                        )
                        .padding(.horizontal)
                    }
                    
                    // Progress indicator for multi-image processing
                    if viewModel.isProcessing {
                        progressSection
                    }
                    
                    // Extracted items preview
                    if !viewModel.extractedItems.isEmpty {
                        extractedItemsSection
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            
            // Loading overlay (only show for single image)
            if viewModel.isProcessing && !viewModel.hasMultipleImages {
                LoadingOverlay(message: "Analyzing receipt...")
            }
        }
        .navigationTitle("Scan Receipt")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.canProceed {
                    Button("Next") {
                        HapticFeedback.shared.lightImpact()
                        // Show total confirmation if we have a detected total
                        if viewModel.detectedTotal != nil {
                            viewModel.requestTotalConfirmation()
                        } else {
                            navigationPath.append(
                                Route.itemsEditor(
                                    viewModel.extractedItems,
                                    viewModel.detectedFees,
                                    viewModel.buildScanMetadata()
                                )
                            )
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $cameraImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(image: $cameraImage, sourceType: .camera)
        }
        .sheet(isPresented: $viewModel.showTotalConfirmation) {
            TotalConfirmationSheet(
                enteredTotal: $viewModel.userEnteredTotal,
                isPresented: $viewModel.showTotalConfirmation,
                detectedTotal: viewModel.detectedTotal,
                calculatedItemsTotal: viewModel.calculatedItemsTotal,
                onConfirm: {
                    navigationPath.append(
                        Route.itemsEditor(
                            viewModel.extractedItems,
                            viewModel.detectedFees,
                            viewModel.buildScanMetadata()
                        )
                    )
                },
                onManualFix: {
                    navigationPath.append(
                        Route.itemsEditor(
                            viewModel.extractedItems,
                            viewModel.detectedFees,
                            viewModel.buildScanMetadata()
                        )
                    )
                }
            )
        }
        .sheet(isPresented: $showFailedPagesSheet) {
            NavigationStack {
                ScrollView {
                    FailedPagesRetryView(
                        failedPageIndices: viewModel.failedPageIndices,
                        pageResults: viewModel.pageResults,
                        totalPages: viewModel.imageCount,
                        retryingPageIndex: viewModel.retryingPageIndex,
                        onRetryPage: { index in
                            await viewModel.retryFailedPage(at: index)
                        },
                        onRetryAll: {
                            await viewModel.retryAllFailedPages()
                        }
                    )
                    .padding()
                }
                .navigationTitle("Failed Pages")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showFailedPagesSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showReorderSheet) {
            ImageReorderSheet(
                images: $viewModel.selectedImages,
                isPresented: $showReorderSheet,
                onReorderComplete: {
                    // Re-process if items were already extracted
                    if !viewModel.extractedItems.isEmpty {
                        Task {
                            await viewModel.processAllImages()
                        }
                    }
                }
            )
        }
        .alert("Processing Cost Warning", isPresented: $showCostWarning) {
            Button("Continue Anyway") {
                Task {
                    await viewModel.processAllImages()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Scanning \(viewModel.imageCount) images may take longer and use more resources. Consider using fewer images if possible.")
        }
        .onChange(of: cameraImage) { _, newImage in
            if let image = newImage {
                Task {
                    await viewModel.setImage(image)
                    cameraImage = nil
                }
            }
        }
        .onChange(of: viewModel.photoPickerItems) { _, _ in
            Task {
                await viewModel.handlePhotoPickerSelection()
            }
        }
    }
    
    // MARK: - Empty State Section
    
    private var emptyImageSection: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                icon: "photo.on.rectangle.angled",
                message: "No image selected.\nChoose photos or take one with your camera."
            )
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Image Carousel Section
    
    private var imageCarouselSection: some View {
        VStack(spacing: 12) {
            // Header with count and reorder hint
            HStack {
                Text("Receipt Images")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if viewModel.hasMultipleImages {
                    HStack(spacing: 8) {
                        Text(viewModel.currentImageDisplay)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        // Reorder button
                        Button {
                            HapticFeedback.shared.lightImpact()
                            showReorderSheet = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            
            // Image carousel using TabView
            if viewModel.hasMultipleImages {
                TabView(selection: $viewModel.currentImageIndex) {
                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                        imageCard(image: image, index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)
                .animation(.easeInOut, value: viewModel.currentImageIndex)
                
                // Custom page indicator
                pageIndicator
                
            } else if let image = viewModel.selectedImage {
                // Single image view
                imageCard(image: image, index: 0)
                    .frame(height: 320)
            }
            
            // Remove button
            Button(action: {
                viewModel.removeCurrentImage()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                    Text(viewModel.hasMultipleImages ? "Remove This Image" : "Remove Image")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
    
    /// Individual image card view
    private func imageCard(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                .padding(.horizontal)
            
            // Page badge for multi-image
            if viewModel.hasMultipleImages {
                Text("Page \(index + 1)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.trailing, 24)
                    .padding(.top, 8)
            }
        }
    }
    
    /// Page indicator dots
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.imageCount, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentImageIndex ? Color.blue : Color.gray.opacity(0.4))
                    .frame(width: index == viewModel.currentImageIndex ? 10 : 8,
                           height: index == viewModel.currentImageIndex ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentImageIndex)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 14) {
            // Camera button
            ActionButton(
                icon: "camera.fill",
                title: "Take Photo",
                color: .blue
            ) {
                showCamera = true
            }
            
            // Multi-photo library picker
            PhotosPicker(
                selection: $viewModel.photoPickerItems,
                maxSelectionCount: maxImageCount - viewModel.imageCount,
                matching: .images
            ) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Choose from Library")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.purple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    }
                )
                .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            
            // Hint text
            Text("You can select up to \(maxImageCount) images for multi-page receipts")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Add More Images Section
    
    private var addMoreImagesSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                // Add from camera
                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                        Text("Add Photo")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                
                // Add from library
                PhotosPicker(
                    selection: $viewModel.photoPickerItems,
                    maxSelectionCount: maxImageCount - viewModel.imageCount,
                    matching: .images
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 14))
                        Text("Add from Library")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            
            Text("\(viewModel.imageCount) of \(maxImageCount) images selected")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.progressTracker.state.progressPercentage, height: 12)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progressTracker.state.progressPercentage)
                }
            }
            .frame(height: 12)
            .padding(.horizontal)
            
            // Progress description
            Text(viewModel.progressTracker.state.description)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            
            // Time remaining
            if let timeRemaining = viewModel.progressTracker.formattedTimeRemaining() {
                Text(timeRemaining)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Extracted Items Section
    
    private var extractedItemsSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extracted Items")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 8) {
                        Text("\(viewModel.extractedItems.count) items found")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        
                        if viewModel.hasMultipleImages {
                            Text("• from \(viewModel.imageCount) pages")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
            }
            .padding(.horizontal)
            
            // Detected total display
            if let detectedTotal = viewModel.detectedTotal {
                HStack {
                    Text("Receipt Total")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(CurrencyFormatter.shared.format(detectedTotal))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
            }
            
            // Confidence indicator
            if let confidence = viewModel.ocrConfidence {
                HStack(spacing: 8) {
                    Image(systemName: confidence >= 0.7 ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(confidence >= 0.7 ? .green : .orange)
                    
                    Text("Confidence: \(Int(confidence * 100))%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    if confidence < 0.7 {
                        Text("• Please verify")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(confidence >= 0.7 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                )
                .padding(.horizontal)
            }
            
            // Items list preview
            VStack(spacing: 10) {
                ForEach(viewModel.extractedItems.prefix(5)) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(CurrencyFormatter.shared.format(item.totalPrice))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                if viewModel.extractedItems.count > 5 {
                    Text("+ \(viewModel.extractedItems.count - 5) more items")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            
            // Detected fees summary
            if !viewModel.detectedFees.isEmpty {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    
                    Text("Additional Fees Detected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    ForEach(viewModel.detectedFees, id: \.type) { fee in
                        HStack {
                            Text(fee.displayName)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text(CurrencyFormatter.shared.format(fee.amount))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ImageUploadView(navigationPath: .constant(NavigationPath()))
    }
    .withDependencies()
}

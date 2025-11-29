//
//  ImageUploadView.swift
//  SplitLens
//
//  Image capture and OCR processing screen with liquid glass design
//

import SwiftUI
import PhotosUI

/// Screen for image selection and OCR processing
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
                    // Image preview or placeholder
                    if let image = viewModel.selectedImage {
                        imagePreviewSection(image: image)
                    } else {
                        emptyImageSection
                    }
                    
                    // Action buttons (only show if no image OR processing failed)
                    if viewModel.selectedImage == nil || viewModel.errorMessage != nil {
                        actionButtonsSection
                    }
                    
                    // Error banner
                    if let error = viewModel.errorMessage {
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
                    
                    // Extracted items preview
                    if !viewModel.extractedItems.isEmpty {
                        extractedItemsSection
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            
            // Loading overlay
            if viewModel.isProcessing {
                LoadingOverlay(message: "Analyzing receipt...")
            }
        }
        .navigationTitle("Scan Receipt")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.canProceed {
                    Button("Next") {
                        navigationPath.append(Route.itemsEditor(viewModel.extractedItems))
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
        .onChange(of: cameraImage) { _, newImage in
            if let image = newImage {
                Task {
                    await viewModel.setImage(image)
                }
            }
        }
        .onChange(of: viewModel.photoPickerItem) { _, _ in
            Task {
                await viewModel.handlePhotoPickerSelection()
            }
        }
    }
    
    // MARK: - Sections
    
    private var emptyImageSection: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                icon: "photo.on.rectangle.angled",
                message: "No image selected.\nChoose a photo or take one with your camera."
            )
            .padding(.vertical, 40)
        }
    }
    
    private func imagePreviewSection(image: UIImage) -> some View {
        VStack(spacing: 12) {
            Text("Receipt Image")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.reset()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Remove Image")
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
            
            // Photo library button
            ActionButton(
                icon: "photo.on.rectangle",
                title: "Choose from Library",
                color: .purple
            ) {
                showImagePicker = true
            }
        }
        .padding(.horizontal)
    }
    
    private var extractedItemsSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extracted Items")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("\(viewModel.extractedItems.count) items found")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
            }
            .padding(.horizontal)
            
            VStack(spacing: 10) {
                ForEach(viewModel.extractedItems.prefix(5)) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                        
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

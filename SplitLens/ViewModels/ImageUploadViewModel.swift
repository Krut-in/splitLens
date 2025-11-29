//
//  ImageUploadViewModel.swift
//  SplitLens
//
//  ViewModel for image capture and OCR processing
//

import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class ImageUploadViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The selected/captured image
    @Published var selectedImage: UIImage?
    
    /// Extracted items from OCR
    @Published var extractedItems: [ReceiptItem] = []
    
    /// Loading state
    @Published var isProcessing = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Whether to show image picker
    @Published var showImagePicker = false
    
    /// Whether to show camera
    @Published var showCamera = false
    
    /// Photo picker selection
    @Published var photoPickerItem: PhotosPickerItem?
    
    // MARK: - Dependencies
    
    private let ocrService: OCRServiceProtocol
    
    // MARK: - Initialization
    
    init(ocrService: OCRServiceProtocol = DependencyContainer.shared.ocrService) {
        self.ocrService = ocrService
    }
    
    // MARK: - Image Selection
    
    /// Triggers photo library selection
    func selectImageFromLibrary() {
        showImagePicker = true
        errorMessage = nil
    }
    
    /// Triggers camera capture
    func captureImage() {
        showCamera = true
        errorMessage = nil
    }
    
    /// Handles photo picker selection
    func handlePhotoPickerSelection() async {
        guard let item = photoPickerItem else { return }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Failed to load image"
                return
            }
            
            selectedImage = image
            await processImage(image)
        } catch {
            ErrorHandler.shared.log(error, context: "ImageUploadViewModel.handlePhotoPickerSelection")
            errorMessage = "Failed to load image: \(error.localizedDescription)"
        }
    }
    
    /// Sets image from camera capture
    func setImage(_ image: UIImage) async {
        selectedImage = image
        await processImage(image)
    }
    
    // MARK: - OCR Processing
    
    /// Processes the image through OCR service
    func processImage(_ image: UIImage? = nil) async {
        guard let imageToProcess = image ?? selectedImage else {
            errorMessage = "No image selected"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        extractedItems = []
        
        do {
            let items = try await ocrService.extractReceiptData(from: imageToProcess)
            
            if items.isEmpty {
                errorMessage = "No items found in the image"
            } else {
                extractedItems = items
            }
            
        } catch let error as OCRError {
            ErrorHandler.shared.log(error, context: "ImageUploadViewModel.processImage")
            errorMessage = error.userMessage
            
        } catch {
            ErrorHandler.shared.log(error, context: "ImageUploadViewModel.processImage")
            errorMessage = "An unexpected error occurred"
        }
        
        isProcessing = false
    }
    
    /// Retries OCR processing
    func retryProcessing() async {
        await processImage()
    }
    
    // MARK: - Reset
    
    /// Clears all data and resets to initial state
    func reset() {
        selectedImage = nil
        extractedItems = []
        isProcessing = false
        errorMessage = nil
        photoPickerItem = nil
    }
    
    // MARK: - Validation
    
    /// Whether the current state is ready to proceed
    var canProceed: Bool {
        !extractedItems.isEmpty && !isProcessing
    }
}

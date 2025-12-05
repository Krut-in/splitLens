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
    
    /// OCR confidence score (0.0 to 1.0)
    @Published var ocrConfidence: Double?
    
    // MARK: - Dependencies
    
    private let ocrService: OCRServiceProtocol
    private let textParser: TextParserProtocol
    
    /// Current OCR processing task (for cancellation)
    private var ocrTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        ocrService: OCRServiceProtocol = DependencyContainer.shared.ocrService,
        textParser: TextParserProtocol = ReceiptTextParser()
    ) {
        self.ocrService = ocrService
        self.textParser = textParser
    }
    
    deinit {
        ocrTask?.cancel()
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
        // Cancel any ongoing OCR processing
        ocrTask?.cancel()
        
        guard let imageToProcess = image ?? selectedImage else {
            errorMessage = "No image selected"
            return
        }
        
        ocrTask = Task {
            isProcessing = true
            errorMessage = nil
            extractedItems = []
            
            do {
                // Check for cancellation before starting
                try Task.checkCancellation()
                
                // Try structured extraction first (Gemini Vision - more accurate)
                if let supabaseService = ocrService as? SupabaseOCRService {
                    let structuredData = try await supabaseService.processReceiptStructured(images: [imageToProcess])
                    
                    try Task.checkCancellation()
                    
                    // Convert structured data to ReceiptItems
                    let items = structuredData.toReceiptItems(includeFees: true)
                    
                    if items.isEmpty {
                        // If no structured items, try legacy text parsing as fallback
                        if let rawText = structuredData.rawText {
                            let parsedItems = try textParser.parseReceiptText(rawText)
                            let confidence = textParser.calculateConfidence(for: parsedItems)
                            ocrConfidence = confidence
                            extractedItems = parsedItems
                            
                            if confidence < 0.7 {
                                errorMessage = "Low confidence (\(Int(confidence * 100))%). Please verify extracted items."
                            }
                        } else {
                            errorMessage = "No items found in the image"
                        }
                    } else {
                        extractedItems = items
                        ocrConfidence = 0.95 // High confidence for structured extraction
                        
                        // Log success for debugging
                        print("✅ Extracted \(items.count) items via Gemini Vision")
                        if let storeName = structuredData.storeName {
                            print("   Store: \(storeName)")
                        }
                        if let total = structuredData.total {
                            print("   Total: $\(String(format: "%.2f", total))")
                        }
                    }
                    
                } else {
                    // Fallback: Legacy text extraction + parsing
                    let rawText = try await ocrService.processReceipt(images: [imageToProcess])
                    
                    try Task.checkCancellation()
                    
                    let items = try textParser.parseReceiptText(rawText)
                    let confidence = textParser.calculateConfidence(for: items)
                    ocrConfidence = confidence
                    
                    if items.isEmpty {
                        errorMessage = "No items found in the image"
                    } else {
                        extractedItems = items
                        
                        if confidence < 0.7 {
                            errorMessage = "Low confidence (\(Int(confidence * 100))%). Please verify extracted items."
                        }
                    }
                }
                
            } catch is CancellationError {
                // Silent cancellation - user likely selected a new image
                return
            } catch let error as OCRError {
                ErrorHandler.shared.log(error, context: "ImageUploadViewModel.processImage")
                errorMessage = error.userMessage
                ocrConfidence = 0.0
                
            } catch {
                ErrorHandler.shared.log(error, context: "ImageUploadViewModel.processImage")
                errorMessage = "An unexpected error occurred"
                ocrConfidence = 0.0
            }
            
            isProcessing = false
        }
        
        await ocrTask?.value
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
        ocrConfidence = nil
    }
    
    // MARK: - Validation
    
    /// Whether the current state is ready to proceed
    var canProceed: Bool {
        !extractedItems.isEmpty && !isProcessing
    }
}

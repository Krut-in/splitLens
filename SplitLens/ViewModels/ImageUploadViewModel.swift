//
//  ImageUploadViewModel.swift
//  SplitLens
//
//  ViewModel for image capture and OCR processing with multi-image support
//

import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class ImageUploadViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Array of selected/captured images for multi-page receipt support
    @Published var selectedImages: [UIImage] = []
    
    /// Current image index in the carousel
    @Published var currentImageIndex: Int = 0
    
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
    
    /// Photo picker selection (multi-select)
    @Published var photoPickerItems: [PhotosPickerItem] = []
    
    /// OCR confidence score (0.0 to 1.0)
    @Published var ocrConfidence: Double?
    
    /// Progress tracker for multi-image OCR processing
    @Published var progressTracker = OCRProgressTracker()
    
    /// Detected total from receipt
    @Published var detectedTotal: Double?
    
    /// Detected fees from receipt
    @Published var detectedFees: [Fee] = []
    
    // MARK: - Total Validation Properties
    
    /// User-entered total for verification
    @Published var userEnteredTotal: Double?
    
    /// Whether to show total confirmation sheet
    @Published var showTotalConfirmation: Bool = false
    
    // MARK: - Page Processing Results (Edge Cases)
    
    /// Results from processing each page
    @Published var pageResults: [PageProcessingResult] = []
    
    /// Indices of pages that failed processing
    @Published var failedPageIndices: [Int] = []
    
    /// Whether a specific page is being retried
    @Published var retryingPageIndex: Int?
    
    // MARK: - Computed Properties
    
    /// Total number of selected images
    var imageCount: Int { selectedImages.count }
    
    /// Whether multiple images are selected
    var hasMultipleImages: Bool { imageCount > 1 }
    
    /// Display string for current image position
    var currentImageDisplay: String { "Image \(currentImageIndex + 1) of \(imageCount)" }
    
    /// Currently displayed image (for backward compatibility)
    var selectedImage: UIImage? { selectedImages.first }
    
    /// Whether any images are selected
    var hasImages: Bool { !selectedImages.isEmpty }
    
    // MARK: - Total Validation Computed Properties
    
    /// Discrepancy between user-entered and detected total
    var totalDiscrepancy: Double? {
        guard let entered = userEnteredTotal, let detected = detectedTotal else { return nil }
        return abs(entered - detected)
    }
    
    /// Discrepancy as a percentage of the entered total
    var discrepancyPercentage: Double? {
        guard let entered = userEnteredTotal,
              let discrepancy = totalDiscrepancy,
              entered > 0 else { return nil }
        return (discrepancy / entered) * 100
    }
    
    /// Whether the discrepancy exceeds acceptable threshold (5%)
    var hasSignificantDiscrepancy: Bool {
        (discrepancyPercentage ?? 0) > 5.0
    }
    
    /// Calculated total from extracted items
    var calculatedItemsTotal: Double {
        extractedItems.reduce(0) { $0 + $1.totalPrice }
    }
    
    /// Calculated total including fees
    var calculatedTotalWithFees: Double {
        let feesTotal = detectedFees.reduce(0) { $0 + $1.amount }
        return calculatedItemsTotal + feesTotal
    }
    
    /// Whether there are failed pages that can be retried
    var hasRetriablePages: Bool {
        !failedPageIndices.isEmpty
    }
    
    /// Number of successfully processed pages
    var successfulPageCount: Int {
        pageResults.filter { $0.isSuccess }.count
    }
    
    /// Whether to show cost warning for many images (>5)
    var shouldShowCostWarning: Bool {
        selectedImages.count > 5
    }
    
    /// Cost warning threshold
    static let costWarningThreshold = 5
    
    // MARK: - Dependencies
    
    internal let ocrService: OCRServiceProtocol
    internal let textParser: TextParserProtocol
    
    /// Current OCR processing task (for cancellation)
    internal var ocrTask: Task<Void, Never>?
    
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
    
    /// Handles multi-image photo picker selection
    func handlePhotoPickerSelection() async {
        guard !photoPickerItems.isEmpty else { return }
        
        var loadedImages: [UIImage] = []
        
        for item in photoPickerItems {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    continue
                }
                loadedImages.append(image)
            } catch {
                ErrorHandler.shared.log(error, context: "ImageUploadViewModel.handlePhotoPickerSelection")
            }
        }
        
        guard !loadedImages.isEmpty else {
            errorMessage = "Failed to load images"
            return
        }
        
        // Append to existing images or replace
        selectedImages.append(contentsOf: loadedImages)
        currentImageIndex = selectedImages.count - loadedImages.count
        
        // Give haptic feedback
        HapticFeedback.shared.success()
        
        // Process all images
        await processAllImages()
    }
    
    /// Sets image from camera capture
    func setImage(_ image: UIImage) async {
        selectedImages.append(image)
        currentImageIndex = selectedImages.count - 1
        
        // Give haptic feedback
        HapticFeedback.shared.lightImpact()
        
        await processAllImages()
    }
    
    /// Removes image at specified index
    func removeImage(at index: Int) {
        guard index >= 0 && index < selectedImages.count else { return }
        
        selectedImages.remove(at: index)
        
        // Adjust current index if needed
        if selectedImages.isEmpty {
            currentImageIndex = 0
            extractedItems = []
            detectedTotal = nil
            detectedFees = []
        } else if currentImageIndex >= selectedImages.count {
            currentImageIndex = selectedImages.count - 1
        }
        
        HapticFeedback.shared.lightImpact()
    }
    
    /// Removes current image from selection
    func removeCurrentImage() {
        removeImage(at: currentImageIndex)
    }
    
    /// Moves an image from one index to another
    func moveImage(from source: IndexSet, to destination: Int) {
        selectedImages.move(fromOffsets: source, toOffset: destination)
        HapticFeedback.shared.selection()
    }
    
    /// Navigates to next image in carousel
    func nextImage() {
        guard currentImageIndex < selectedImages.count - 1 else { return }
        currentImageIndex += 1
        HapticFeedback.shared.selection()
    }
    
    /// Navigates to previous image in carousel
    func previousImage() {
        guard currentImageIndex > 0 else { return }
        currentImageIndex -= 1
        HapticFeedback.shared.selection()
    }
    
    // MARK: - Reset
    
    /// Clears all data and resets to initial state
    func reset() {
        selectedImages = []
        currentImageIndex = 0
        extractedItems = []
        isProcessing = false
        errorMessage = nil
        photoPickerItems = []
        ocrConfidence = nil
        detectedTotal = nil
        detectedFees = []
        progressTracker.reset()
        userEnteredTotal = nil
        showTotalConfirmation = false
        pageResults = []
        failedPageIndices = []
        retryingPageIndex = nil
    }
    
    // MARK: - Total Validation
    
    /// Confirms the total and dismisses the sheet
    func confirmTotal() {
        showTotalConfirmation = false
        HapticFeedback.shared.success()
    }
    
    /// Updates the user-entered total and validates
    func updateUserTotal(_ total: Double?) {
        userEnteredTotal = total
        
        if hasSignificantDiscrepancy {
            HapticFeedback.shared.warning()
        }
    }
    
    /// Shows the total confirmation sheet
    func requestTotalConfirmation() {
        showTotalConfirmation = true
        HapticFeedback.shared.lightImpact()
    }
    
    // MARK: - Validation
    
    /// Whether the current state is ready to proceed
    var canProceed: Bool {
        !extractedItems.isEmpty && !isProcessing
    }
}

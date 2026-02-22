//
//  ImageUploadViewModel+OCR.swift
//  SplitLens
//
//  OCR processing and page retry extension for ImageUploadViewModel
//

import Foundation
import UIKit

// MARK: - OCR Processing Extension

extension ImageUploadViewModel {
    
    /// Processes all selected images through OCR service sequentially
    func processAllImages() async {
        // Cancel any ongoing OCR processing
        ocrTask?.cancel()
        
        guard !selectedImages.isEmpty else {
            errorMessage = "No images selected"
            return
        }
        
        ocrTask = Task {
            isProcessing = true
            errorMessage = nil
            extractedItems = []
            pageResults = []
            failedPageIndices = []
            detectedReceiptDate = nil
            detectedReceiptDateHasTime = false
            progressTracker.start()
            
            // Provide haptic feedback for OCR start
            HapticFeedback.shared.ocrStarted()
            
            do {
                try Task.checkCancellation()
                
                // Use Supabase service for structured extraction with page tracking
                if let supabaseService = ocrService as? SupabaseOCRService {
                    await processImagesWithPageTracking(supabaseService: supabaseService)
                    
                } else {
                    // Fallback: Legacy text extraction for single image
                    try await processWithLegacyOCR()
                }
                
            } catch is CancellationError {
                progressTracker.updateState(.cancelled)
                return
            } catch let error as OCRError {
                ErrorHandler.shared.log(error, context: "ImageUploadViewModel.processAllImages")
                errorMessage = error.userMessage
                ocrConfidence = 0.0
                progressTracker.updateState(.failed(error.userMessage))
                HapticFeedback.shared.ocrFailed()
                
            } catch {
                ErrorHandler.shared.log(error, context: "ImageUploadViewModel.processAllImages")
                errorMessage = "An unexpected error occurred"
                ocrConfidence = 0.0
                progressTracker.updateState(.failed(error.localizedDescription))
                HapticFeedback.shared.ocrFailed()
            }
            
            isProcessing = false
        }
        
        await ocrTask?.value
    }
    
    /// Legacy OCR processing for non-Supabase services
    private func processWithLegacyOCR() async throws {
        guard let firstImage = selectedImages.first else {
            throw OCRError.invalidImage
        }
        
        progressTracker.updateState(.analyzing(imageIndex: 0, total: 1))
        
        let rawText = try await ocrService.processReceipt(images: [firstImage])
        
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
        
        progressTracker.updateState(.completed(items))
        HapticFeedback.shared.ocrCompleted()
    }
    
    /// Processes images with individual page tracking for partial failure handling
    func processImagesWithPageTracking(supabaseService: SupabaseOCRService) async {
        var allItems: [ExtractedItem] = []
        var allFees: [Fee] = []
        var latestTotal: Double?
        var receiptDate: Date?
        var receiptDateHasTime = false
        
        // For 3+ images, try batch processing first (uses edge function's multi-image support)
        if selectedImages.count >= 2 {
            do {
                progressTracker.updateState(.analyzing(imageIndex: 0, total: selectedImages.count))
                
                let batchResult = try await supabaseService.processReceiptsBatch(images: selectedImages)
                
                // All items from batch already have sourcePageIndex
                allItems = batchResult.items
                allFees = batchResult.fees ?? []
                latestTotal = batchResult.total
                receiptDate = batchResult.parsedReceiptDate
                receiptDateHasTime = batchResult.parsedReceiptDateHasTime
                
                // Create successful page results for all pages
                for index in 0..<selectedImages.count {
                    let pageItems = batchResult.items.filter { $0.sourcePageIndex == index }
                    let result = PageProcessingResult(
                        pageIndex: index,
                        items: pageItems.isEmpty ? nil : pageItems,
                        fees: index == selectedImages.count - 1 ? batchResult.fees : nil,
                        total: index == selectedImages.count - 1 ? batchResult.total : nil,
                        storeName: index == 0 ? batchResult.storeName : nil,
                        error: nil
                    )
                    pageResults.append(result)
                }
                
                // Check for warnings in response (partial failures handled by backend)
                if let rawText = batchResult.rawText, rawText.contains("Page") && rawText.contains("failed") {
                    // Parse warning from rawText if present
                    print("⚠️ Some pages may have had issues: \(rawText)")
                }
                
                progressTracker.updateState(.parsing)
                finalizePageProcessing(
                    items: allItems,
                    fees: allFees,
                    total: latestTotal,
                    receiptDate: receiptDate,
                    receiptDateHasTime: receiptDateHasTime
                )
                return
                
            } catch {
                // Batch failed, fall back to sequential processing
                ErrorHandler.shared.log(error, context: "ImageUploadViewModel.batchProcessing")
                print("⚠️ Batch processing failed, falling back to sequential: \(error.localizedDescription)")
                pageResults = []
                allItems = []
                allFees = []
            }
        }
        
        // Sequential processing (fallback or for single image)
        for (index, image) in selectedImages.enumerated() {
            do {
                try Task.checkCancellation()
                
                // Update progress
                progressTracker.updateState(.preprocessing(imageIndex: index, total: selectedImages.count))
                
                // Rate limit delay between API calls (skip first image)
                if index > 0 {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
                
                progressTracker.updateState(.analyzing(imageIndex: index, total: selectedImages.count))
                
                let pageData = try await supabaseService.processReceiptStructured(images: [image])
                
                // Create successful page result
                let result = PageProcessingResult(
                    pageIndex: index,
                    items: pageData.items,
                    fees: pageData.fees,
                    total: pageData.total,
                    storeName: pageData.storeName,
                    error: nil
                )
                pageResults.append(result)
                
                // Collect items with source page tracking
                for item in pageData.items {
                    let itemWithSource = ExtractedItem(
                        name: item.name,
                        quantity: item.quantity,
                        price: item.price,
                        sourcePageIndex: index
                    )
                    allItems.append(itemWithSource)
                }
                
                // Collect fees
                if let pageFees = pageData.fees {
                    allFees.append(contentsOf: pageFees)
                }
                
                // Use last page's total (most reliable)
                if let total = pageData.total {
                    latestTotal = total
                }
                
                // Use first store name found
                if receiptDate == nil, let parsedDate = pageData.parsedReceiptDate {
                    receiptDate = parsedDate
                    receiptDateHasTime = pageData.parsedReceiptDateHasTime
                }
                
            } catch let error as OCRError {
                ErrorHandler.shared.log(error, context: "ImageUploadViewModel.processPage\(index)")
                addFailedPageResult(at: index, error: error)
                
            } catch {
                ErrorHandler.shared.log(error, context: "ImageUploadViewModel.processPage\(index)")
                addFailedPageResult(at: index, error: OCRError.unknown(error))
            }
        }
        
        progressTracker.updateState(.parsing)
        finalizePageProcessing(
            items: allItems,
            fees: allFees,
            total: latestTotal,
            receiptDate: receiptDate,
            receiptDateHasTime: receiptDateHasTime
        )
    }
    
    /// Adds a failed page result
    private func addFailedPageResult(at index: Int, error: OCRError) {
        let result = PageProcessingResult(
            pageIndex: index,
            items: nil,
            fees: nil,
            total: nil,
            storeName: nil,
            error: error
        )
        pageResults.append(result)
        failedPageIndices.append(index)
    }
    
    /// Finalizes page processing with merged results
    private func finalizePageProcessing(
        items: [ExtractedItem],
        fees: [Fee],
        total: Double?,
        receiptDate: Date?,
        receiptDateHasTime: Bool
    ) {
        // Convert to ReceiptItems
        extractedItems = items.map { $0.toReceiptItem() }
        
        // Deduplicate fees by type
        var seenFeeTypes = Set<String>()
        detectedFees = fees.filter { fee in
            let key = fee.type.lowercased()
            if seenFeeTypes.contains(key) { return false }
            seenFeeTypes.insert(key)
            return true
        }
        
        detectedTotal = total
        detectedReceiptDate = receiptDate
        detectedReceiptDateHasTime = receiptDateHasTime
        ocrConfidence = 0.95
        
        // Determine final state
        if extractedItems.isEmpty && failedPageIndices.count == selectedImages.count {
            errorMessage = "Failed to extract items from all pages"
            progressTracker.updateState(.failed("All pages failed"))
            HapticFeedback.shared.ocrFailed()
        } else if !failedPageIndices.isEmpty {
            let failedCount = failedPageIndices.count
            let totalCount = selectedImages.count
            errorMessage = "\(failedCount) of \(totalCount) page(s) failed. Tap to retry."
            progressTracker.updateState(.completed(extractedItems))
            HapticFeedback.shared.warning()
        } else {
            progressTracker.updateState(.completed(extractedItems))
            HapticFeedback.shared.ocrCompleted()
            print("✅ Extracted \(extractedItems.count) items from \(selectedImages.count) image(s)")
            if let total = detectedTotal {
                print("   Total: $\(String(format: "%.2f", total))")
            }
        }
    }
    
    /// Processes a single image (backward compatibility wrapper)
    func processImage(_ image: UIImage? = nil) async {
        if let image = image {
            if !selectedImages.contains(where: { $0 === image }) {
                selectedImages = [image]
                if scanCapturedAt == nil {
                    scanCapturedAt = Date()
                }
            }
        }
        await processAllImages()
    }
    
    /// Retries OCR processing
    func retryProcessing() async {
        await processAllImages()
    }
}

// MARK: - Page Retry Extension

extension ImageUploadViewModel {
    
    /// Retries processing for a failed page
    /// - Parameter index: The page index to retry
    func retryFailedPage(at index: Int) async {
        guard failedPageIndices.contains(index),
              index >= 0 && index < selectedImages.count else {
            return
        }
        
        retryingPageIndex = index
        HapticFeedback.shared.lightImpact()
        
        let image = selectedImages[index]
        
        do {
            guard let supabaseService = ocrService as? SupabaseOCRService else {
                throw OCRError.ocrServiceUnavailable
            }
            
            let pageData = try await supabaseService.processReceiptStructured(images: [image])
            
            // Create successful result
            let result = PageProcessingResult(
                pageIndex: index,
                items: pageData.items,
                fees: pageData.fees,
                total: pageData.total,
                storeName: pageData.storeName,
                error: nil
            )
            
            // Update page results
            if let existingIndex = pageResults.firstIndex(where: { $0.pageIndex == index }) {
                pageResults[existingIndex] = result
            } else {
                pageResults.append(result)
            }
            
            // Remove from failed indices
            failedPageIndices.removeAll { $0 == index }
            
            // Merge the new items into extracted items
            mergePageResultsIntoExtractedItems()
            
            // Clear error if no more failed pages
            if failedPageIndices.isEmpty {
                errorMessage = nil
            }
            
            HapticFeedback.shared.success()
            
        } catch let error as OCRError {
            ErrorHandler.shared.log(error, context: "ImageUploadViewModel.retryFailedPage")
            
            let result = PageProcessingResult(
                pageIndex: index,
                items: nil,
                fees: nil,
                total: nil,
                storeName: nil,
                error: error
            )
            
            if let existingIndex = pageResults.firstIndex(where: { $0.pageIndex == index }) {
                pageResults[existingIndex] = result
            }
            
            HapticFeedback.shared.error()
            
        } catch {
            ErrorHandler.shared.log(error, context: "ImageUploadViewModel.retryFailedPage")
            HapticFeedback.shared.error()
        }
        
        retryingPageIndex = nil
    }
    
    /// Retries all failed pages
    func retryAllFailedPages() async {
        let indicesToRetry = failedPageIndices
        for index in indicesToRetry {
            await retryFailedPage(at: index)
            
            // Small delay between retries for rate limiting
            if index != indicesToRetry.last {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    /// Merges all successful page results into extracted items
    func mergePageResultsIntoExtractedItems() {
        var allItems: [ReceiptItem] = []
        var latestTotal: Double?
        var allFees: [Fee] = []
        
        let sortedResults = pageResults.sorted { $0.pageIndex < $1.pageIndex }
        
        for result in sortedResults where result.isSuccess {
            if let items = result.items {
                allItems.append(contentsOf: items.map { $0.toReceiptItem() })
            }
            
            if let fees = result.fees {
                allFees.append(contentsOf: fees)
            }
            
            if let total = result.total {
                latestTotal = total
            }
        }
        
        // Deduplicate fees
        var seenFeeTypes = Set<String>()
        let uniqueFees = allFees.filter { fee in
            let key = fee.type.lowercased()
            if seenFeeTypes.contains(key) { return false }
            seenFeeTypes.insert(key)
            return true
        }
        
        extractedItems = allItems
        detectedFees = uniqueFees
        detectedTotal = latestTotal
    }
}

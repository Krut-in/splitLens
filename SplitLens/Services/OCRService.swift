//
//  OCRService.swift
//  SplitLens
//
//  Service protocol and implementation for OCR functionality with multi-image support
//

import Foundation
import UIKit

// MARK: - OCR Service Protocol

/// Protocol defining OCR service capabilities
protocol OCRServiceProtocol {
    /// Processes receipt images and returns raw OCR text
    /// - Parameter images: Array of receipt images to process
    /// - Returns: Raw extracted text from all images combined
    /// - Throws: OCRError if processing fails
    func processReceipt(images: [UIImage]) async throws -> String
}

// MARK: - Mock OCR Service

/// Mock implementation of OCR service for development and testing
/// This will be replaced with actual Supabase Edge Function integration in Part 2
final class MockOCRService: OCRServiceProtocol {
    
    /// Simulates OCR processing with mock raw text data
    func processReceipt(images: [UIImage]) async throws -> String {
        // Simulate network delay (500ms per image)
        let totalDelay = UInt64(images.count) * 500_000_000
        try await Task.sleep(nanoseconds: totalDelay)
        
        // Simulate occasional failures (10% chance)
        if Int.random(in: 1...10) == 1 {
            throw OCRError.noTextDetected
        }
        
        // Return mock raw OCR text that simulates a receipt
        let mockReceipts = [
            """
            WALMART SUPERCENTER
            Store #1234
            123 Main St
            
            Caesar Salad        $12.99
            2x Burger           $15.99
            Pizza Large         $24.99
            QTY: 3 Coke         $2.99
            Fries x2            $4.99
            
            SUBTOTAL            $61.95
            TAX                 $4.01
            TOTAL               $65.96
            """,
            """
            Joe's Deli
            Receipt #5678
            
            Turkey Sandwich     $8.50
            Chips               $1.99
            2x Water            $1.50
            
            Total: $11.99
            Thank you!
            """,
            """
            CORNER CAFE
            
            Cappuccino          $4.50
            Croissant           $3.25
            Muffin              $2.75
            
            Amount: $10.50
            """
        ]
        
        // Return different mock receipts based on image count
        if images.count == 1 {
            return mockReceipts[0]
        } else if images.count == 2 {
            return mockReceipts[0] + "\n\n" + mockReceipts[1]
        } else {
            return mockReceipts.joined(separator: "\n\n")
        }
    }
}

// MARK: - Real OCR Service (Supabase Integration)

/// Real OCR service implementation using Supabase Edge Function
/// Supports both legacy text extraction and structured Gemini Vision extraction
final class SupabaseOCRService: OCRServiceProtocol {
    
    private let edgeFunctionURL: URL
    private let apiKey: String
    private let timeout: TimeInterval
    private let maxRetries: Int
    
    /// Rate limit delay between API calls (in seconds)
    private let rateLimitDelay: TimeInterval = 1.0
    
    init(
        edgeFunctionURL: URL,
        apiKey: String,
        timeout: TimeInterval = 30.0,
        maxRetries: Int = 1
    ) {
        self.edgeFunctionURL = edgeFunctionURL
        self.apiKey = apiKey
        self.timeout = timeout
        self.maxRetries = maxRetries
    }
    
    // MARK: - Legacy Protocol Method (for backward compatibility)
    
    func processReceipt(images: [UIImage]) async throws -> String {
        // For backward compatibility, convert structured data to text
        let structuredData = try await processReceiptStructured(images: images)
        
        // If we have raw text (legacy mode), return it
        if let rawText = structuredData.rawText {
            return rawText
        }
        
        // Convert structured data to readable text format
        var lines: [String] = []
        
        if let storeName = structuredData.storeName {
            lines.append(storeName)
            lines.append("")
        }
        
        for item in structuredData.items {
            let qtyPrefix = item.quantity > 1 ? "\(item.quantity)x " : ""
            lines.append("\(qtyPrefix)\(item.name)        $\(String(format: "%.2f", item.price))")
        }
        
        if let fees = structuredData.fees {
            lines.append("")
            for fee in fees {
                lines.append("\(fee.displayName)        $\(String(format: "%.2f", fee.amount))")
            }
        }
        
        if let total = structuredData.total {
            lines.append("")
            lines.append("TOTAL        $\(String(format: "%.2f", total))")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Single Image Structured Processing
    
    /// Process receipt images and return structured data directly
    /// This is the preferred method when using Gemini Vision API
    func processReceiptStructured(images: [UIImage]) async throws -> StructuredReceiptData {
        guard let firstImage = images.first else {
            throw OCRError.invalidImage
        }
        
        // For now, process only the first image
        // Multi-image support can be added later by merging results
        try Task.checkCancellation()
        
        guard let imageData = firstImage.jpegData(compressionQuality: 0.8) else {
            throw OCRError.invalidImageFormat
        }
        
        if imageData.count < 1000 {
            throw OCRError.invalidImage
        }
        
        return try await processImageStructuredWithRetry(imageData: imageData, attemptNumber: 0)
    }
    
    // MARK: - Multi-Image Receipt Processing
    
    /// Processes multiple receipt images sequentially and merges results
    /// - Parameters:
    ///   - images: Array of receipt images (pages of same receipt)
    ///   - progressTracker: Optional tracker for progress updates
    /// - Returns: Merged StructuredReceiptData with items from all pages
    func processMultipleReceipts(
        images: [UIImage],
        progressTracker: OCRProgressTracker? = nil
    ) async throws -> StructuredReceiptData {
        guard !images.isEmpty else {
            throw OCRError.invalidImage
        }
        
        // Single image - use existing method
        if images.count == 1 {
            progressTracker?.updateState(.analyzing(imageIndex: 0, total: 1))
            return try await processReceiptStructured(images: images)
        }
        
        // Multi-image processing
        var allItems: [ExtractedItem] = []
        var allFees: [Fee] = []
        var detectedTotal: Double?
        var detectedSubtotal: Double?
        var storeName: String?
        var detectedReceiptDateISO: String?
        var rawTexts: [String] = []
        
        for (index, image) in images.enumerated() {
            try Task.checkCancellation()
            
            // Update progress tracker
            progressTracker?.updateState(.preprocessing(imageIndex: index, total: images.count))
            
            // Rate limit delay between API calls (skip first image)
            if index > 0 {
                try await Task.sleep(nanoseconds: UInt64(rateLimitDelay * 1_000_000_000))
            }
            
            progressTracker?.updateState(.analyzing(imageIndex: index, total: images.count))
            
            do {
                let pageData = try await processReceiptStructured(images: [image])
                
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
                
                // Collect fees (will deduplicate later)
                if let pageFees = pageData.fees {
                    for fee in pageFees {
                        allFees.append(fee)
                    }
                }
                
                // Use last page's total/subtotal (most reliable - usually on last page)
                if let total = pageData.total {
                    detectedTotal = total
                }
                if let subtotal = pageData.subtotal {
                    detectedSubtotal = subtotal
                }
                
                // Use first non-nil store name
                if storeName == nil, let name = pageData.storeName {
                    storeName = name
                }

                if detectedReceiptDateISO == nil, let receiptDateISO = pageData.receiptDateISO {
                    detectedReceiptDateISO = receiptDateISO
                }
                
                // Collect raw text if available
                if let rawText = pageData.rawText {
                    rawTexts.append(rawText)
                }
                
            } catch {
                // Log error but continue processing other images
                ErrorHandler.shared.log(error, context: "OCRService.processMultipleReceipts.page\(index)")
                
                // If all images fail, throw the last error
                if index == images.count - 1 && allItems.isEmpty {
                    throw error
                }
            }
        }
        
        progressTracker?.updateState(.parsing)
        
        // Deduplicate items using name similarity
        let mergedItems = deduplicateItems(allItems)
        
        // Deduplicate fees by type
        let mergedFees = deduplicateFees(allFees)
        
        // Combine raw texts if present
        let combinedRawText = rawTexts.isEmpty ? nil : rawTexts.joined(separator: "\n\n--- Page Break ---\n\n")
        
        return StructuredReceiptData(
            items: mergedItems,
            fees: mergedFees.isEmpty ? nil : mergedFees,
            subtotal: detectedSubtotal,
            total: detectedTotal,
            storeName: storeName,
            receiptDateISO: detectedReceiptDateISO,
            rawText: combinedRawText
        )
    }
    
    // MARK: - Deduplication
    
    /// Deduplicates items using Levenshtein distance for name similarity
    /// Items with >80% name similarity are considered duplicates
    /// - Parameter items: Array of extracted items (may contain duplicates)
    /// - Returns: Deduplicated array keeping items with higher prices
    /// - Note: Internal access for unit testing
    func deduplicateItems(_ items: [ExtractedItem]) -> [ExtractedItem] {
        guard items.count > 1 else { return items }
        
        var uniqueItems: [ExtractedItem] = []
        var processedIndices = Set<Int>()
        
        for (i, item) in items.enumerated() {
            guard !processedIndices.contains(i) else { continue }
            
            var bestItem = item
            processedIndices.insert(i)
            
            // Look for duplicates in remaining items
            for (j, otherItem) in items.enumerated() where j > i {
                guard !processedIndices.contains(j) else { continue }
                
                let similarity = calculateNameSimilarity(item.name, otherItem.name)
                
                if similarity > 0.8 {
                    // Mark as duplicate
                    processedIndices.insert(j)
                    
                    // Keep the one with higher price (more complete line item)
                    if otherItem.price > bestItem.price {
                        bestItem = otherItem
                    }
                }
            }
            
            uniqueItems.append(bestItem)
        }
        
        return uniqueItems
    }
    
    /// Deduplicates fees by type, keeping the highest amount
    /// - Note: Internal access for unit testing
    func deduplicateFees(_ fees: [Fee]) -> [Fee] {
        var feesByType: [String: Fee] = [:]
        
        for fee in fees {
            let key = fee.type.lowercased()
            if let existing = feesByType[key] {
                // Keep higher amount
                if fee.amount > existing.amount {
                    feesByType[key] = fee
                }
            } else {
                feesByType[key] = fee
            }
        }
        
        return Array(feesByType.values)
    }
    
    /// Calculates similarity between two strings (0.0 to 1.0)
    /// Uses a simplified Levenshtein-based approach
    /// - Note: Internal access for unit testing
    func calculateNameSimilarity(_ s1: String, _ s2: String) -> Double {
        let str1 = s1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let str2 = s2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact match
        if str1 == str2 { return 1.0 }
        
        // Empty string handling
        if str1.isEmpty || str2.isEmpty { return 0.0 }
        
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Calculates Levenshtein distance between two strings
    /// - Note: Internal access for unit testing
    func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    // MARK: - Retry Logic
    
    private func processImageStructuredWithRetry(imageData: Data, attemptNumber: Int) async throws -> StructuredReceiptData {
        do {
            return try await callStructuredEdgeFunction(imageData: imageData)
        } catch let error as OCRError {
            switch error {
            case .invalidImageFormat, .invalidImage, .noTextDetected:
                throw error
            case .networkError, .ocrServiceUnavailable, .timeout:
                if attemptNumber < maxRetries {
                    let delay = UInt64(pow(2.0, Double(attemptNumber)) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delay)
                    return try await processImageStructuredWithRetry(imageData: imageData, attemptNumber: attemptNumber + 1)
                } else {
                    throw error
                }
            default:
                throw error
            }
        } catch {
            if attemptNumber < maxRetries {
                let delay = UInt64(pow(2.0, Double(attemptNumber)) * 1_000_000_000)
                try await Task.sleep(nanoseconds: delay)
                return try await processImageStructuredWithRetry(imageData: imageData, attemptNumber: attemptNumber + 1)
            } else {
                throw OCRError.unknown(error)
            }
        }
    }
    
    // MARK: - Edge Function Call (Structured Response)
    
    private func callStructuredEdgeFunction(imageData: Data) async throws -> StructuredReceiptData {
        let base64Image = imageData.base64EncodedString()
        
        let requestBody: [String: Any] = ["image": base64Image]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw OCRError.imageProcessingFailed
        }
        
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = timeout
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OCRError.ocrServiceUnavailable
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return try parseStructuredResponse(data)
            case 408, 504:
                throw OCRError.timeout
            case 500...599:
                throw OCRError.ocrServiceUnavailable
            default:
                throw OCRError.ocrServiceUnavailable
            }
            
        } catch let error as OCRError {
            throw error
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw OCRError.timeout
            } else {
                throw OCRError.networkError(urlError)
            }
        } catch {
            throw OCRError.unknown(error)
        }
    }
    
    // MARK: - Batch Multi-Image Edge Function Call
    
    /// Processes multiple images in a single batch request to the edge function
    /// Uses the backend's multi-image support with rate limiting and deduplication
    /// - Parameter images: Array of UIImages to process
    /// - Returns: Merged StructuredReceiptData with items from all pages
    func processReceiptsBatch(images: [UIImage]) async throws -> StructuredReceiptData {
        guard !images.isEmpty else {
            throw OCRError.invalidImage
        }
        
        // Convert all images to base64
        var base64Images: [String] = []
        for image in images {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw OCRError.invalidImageFormat
            }
            if imageData.count < 1000 {
                throw OCRError.invalidImage
            }
            base64Images.append(imageData.base64EncodedString())
        }
        
        // Create batch request body
        let requestBody: [String: Any] = ["images": base64Images]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw OCRError.imageProcessingFailed
        }
        
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        // Longer timeout for batch processing (30s + 5s per additional image)
        request.timeoutInterval = timeout + (Double(images.count - 1) * 5.0)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OCRError.ocrServiceUnavailable
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return try parseStructuredResponse(data)
            case 408, 504:
                throw OCRError.timeout
            case 500...599:
                throw OCRError.ocrServiceUnavailable
            default:
                throw OCRError.ocrServiceUnavailable
            }
            
        } catch let error as OCRError {
            throw error
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw OCRError.timeout
            } else {
                throw OCRError.networkError(urlError)
            }
        } catch {
            throw OCRError.unknown(error)
        }
    }
    
    // MARK: - Parse Structured Response
    
    private func parseStructuredResponse(_ data: Data) throws -> StructuredReceiptData {
        // First, check for error response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorMessage = json["error"] as? String {
            throw OCRError.parsingFailed(errorMessage)
        }
        
        // Try to decode as StructuredReceiptData
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(StructuredReceiptData.self, from: data)
            
            // Validate we got meaningful data
            if result.items.isEmpty && result.rawText == nil {
                throw OCRError.noTextDetected
            }
            
            return result
        } catch let decodingError as DecodingError {
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Failed to decode response: \(responseString)")
            }
            throw OCRError.parsingFailed("Failed to parse structured response: \(decodingError.localizedDescription)")
        }
    }
}

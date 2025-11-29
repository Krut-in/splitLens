//
//  OCRService.swift
//  SplitLens
//
//  Service protocol and implementation for OCR functionality
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
    
    /// Legacy method for single image processing (deprecated)
    /// - Parameter image: The receipt image to process
    /// - Returns: Array of extracted receipt items
    /// - Throws: OCRError if processing fails
    @available(*, deprecated, message: "Use processReceipt(images:) with TextParser instead")
    func extractReceiptData(from image: UIImage) async throws -> [ReceiptItem]
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
    
    /// Legacy method - simulates OCR processing with mock data
    func extractReceiptData(from image: UIImage) async throws -> [ReceiptItem] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simulate occasional failures (10% chance)
        if Int.random(in: 1...10) == 1 {
            throw OCRError.noTextDetected
        }
        
        // Return mock extracted items
        return [
            ReceiptItem(
                name: "Caesar Salad",
                quantity: 1,
                price: 12.99
            ),
            ReceiptItem(
                name: "Margherita Pizza",
                quantity: 1,
                price: 18.50
            ),
            ReceiptItem(
                name: "Chicken Wings",
                quantity: 2,
                price: 9.99
            ),
            ReceiptItem(
                name: "Coke",
                quantity: 3,
                price: 2.50
            ),
            ReceiptItem(
                name: "Fries",
                quantity: 2,
                price: 4.99
            )
        ]
    }
}

// MARK: - Real OCR Service (Supabase Integration)

/// Real OCR service implementation using Supabase Edge Function
final class SupabaseOCRService: OCRServiceProtocol {
    
    private let edgeFunctionURL: URL
    private let apiKey: String
    private let timeout: TimeInterval
    private let maxRetries: Int
    
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
    
    // MARK: - Multi-Image Processing
    
    func processReceipt(images: [UIImage]) async throws -> String {
        var combinedText = ""
        
        // Process each image sequentially
        for (index, image) in images.enumerated() {
            // Check for cancellation
            try Task.checkCancellation()
            
            // Convert image to JPEG data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw OCRError.invalidImageFormat
            }
            
            // Validate image size (not too small)
            if imageData.count < 1000 {
                throw OCRError.invalidImage
            }
            
            // Process this image with retry logic
            let text = try await processImageWithRetry(imageData: imageData, attemptNumber: 0)
            
            // Append to combined text
            if !combinedText.isEmpty {
                combinedText += "\n\n"
            }
            combinedText += text
        }
        
        // Validate we got some text
        guard !combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRError.noTextDetected
        }
        
        return combinedText
    }
    
    // MARK: - Retry Logic
    
    private func processImageWithRetry(imageData: Data, attemptNumber: Int) async throws -> String {
        do {
            return try await callOCREdgeFunction(imageData: imageData)
        } catch let error as OCRError {
            // Don't retry on certain errors
            switch error {
            case .invalidImageFormat, .invalidImage, .noTextDetected:
                throw error
            case .networkError, .ocrServiceUnavailable, .timeout:
                // Retry network-related errors
                if attemptNumber < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s, etc.
                    let delay = UInt64(pow(2.0, Double(attemptNumber)) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delay)
                    return try await processImageWithRetry(imageData: imageData, attemptNumber: attemptNumber + 1)
                } else {
                    throw error
                }
            default:
                throw error
            }
        } catch {
            // Unknown error - retry if attempts remain
            if attemptNumber < maxRetries {
                let delay = UInt64(pow(2.0, Double(attemptNumber)) * 1_000_000_000)
                try await Task.sleep(nanoseconds: delay)
                return try await processImageWithRetry(imageData: imageData, attemptNumber: attemptNumber + 1)
            } else {
                throw OCRError.unknown(error)
            }
        }
    }
    
    // MARK: - Edge Function Call
    
    private func callOCREdgeFunction(imageData: Data) async throws -> String {
        // Convert image to base64
        let base64Image = imageData.base64EncodedString()
        
        // Create JSON request body
        let requestBody: [String: Any] = ["image": base64Image]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw OCRError.imageProcessingFailed
        }
        
        // Create request with timeout
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = timeout
        
        do {
            // Send request with timeout
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OCRError.ocrServiceUnavailable
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - parse response
                return try parseOCRResponse(data)
            case 408, 504:
                // Timeout errors
                throw OCRError.timeout
            case 500...599:
                // Service unavailable
                throw OCRError.ocrServiceUnavailable
            default:
                throw OCRError.ocrServiceUnavailable
            }
            
        } catch let error as OCRError {
            throw error
        } catch let urlError as URLError {
            // Handle URLSession errors
            if urlError.code == .timedOut {
                throw OCRError.timeout
            } else if urlError.code == .notConnectedToInternet {
                throw OCRError.networkError(urlError)
            } else {
                throw OCRError.networkError(urlError)
            }
        } catch {
            throw OCRError.unknown(error)
        }
    }
    
    // MARK: - Response Parsing
    
    private func parseOCRResponse(_ data: Data) throws -> String {
        // Parse JSON response: { "text": "raw ocr text..." }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw OCRError.parsingFailed("Invalid response format")
        }
        
        // Validate we got meaningful text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw OCRError.noTextDetected
        }
        
        return text
    }
    
    // MARK: - Legacy Method
    
    func extractReceiptData(from image: UIImage) async throws -> [ReceiptItem] {
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw OCRError.invalidImageFormat
        }
        
        // Create request
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        do {
            // Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OCRError.ocrServiceUnavailable
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw OCRError.ocrServiceUnavailable
            }
            
            // Parse response
            let decoder = JSONDecoder()
            let items = try decoder.decode([ReceiptItem].self, from: data)
            
            if items.isEmpty {
                throw OCRError.noTextDetected
            }
            
            return items
            
        } catch let error as OCRError {
            throw error
        } catch {
            throw OCRError.networkError(error)
        }
    }
}

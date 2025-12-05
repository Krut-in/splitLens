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
    
    // MARK: - Structured Receipt Processing (NEW - Preferred Method)
    
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


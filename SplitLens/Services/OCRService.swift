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
    /// Extracts receipt data from an image asynchronously
    /// - Parameter image: The receipt image to process
    /// - Returns: Array of extracted receipt items
    /// - Throws: OCRError if processing fails
    func extractReceiptData(from image: UIImage) async throws -> [ReceiptItem]
}

// MARK: - Mock OCR Service

/// Mock implementation of OCR service for development and testing
/// This will be replaced with actual Supabase Edge Function integration in Part 2
final class MockOCRService: OCRServiceProtocol {
    
    /// Simulates OCR processing with mock data
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
/// This will be implemented in Part 2
final class SupabaseOCRService: OCRServiceProtocol {
    
    private let edgeFunctionURL: URL
    private let apiKey: String
    
    init(edgeFunctionURL: URL, apiKey: String) {
        self.edgeFunctionURL = edgeFunctionURL
        self.apiKey = apiKey
    }
    
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

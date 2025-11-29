//
//  SupabaseService.swift
//  SplitLens
//
//  Service for database operations with Supabase
//

import Foundation
import UIKit

// MARK: - Supabase Service Protocol

/// Protocol defining database service capabilities
protocol SupabaseServiceProtocol {
    /// Saves a receipt session to the database
    func saveSession(_ session: ReceiptSession) async throws
    
    /// Fetches a specific session by ID
    func fetchSession(id: UUID) async throws -> ReceiptSession
    
    /// Fetches all sessions, optionally limited
    func fetchAllSessions(limit: Int?) async throws -> [ReceiptSession]
    
    /// Deletes a session by ID
    func deleteSession(id: UUID) async throws
    
    /// Fetches recent sessions (for history view)
    func fetchRecentSessions(count: Int) async throws -> [ReceiptSession]
    
    /// Uploads a receipt image to Supabase Storage
    /// - Parameters:
    ///   - image: The receipt image to upload
    ///   - sessionId: UUID of the session this image belongs to
    /// - Returns: Public URL of the uploaded image
    /// - Throws: StorageError if upload fails
    func uploadReceiptImage(_ image: UIImage, sessionId: UUID) async throws -> String
    
    /// Calls OCR Edge Function to extract text from image
    /// - Parameter imageData: JPEG image data
    /// - Returns: Raw extracted text
    /// - Throws: OCRError if processing fails
    func callOCRFunction(imageData: Data) async throws -> String
}

// MARK: - Mock Supabase Service

/// Mock implementation using in-memory storage for development
final class MockSupabaseService: SupabaseServiceProtocol {
    
    /// In-memory storage for sessions
    private var sessions: [UUID: ReceiptSession] = [:]
    
    /// Shared instance for app-wide use
    static let shared = MockSupabaseService()
    
    private init() {
        // Preload with sample data
        let samples = ReceiptSession.samples
        for session in samples {
            sessions[session.id] = session
        }
    }
    
    func saveSession(_ session: ReceiptSession) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Save to memory
        sessions[session.id] = session
    }
    
    func fetchSession(id: UUID) async throws -> ReceiptSession {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard let session = sessions[id] else {
            throw DatabaseError.fetchFailed("Session not found")
        }
        
        return session
    }
    
    func fetchAllSessions(limit: Int? = nil) async throws -> [ReceiptSession] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let allSessions = Array(sessions.values)
            .sorted { $0.createdAt > $1.createdAt } // Most recent first
        
        if let limit = limit {
            return Array(allSessions.prefix(limit))
        }
        
        return allSessions
    }
    
    func deleteSession(id: UUID) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard sessions[id] != nil else {
            throw DatabaseError.deleteFailed("Session not found")
        }
        
        sessions.removeValue(forKey: id)
    }
    
    func fetchRecentSessions(count: Int) async throws -> [ReceiptSession] {
        return try await fetchAllSessions(limit: count)
    }
    
    func uploadReceiptImage(_ image: UIImage, sessionId: UUID) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        // Return mock URL
        return "https://mock.supabase.co/storage/v1/object/public/receipt-images/\(sessionId.uuidString)/\(Date().timeIntervalSince1970).jpg"
    }
    
    func callOCRFunction(imageData: Data) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Return mock OCR text
        return """
        WALMART SUPERCENTER
        Store #1234
        
        Caesar Salad        $12.99
        2x Burger           $15.99
        Pizza Large         $24.99
        QTY: 3 Coke         $2.99
        Fries x2            $4.99
        
        TOTAL               $65.96
        """
    }
}

// MARK: - Real Supabase Service

/// Real implementation using Supabase REST API
/// This will be fully implemented in Part 2
final class RealSupabaseService: SupabaseServiceProtocol {
    
    private let projectURL: String
    private let apiKey: String
    private let tableName = "receipt_sessions"
    
    init(projectURL: String, apiKey: String) {
        self.projectURL = projectURL
        self.apiKey = apiKey
    }
    
    /// Base URL for Supabase REST API
    private var baseURL: URL {
        URL(string: "\(projectURL)/rest/v1/\(tableName)")!
    }
    
    /// Creates a URLRequest with authentication headers
    private func createRequest(
        url: URL,
        method: String,
        body: Data? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return request
    }
    
    func saveSession(_ session: ReceiptSession) async throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(session)
        
        let request = createRequest(
            url: baseURL,
            method: "POST",
            body: jsonData
        )
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw DatabaseError.saveFailed("HTTP error")
            }
        } catch {
            ErrorHandler.shared.log(error, context: "SupabaseService.saveSession")
            throw DatabaseError.saveFailed(error.localizedDescription)
        }
    }
    
    func fetchSession(id: UUID) async throws -> ReceiptSession {
        let urlString = "\(baseURL.absoluteString)?id=eq.\(id.uuidString)"
        guard let url = URL(string: urlString) else {
            throw DatabaseError.fetchFailed("Invalid URL")
        }
        
        let request = createRequest(url: url, method: "GET")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw DatabaseError.fetchFailed("HTTP error")
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            
            let sessions = try decoder.decode([ReceiptSession].self, from: data)
            
            guard let session = sessions.first else {
                throw DatabaseError.fetchFailed("Session not found")
            }
            
            return session
        } catch {
            ErrorHandler.shared.log(error, context: "SupabaseService.fetchSession")
            throw DatabaseError.fetchFailed(error.localizedDescription)
        }
    }
    
    func fetchAllSessions(limit: Int? = nil) async throws -> [ReceiptSession] {
        var urlString = "\(baseURL.absoluteString)?order=created_at.desc"
        
        if let limit = limit {
            urlString += "&limit=\(limit)"
        }
        
        guard let url = URL(string: urlString) else {
            throw DatabaseError.fetchFailed("Invalid URL")
        }
        
        let request = createRequest(url: url, method: "GET")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw DatabaseError.fetchFailed("HTTP error")
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode([ReceiptSession].self, from: data)
        } catch {
            ErrorHandler.shared.log(error, context: "SupabaseService.fetchAllSessions")
            throw DatabaseError.fetchFailed(error.localizedDescription)
        }
    }
    
    func deleteSession(id: UUID) async throws {
        let urlString = "\(baseURL.absoluteString)?id=eq.\(id.uuidString)"
        guard let url = URL(string: urlString) else {
            throw DatabaseError.deleteFailed("Invalid URL")
        }
        
        let request = createRequest(url: url, method: "DELETE")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw DatabaseError.deleteFailed("HTTP error")
            }
        } catch {
            ErrorHandler.shared.log(error, context: "SupabaseService.deleteSession")
            throw DatabaseError.deleteFailed(error.localizedDescription)
        }
    }
    
    func fetchRecentSessions(count: Int) async throws -> [ReceiptSession] {
        return try await fetchAllSessions(limit: count)
    }
    
    // MARK: - Storage Operations
    
    func uploadReceiptImage(_ image: UIImage, sessionId: UUID) async throws -> String {
        // Convert image to JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.invalidImageFormat
        }
        
        // Create storage path
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(timestamp).jpg"
        let storagePath = "\(sessionId.uuidString)/\(fileName)"
        
        // Construct storage URL
        let storageURL = URL(string: "\(projectURL)/storage/v1/object/receipt-images/\(storagePath)")!
        
        // Create request
        var request = URLRequest(url: storageURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw StorageError.uploadFailed("Invalid response")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 413 {
                    throw StorageError.quotaExceeded
                }
                throw StorageError.uploadFailed("HTTP \(httpResponse.statusCode)")
            }
            
            // Return public URL
            return "\(projectURL)/storage/v1/object/public/receipt-images/\(storagePath)"
            
        } catch let error as StorageError {
            ErrorHandler.shared.log(error, context: "SupabaseService.uploadReceiptImage")
            throw error
        } catch {
            ErrorHandler.shared.log(error, context: "SupabaseService.uploadReceiptImage")
            throw StorageError.networkError(error)
        }
    }
    
    // MARK: - Edge Functions
    
    func callOCRFunction(imageData: Data) async throws -> String {
        // This method is typically not called directly from RealSupabaseService
        // OCR is handled by SupabaseOCRService which calls the Edge Function
        // This is here for protocol conformance
        
        let ocrURL = URL(string: "\(projectURL)/functions/v1/extract-receipt-data")!
        
        // Convert to base64
        let base64Image = imageData.base64EncodedString()
        let requestBody: [String: Any] = ["image": base64Image]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw OCRError.imageProcessingFailed
        }
        
        var request = URLRequest(url: ocrURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw OCRError.ocrServiceUnavailable
            }
            
            // Parse response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                throw OCRError.parsingFailed("Invalid response format")
            }
            
            return text
            
        } catch let error as OCRError {
            throw error
        } catch {
            throw OCRError.networkError(error)
        }
    }
}

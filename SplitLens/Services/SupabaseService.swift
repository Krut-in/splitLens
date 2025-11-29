//
//  SupabaseService.swift
//  SplitLens
//
//  Service for database operations with Supabase
//

import Foundation

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
}

//
//  TextParser.swift
//  SplitLens
//
//  Service for parsing raw OCR text into structured receipt items
//

import Foundation

// MARK: - Text Parser Protocol

/// Protocol defining text parsing capabilities
protocol TextParserProtocol {
    /// Parses raw OCR text into structured receipt items
    /// - Parameter rawText: The raw text extracted from OCR
    /// - Returns: Array of parsed receipt items with confidence scores
    /// - Throws: OCRError if parsing fails completely
    func parseReceiptText(_ rawText: String) throws -> [ReceiptItem]
    
    /// Calculates confidence score for parsed data (0.0 to 1.0)
    /// - Parameter items: The parsed items to evaluate
    /// - Returns: Confidence score where 1.0 = high confidence, 0.0 = no confidence
    func calculateConfidence(for items: [ReceiptItem]) -> Double
}

// MARK: - Receipt Text Parser

/// Implements receipt text parsing with regex-based extraction
final class ReceiptTextParser: TextParserProtocol {
    
    // MARK: - Regex Patterns
    
    /// Pattern to match price values: $12.99, 12.99, $12
    private let pricePattern = #"\$?\d+\.?\d{0,2}"#
    
    /// Pattern to match quantity indicators: 2x, x2, QTY: 3, qty 2
    private let quantityPattern = #"(?:(\d+)\s*x|x\s*(\d+)|qty:?\s*(\d+))"#
    
    /// Pattern to match dollar amounts more strictly (for extraction)
    private let strictPricePattern = #"\$?(\d+)\.(\d{2})|(\d+)"#
    
    // MARK: - Parsing Methods
    
    func parseReceiptText(_ rawText: String) throws -> [ReceiptItem] {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OCRError.noTextDetected
        }
        
        // Split text into lines for line-by-line processing
        let lines = rawText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var items: [ReceiptItem] = []
        
        for line in lines {
            // Skip common receipt header/footer patterns
            if shouldSkipLine(line) {
                continue
            }
            
            // Try to extract item from line
            if let item = extractItem(from: line) {
                items.append(item)
            }
        }
        
        // If we couldn't parse any items, throw error
        if items.isEmpty {
            throw OCRError.parsingFailed("No valid items could be extracted from text")
        }
        
        return items
    }
    
    func calculateConfidence(for items: [ReceiptItem]) -> Double {
        guard !items.isEmpty else { return 0.0 }
        
        var totalConfidence: Double = 0.0
        
        for item in items {
            var itemConfidence: Double = 0.0
            
            // Valid name (not too short, not all numbers)
            if item.name.count >= 3 && !item.name.allSatisfy({ $0.isNumber }) {
                itemConfidence += 0.4
            }
            
            // Valid price (reasonable range)
            if item.price > 0 && item.price < 1000 {
                itemConfidence += 0.3
            }
            
            // Valid quantity
            if item.quantity > 0 && item.quantity <= 20 {
                itemConfidence += 0.3
            }
            
            totalConfidence += itemConfidence
        }
        
        let averageConfidence = totalConfidence / Double(items.count)
        return min(averageConfidence, 1.0)
    }
    
    // MARK: - Private Helper Methods
    
    /// Determines if a line should be skipped (headers, footers, etc.)
    private func shouldSkipLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        
        // Skip common receipt headers/footers
        let skipPatterns = [
            "receipt", "thank you", "total", "subtotal", "tax", "tip",
            "balance", "change", "cash", "card", "credit", "debit",
            "visa", "mastercard", "amex", "discover",
            "store", "location", "address", "phone", "website",
            "date", "time", "server", "cashier", "order"
        ]
        
        for pattern in skipPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        // Skip very short lines (likely not item descriptions)
        if line.count < 3 {
            return true
        }
        
        // Skip lines that are only numbers or special characters
        if line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace }) {
            return true
        }
        
        return false
    }
    
    /// Extracts a receipt item from a single line of text
    private func extractItem(from line: String) -> ReceiptItem? {
        // Try to extract price
        guard let price = extractPrice(from: line) else {
            return nil
        }
        
        // Extract quantity (default to 1)
        let quantity = extractQuantity(from: line) ?? 1
        
        // Extract item name (everything before the price/quantity)
        let name = extractItemName(from: line, price: price, quantity: quantity)
        
        // Validate we have a meaningful name
        guard !name.isEmpty, name.count >= 2 else {
            return nil
        }
        
        return ReceiptItem(
            name: name,
            quantity: quantity,
            price: price
        )
    }
    
    /// Extracts price from a line using regex
    private func extractPrice(from line: String) -> Double? {
        // Try to find price patterns in the line
        guard let regex = try? NSRegularExpression(pattern: strictPricePattern, options: []) else {
            return nil
        }
        
        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, options: [], range: range)
        
        // Find the last match (prices usually at end of line)
        guard let lastMatch = matches.last else {
            return nil
        }
        
        // Extract the matched price string
        guard let matchRange = Range(lastMatch.range, in: line) else {
            return nil
        }
        
        let priceString = String(line[matchRange])
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return Double(priceString)
    }
    
    /// Extracts quantity from a line using regex
    private func extractQuantity(from line: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: quantityPattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else {
            return nil
        }
        
        // Try each capture group to find the quantity value
        for i in 1..<match.numberOfRanges {
            if let groupRange = Range(match.range(at: i), in: line) {
                let quantityString = String(line[groupRange])
                if let quantity = Int(quantityString), quantity > 0 {
                    return quantity
                }
            }
        }
        
        return nil
    }
    
    /// Extracts item name by removing price and quantity indicators
    private func extractItemName(from line: String, price: Double, quantity: Int?) -> String {
        var name = line
        
        // Remove price from the end
        let priceString = String(format: "%.2f", price)
        name = name.replacingOccurrences(of: "$" + priceString, with: "")
        name = name.replacingOccurrences(of: priceString, with: "")
        
        // Remove quantity indicators
        if let qty = quantity, qty > 1 {
            name = name.replacingOccurrences(of: "\(qty)x", with: "", options: .caseInsensitive)
            name = name.replacingOccurrences(of: "x\(qty)", with: "", options: .caseInsensitive)
            name = name.replacingOccurrences(of: "qty:\(qty)", with: "", options: .caseInsensitive)
            name = name.replacingOccurrences(of: "qty \(qty)", with: "", options: .caseInsensitive)
        }
        
        // Clean up whitespace and special characters
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.replacingOccurrences(of: "  ", with: " ") // Remove double spaces
        
        // Remove leading/trailing special characters
        while name.first?.isPunctuation == true {
            name.removeFirst()
        }
        while name.last?.isPunctuation == true {
            name.removeLast()
        }
        
        return name.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Mock Text Parser

/// Mock parser for testing that returns perfect results
final class MockTextParser: TextParserProtocol {
    func parseReceiptText(_ rawText: String) throws -> [ReceiptItem] {
        // Return mock parsed items for testing
        return [
            ReceiptItem(name: "Caesar Salad", quantity: 1, price: 12.99),
            ReceiptItem(name: "Burger", quantity: 2, price: 15.99),
            ReceiptItem(name: "Fries", quantity: 2, price: 4.99)
        ]
    }
    
    func calculateConfidence(for items: [ReceiptItem]) -> Double {
        return 0.95 // High confidence for mock data
    }
}

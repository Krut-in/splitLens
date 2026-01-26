//
//  PageProcessingResult.swift
//  SplitLens
//
//  Result model for individual receipt page processing
//

import Foundation

/// Result from processing a single receipt page
struct PageProcessingResult: Identifiable, Equatable {
    let id = UUID()
    let pageIndex: Int
    let items: [ExtractedItem]?
    let fees: [Fee]?
    let total: Double?
    let storeName: String?
    let error: OCRError?
    
    /// Whether this page can be retried
    var canRetry: Bool {
        error != nil
    }
    
    /// Whether this page was processed successfully
    var isSuccess: Bool {
        error == nil && items != nil
    }
    
    static func == (lhs: PageProcessingResult, rhs: PageProcessingResult) -> Bool {
        lhs.id == rhs.id && lhs.pageIndex == rhs.pageIndex
    }
}

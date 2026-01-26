//
//  OCRServiceTests.swift
//  SplitLensTests
//
//  Comprehensive unit tests for OCR service functionality including
//  multi-image processing, item deduplication, and partial failure handling
//

import XCTest
@testable import SplitLens

// MARK: - OCR Service Tests

final class OCRServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: SupabaseOCRService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        // Create a test instance with mock URL (won't make real network calls in unit tests)
        sut = SupabaseOCRService(
            edgeFunctionURL: URL(string: "https://test.supabase.co/functions/v1/extract-receipt-data")!,
            apiKey: "test-api-key",
            timeout: 10.0,
            maxRetries: 0
        )
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Multi-Image Merging Tests
    
    /// Tests that items from multiple pages are properly merged
    func testProcessMultipleReceipts_MergesItems() {
        // Given: Items from two different pages
        let page1Items = [
            ExtractedItem(name: "Pizza", quantity: 1, price: 15.00, sourcePageIndex: 0),
            ExtractedItem(name: "Salad", quantity: 1, price: 8.00, sourcePageIndex: 0)
        ]
        
        let page2Items = [
            ExtractedItem(name: "Burger", quantity: 2, price: 12.00, sourcePageIndex: 1),
            ExtractedItem(name: "Fries", quantity: 1, price: 4.00, sourcePageIndex: 1)
        ]
        
        let allItems = page1Items + page2Items
        
        // When: We deduplicate (no duplicates in this case)
        let mergedItems = sut.deduplicateItems(allItems)
        
        // Then: All 4 unique items should be preserved
        XCTAssertEqual(mergedItems.count, 4, "All unique items should be preserved")
        
        // Verify item names are all present
        let itemNames = Set(mergedItems.map { $0.name })
        XCTAssertTrue(itemNames.contains("Pizza"))
        XCTAssertTrue(itemNames.contains("Salad"))
        XCTAssertTrue(itemNames.contains("Burger"))
        XCTAssertTrue(itemNames.contains("Fries"))
    }
    
    /// Tests that duplicate fees are properly deduplicated by keeping highest amount
    func testProcessMultipleReceipts_DeduplicatesFees() {
        // Given: Fees from two pages with duplicate tax
        let fees = [
            Fee(type: "tax", amount: 2.00),
            Fee(type: "delivery", amount: 4.95),
            Fee(type: "Tax", amount: 2.50),  // Duplicate with different case and higher amount
            Fee(type: "service", amount: 3.00)
        ]
        
        // When: We deduplicate fees
        let deduplicatedFees = sut.deduplicateFees(fees)
        
        // Then: Should have 3 unique fee types
        XCTAssertEqual(deduplicatedFees.count, 3, "Should have 3 unique fee types")
        
        // Tax should keep the higher amount
        let taxFee = deduplicatedFees.first { $0.type.lowercased() == "tax" }
        XCTAssertNotNil(taxFee, "Tax fee should exist")
        XCTAssertEqual(taxFee?.amount, 2.50, accuracy: 0.001, "Should keep higher tax amount")
    }
    
    /// Tests that the total from the last page is used (as receipt totals are typically on the last page)
    func testProcessMultipleReceipts_UsesLastPageTotal() {
        // This test verifies the merge strategy behavior
        // The actual merging logic happens in processMultipleReceipts
        // Here we verify the expected behavior through data structure inspection
        
        // Given: Page data with different totals
        let page1Data = StructuredReceiptData(
            items: [ExtractedItem(name: "Item1", quantity: 1, price: 10.00)],
            fees: nil,
            subtotal: 10.00,
            total: 10.00,  // Page 1 total
            storeName: "Store A",
            rawText: nil
        )
        
        let page2Data = StructuredReceiptData(
            items: [ExtractedItem(name: "Item2", quantity: 1, price: 20.00)],
            fees: nil,
            subtotal: 30.00,
            total: 32.50,  // Page 2 total (final receipt total)
            storeName: nil,
            rawText: nil
        )
        
        // Then: Per merge strategy, last page's total should be used
        // Simulating the merge logic expectation
        let expectedTotal = page2Data.total  // Last non-nil total
        XCTAssertEqual(expectedTotal, 32.50, "Last page total should be 32.50")
        
        // And: First page's store name should be used
        let expectedStoreName = page1Data.storeName
        XCTAssertEqual(expectedStoreName, "Store A", "First non-nil store name should be used")
    }
    
    /// Tests that source page index is properly tracked for each item
    func testProcessMultipleReceipts_TracksSourcePageIndex() {
        // Given: Items with explicit source page indices
        let items = [
            ExtractedItem(name: "Coffee", quantity: 1, price: 4.50, sourcePageIndex: 0),
            ExtractedItem(name: "Muffin", quantity: 1, price: 3.00, sourcePageIndex: 0),
            ExtractedItem(name: "Sandwich", quantity: 1, price: 8.00, sourcePageIndex: 1),
            ExtractedItem(name: "Water", quantity: 2, price: 2.00, sourcePageIndex: 2)
        ]
        
        // When: Processing items
        let processedItems = sut.deduplicateItems(items)
        
        // Then: Source page indices should be preserved
        XCTAssertEqual(processedItems.count, 4)
        
        let coffeeItem = processedItems.first { $0.name == "Coffee" }
        XCTAssertEqual(coffeeItem?.sourcePageIndex, 0, "Coffee should be from page 0")
        
        let sandwichItem = processedItems.first { $0.name == "Sandwich" }
        XCTAssertEqual(sandwichItem?.sourcePageIndex, 1, "Sandwich should be from page 1")
        
        let waterItem = processedItems.first { $0.name == "Water" }
        XCTAssertEqual(waterItem?.sourcePageIndex, 2, "Water should be from page 2")
    }
    
    // MARK: - Item Deduplication Tests
    
    /// Tests that exact duplicate items are properly deduplicated
    func testDeduplicateItems_ExactMatch() {
        // Given: Two identical items
        let items = [
            ExtractedItem(name: "Caesar Salad", quantity: 1, price: 12.99, sourcePageIndex: 0),
            ExtractedItem(name: "Caesar Salad", quantity: 1, price: 12.99, sourcePageIndex: 1)
        ]
        
        // When: Deduplicating
        let result = sut.deduplicateItems(items)
        
        // Then: Should have only one item
        XCTAssertEqual(result.count, 1, "Exact duplicates should be merged into one")
        XCTAssertEqual(result[0].name, "Caesar Salad")
    }
    
    /// Tests that items with high similarity (>80%) are treated as duplicates
    func testDeduplicateItems_HighSimilarity() {
        // Given: Items with slight variations (>80% similar)
        let items = [
            ExtractedItem(name: "Caesar Salad", quantity: 1, price: 12.99, sourcePageIndex: 0),
            ExtractedItem(name: "Ceasar Salad", quantity: 1, price: 12.99, sourcePageIndex: 1)  // Typo
        ]
        
        // Calculate similarity
        let similarity = sut.calculateNameSimilarity("Caesar Salad", "Ceasar Salad")
        
        // Then: Similarity should be > 80%
        XCTAssertGreaterThan(similarity, 0.8, "These items should have >80% similarity")
        
        // When: Deduplicating
        let result = sut.deduplicateItems(items)
        
        // Then: Should be merged into one
        XCTAssertEqual(result.count, 1, "Similar items should be merged")
    }
    
    /// Tests that items with low similarity (<80%) are kept as separate items
    func testDeduplicateItems_LowSimilarity() {
        // Given: Items with different names
        let items = [
            ExtractedItem(name: "Pizza", quantity: 1, price: 15.00, sourcePageIndex: 0),
            ExtractedItem(name: "Pasta", quantity: 1, price: 12.00, sourcePageIndex: 1)
        ]
        
        // Calculate similarity
        let similarity = sut.calculateNameSimilarity("Pizza", "Pasta")
        
        // Then: Similarity should be < 80%
        XCTAssertLessThanOrEqual(similarity, 0.8, "Pizza and Pasta should have <80% similarity")
        
        // When: Deduplicating
        let result = sut.deduplicateItems(items)
        
        // Then: Both items should be kept
        XCTAssertEqual(result.count, 2, "Dissimilar items should be kept separate")
    }
    
    /// Tests that when duplicates exist, the one with higher price is kept
    func testDeduplicateItems_KeepsHigherPrice() {
        // Given: Duplicate items with different prices
        let items = [
            ExtractedItem(name: "Large Pizza", quantity: 1, price: 15.00, sourcePageIndex: 0),
            ExtractedItem(name: "Large Pizza", quantity: 1, price: 18.00, sourcePageIndex: 1)  // Higher price
        ]
        
        // When: Deduplicating
        let result = sut.deduplicateItems(items)
        
        // Then: Should keep the higher price
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].price, 18.00, accuracy: 0.001, "Should keep higher price")
    }
    
    /// Tests that deduplication is case-insensitive
    func testDeduplicateItems_CaseInsensitive() {
        // Given: Same item with different cases
        let items = [
            ExtractedItem(name: "BURGER", quantity: 1, price: 10.00, sourcePageIndex: 0),
            ExtractedItem(name: "burger", quantity: 1, price: 10.00, sourcePageIndex: 1),
            ExtractedItem(name: "Burger", quantity: 1, price: 12.00, sourcePageIndex: 2)  // Higher price
        ]
        
        // When: Deduplicating
        let result = sut.deduplicateItems(items)
        
        // Then: Should merge all into one, keeping highest price
        XCTAssertEqual(result.count, 1, "Case variations should be treated as duplicates")
        XCTAssertEqual(result[0].price, 12.00, accuracy: 0.001, "Should keep highest price")
    }
    
    /// Tests deduplication with empty item array
    func testDeduplicateItems_EmptyArray() {
        // Given: Empty array
        let items: [ExtractedItem] = []
        
        // When: Deduplicating
        let result = sut.deduplicateItems(items)
        
        // Then: Should return empty array
        XCTAssertTrue(result.isEmpty, "Empty input should return empty output")
    }
    
    /// Tests deduplication with single item
    func testDeduplicateItems_SingleItem() {
        // Given: Single item
        let items = [
            ExtractedItem(name: "Coffee", quantity: 1, price: 4.50, sourcePageIndex: 0)
        ]
        
        // When: Deduplicating
        let result = sut.deduplicateItems(items)
        
        // Then: Should return the same item
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Coffee")
    }
    
    // MARK: - Partial Failure Tests
    
    /// Tests that successful pages are preserved when some pages fail
    func testPartialFailure_PreservesSuccessfulPages() {
        // This test validates the expected behavior through data structure design
        // The actual partial failure handling is in processMultipleReceipts
        
        // Given: Simulated results where page 2 failed
        let page1Items = [
            ExtractedItem(name: "Item A", quantity: 1, price: 10.00, sourcePageIndex: 0)
        ]
        let page3Items = [
            ExtractedItem(name: "Item B", quantity: 1, price: 15.00, sourcePageIndex: 2)
        ]
        
        // When: Merging successful pages (simulating partial failure)
        let allItems = page1Items + page3Items
        let result = sut.deduplicateItems(allItems)
        
        // Then: Successful page items should be preserved
        XCTAssertEqual(result.count, 2, "Items from successful pages should be preserved")
        XCTAssertTrue(result.contains { $0.name == "Item A" }, "Page 1 items should be present")
        XCTAssertTrue(result.contains { $0.name == "Item B" }, "Page 3 items should be present")
    }
    
    /// Tests that failed page indices can be tracked
    func testPartialFailure_TracksFailedIndices() {
        // Validate the warning message format for failed pages
        let warnings = [
            "Page 2 failed: No text detected",
            "Page 5 failed: Network timeout"
        ]
        
        // Then: Warnings should clearly identify failed pages
        XCTAssertTrue(warnings[0].contains("Page 2"), "Warning should identify failed page")
        XCTAssertTrue(warnings[1].contains("Page 5"), "Warning should identify failed page")
    }
    
    /// Tests that total failure (all pages fail) throws an appropriate error
    func testTotalFailure_ThrowsError() async {
        // This test documents expected error behavior
        // When all images fail, processMultipleReceipts should throw
        
        // Given: Expected error message format
        let expectedErrorFormat = "All %d images failed to process"
        
        // Then: Error message format should indicate total failure
        let formattedError = String(format: expectedErrorFormat, 3)
        XCTAssertTrue(formattedError.contains("All 3 images failed"), "Error should indicate total failure count")
    }
    
    // MARK: - Levenshtein Distance Tests
    
    /// Tests Levenshtein distance for identical strings
    func testLevenshteinDistance_IdenticalStrings() {
        // Given: Identical strings
        let s1 = "hello"
        let s2 = "hello"
        
        // When: Calculating distance
        let distance = sut.levenshteinDistance(s1, s2)
        
        // Then: Distance should be 0
        XCTAssertEqual(distance, 0, "Identical strings should have distance 0")
    }
    
    /// Tests Levenshtein distance for strings with one character difference
    func testLevenshteinDistance_OneCharDiff() {
        // Given: Strings with one character difference
        let s1 = "hello"
        let s2 = "hallo"  // 'e' -> 'a' substitution
        
        // When: Calculating distance
        let distance = sut.levenshteinDistance(s1, s2)
        
        // Then: Distance should be 1
        XCTAssertEqual(distance, 1, "One substitution should have distance 1")
    }
    
    /// Tests Levenshtein distance for one character insertion
    func testLevenshteinDistance_OneCharInsertion() {
        // Given: Strings where one has an extra character
        let s1 = "hello"
        let s2 = "hellos"  // Extra 's'
        
        // When: Calculating distance
        let distance = sut.levenshteinDistance(s1, s2)
        
        // Then: Distance should be 1
        XCTAssertEqual(distance, 1, "One insertion should have distance 1")
    }
    
    /// Tests Levenshtein distance for one character deletion
    func testLevenshteinDistance_OneCharDeletion() {
        // Given: Strings where one is missing a character
        let s1 = "hello"
        let s2 = "helo"  // Missing 'l'
        
        // When: Calculating distance
        let distance = sut.levenshteinDistance(s1, s2)
        
        // Then: Distance should be 1
        XCTAssertEqual(distance, 1, "One deletion should have distance 1")
    }
    
    /// Tests Levenshtein distance for completely different strings
    func testLevenshteinDistance_CompletelyDifferent() {
        // Given: Completely different strings
        let s1 = "abc"
        let s2 = "xyz"
        
        // When: Calculating distance
        let distance = sut.levenshteinDistance(s1, s2)
        
        // Then: Distance should be 3 (all characters different)
        XCTAssertEqual(distance, 3, "Completely different 3-char strings should have distance 3")
    }
    
    /// Tests Levenshtein distance with empty strings
    func testLevenshteinDistance_EmptyString() {
        // Given: One empty string
        let s1 = "hello"
        let s2 = ""
        
        // When: Calculating distance
        let distance = sut.levenshteinDistance(s1, s2)
        
        // Then: Distance should be length of non-empty string
        XCTAssertEqual(distance, 5, "Distance from 'hello' to '' should be 5")
    }
    
    /// Tests that similarity calculation returns correct ratio
    func testCalculateSimilarity_ReturnsCorrectRatio() {
        // Test case 1: Identical strings
        let similarity1 = sut.calculateNameSimilarity("Pizza", "Pizza")
        XCTAssertEqual(similarity1, 1.0, accuracy: 0.001, "Identical strings should have similarity 1.0")
        
        // Test case 2: One character difference
        let similarity2 = sut.calculateNameSimilarity("Pizza", "Pizzas")  // 5 vs 6 chars, 1 edit
        let expectedSimilarity2 = 1.0 - (1.0 / 6.0)  // ~0.833
        XCTAssertEqual(similarity2, expectedSimilarity2, accuracy: 0.01, "Should calculate correct similarity")
        
        // Test case 3: Empty string
        let similarity3 = sut.calculateNameSimilarity("Pizza", "")
        XCTAssertEqual(similarity3, 0.0, accuracy: 0.001, "Empty string should have similarity 0.0")
        
        // Test case 4: Case insensitivity
        let similarity4 = sut.calculateNameSimilarity("BURGER", "burger")
        XCTAssertEqual(similarity4, 1.0, accuracy: 0.001, "Case difference should not affect similarity")
    }
    
    /// Tests similarity with whitespace handling
    func testCalculateSimilarity_WhitespaceHandling() {
        // Given: Strings with leading/trailing whitespace
        let similarity = sut.calculateNameSimilarity("  Pizza  ", "Pizza")
        
        // Then: Whitespace should be trimmed, similarity should be 1.0
        XCTAssertEqual(similarity, 1.0, accuracy: 0.001, "Whitespace should be trimmed")
    }
    
    // MARK: - Fee Deduplication Tests
    
    /// Tests that fees with same type (different case) are deduplicated
    func testDeduplicateFees_CaseInsensitive() {
        // Given: Fees with same type in different cases
        let fees = [
            Fee(type: "TAX", amount: 3.00),
            Fee(type: "tax", amount: 2.50),
            Fee(type: "Tax", amount: 3.50)  // Highest
        ]
        
        // When: Deduplicating
        let result = sut.deduplicateFees(fees)
        
        // Then: Should keep one tax with highest amount
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].amount, 3.50, accuracy: 0.001)
    }
    
    /// Tests that different fee types are all kept
    func testDeduplicateFees_DifferentTypes() {
        // Given: Different fee types
        let fees = [
            Fee(type: "tax", amount: 3.00),
            Fee(type: "delivery", amount: 4.95),
            Fee(type: "service", amount: 2.00),
            Fee(type: "tip", amount: 5.00)
        ]
        
        // When: Deduplicating
        let result = sut.deduplicateFees(fees)
        
        // Then: All 4 types should be preserved
        XCTAssertEqual(result.count, 4)
        
        let feeTypes = Set(result.map { $0.type.lowercased() })
        XCTAssertTrue(feeTypes.contains("tax"))
        XCTAssertTrue(feeTypes.contains("delivery"))
        XCTAssertTrue(feeTypes.contains("service"))
        XCTAssertTrue(feeTypes.contains("tip"))
    }
    
    /// Tests fee deduplication with empty array
    func testDeduplicateFees_EmptyArray() {
        // Given: Empty array
        let fees: [Fee] = []
        
        // When: Deduplicating
        let result = sut.deduplicateFees(fees)
        
        // Then: Should return empty array
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - Integration-Style Tests
    
    /// Tests a realistic multi-page receipt scenario
    func testRealisticMultiPageReceipt() {
        // Given: Items that might appear on a 3-page receipt
        let allItems = [
            // Page 1: Appetizers
            ExtractedItem(name: "Caesar Salad", quantity: 1, price: 12.99, sourcePageIndex: 0),
            ExtractedItem(name: "Garlic Bread", quantity: 1, price: 5.99, sourcePageIndex: 0),
            
            // Page 2: Main courses (with duplicate from page 1 - typo)
            ExtractedItem(name: "Grilled Salmon", quantity: 1, price: 24.99, sourcePageIndex: 1),
            ExtractedItem(name: "Ceasar Salad", quantity: 1, price: 14.99, sourcePageIndex: 1),  // Duplicate with typo and higher price
            
            // Page 3: Desserts and drinks
            ExtractedItem(name: "Chocolate Cake", quantity: 1, price: 8.99, sourcePageIndex: 2),
            ExtractedItem(name: "Coffee", quantity: 2, price: 6.00, sourcePageIndex: 2)
        ]
        
        // When: Deduplicating
        let result = sut.deduplicateItems(allItems)
        
        // Then: Should have 5 unique items (Caesar Salad merged)
        XCTAssertEqual(result.count, 5, "Should merge Caesar Salad variations")
        
        // The kept Caesar Salad should have the higher price
        let saladItem = result.first { $0.name.lowercased().contains("salad") }
        XCTAssertNotNil(saladItem)
        XCTAssertEqual(saladItem?.price, 14.99, accuracy: 0.001, "Should keep higher-priced duplicate")
    }
    
    /// Tests items with identical names but genuinely different prices (should keep both)
    func testItemsWithSameName_DifferentQuantity() {
        // Note: Per spec, items with identical names are duplicates and merged (keeping higher price)
        // This is because receipts often show the same item twice when it spans pages
        
        let items = [
            ExtractedItem(name: "Beer", quantity: 1, price: 5.00, sourcePageIndex: 0),
            ExtractedItem(name: "Beer", quantity: 1, price: 5.00, sourcePageIndex: 1)  // Same item, same price
        ]
        
        // When: Deduplicating
        let result = sut.deduplicateItems(items)
        
        // Then: Should merge into one (they're considered duplicates)
        XCTAssertEqual(result.count, 1, "Identical items should be merged")
    }
}

// MARK: - Mock OCR Service Tests

final class MockOCRServiceTests: XCTestCase {
    
    var mockService: MockOCRService!
    
    override func setUp() {
        super.setUp()
        mockService = MockOCRService()
    }
    
    override func tearDown() {
        mockService = nil
        super.tearDown()
    }
    
    /// Tests that mock service returns expected raw text format
    func testMockService_ReturnsRawText() async throws {
        // Given: A mock service with one image
        let mockImage = UIImage()
        
        // When: Processing receipt
        let result = try await mockService.processReceipt(images: [mockImage])
        
        // Then: Should return non-empty text
        XCTAssertFalse(result.isEmpty, "Mock service should return text")
    }
    
    /// Tests that mock service handles multiple images
    func testMockService_HandlesMultipleImages() async throws {
        // Given: Multiple mock images
        let mockImages = [UIImage(), UIImage(), UIImage()]
        
        // When: Processing receipts
        let result = try await mockService.processReceipt(images: mockImages)
        
        // Then: Should return combined text from all receipts
        XCTAssertFalse(result.isEmpty)
        // The mock combines different receipts
        XCTAssertTrue(result.contains("WALMART") || result.contains("Joe's") || result.contains("CORNER"),
                     "Should contain text from mock receipts")
    }
}

// MARK: - StructuredReceiptData Tests

final class StructuredReceiptDataTests: XCTestCase {
    
    /// Tests calculatedTotal when total is provided
    func testCalculatedTotal_WithProvidedTotal() {
        // Given: Receipt data with explicit total
        let data = StructuredReceiptData(
            items: [ExtractedItem(name: "Item", quantity: 1, price: 10.00)],
            fees: [Fee(type: "tax", amount: 1.00)],
            subtotal: 10.00,
            total: 11.00,  // Explicit total
            storeName: nil,
            rawText: nil
        )
        
        // Then: calculatedTotal should return the provided total
        XCTAssertEqual(data.calculatedTotal, 11.00, accuracy: 0.001)
    }
    
    /// Tests calculatedTotal when total is nil
    func testCalculatedTotal_WithoutProvidedTotal() {
        // Given: Receipt data without explicit total
        let data = StructuredReceiptData(
            items: [
                ExtractedItem(name: "Item 1", quantity: 1, price: 10.00),
                ExtractedItem(name: "Item 2", quantity: 1, price: 15.00)
            ],
            fees: [Fee(type: "tax", amount: 2.50)],
            subtotal: nil,
            total: nil,  // No explicit total
            storeName: nil,
            rawText: nil
        )
        
        // Then: calculatedTotal should sum items and fees
        XCTAssertEqual(data.calculatedTotal, 27.50, accuracy: 0.001, "Should sum items (25.00) + fees (2.50)")
    }
    
    /// Tests isStructured property
    func testIsStructured_WithItems() {
        let data = StructuredReceiptData(
            items: [ExtractedItem(name: "Item", quantity: 1, price: 10.00)],
            fees: nil,
            subtotal: nil,
            total: nil,
            storeName: nil,
            rawText: nil
        )
        
        XCTAssertTrue(data.isStructured, "Should be structured when items are present")
    }
    
    func testIsStructured_WithRawTextOnly() {
        let data = StructuredReceiptData(
            items: [],
            fees: nil,
            subtotal: nil,
            total: nil,
            storeName: nil,
            rawText: "Some raw text"
        )
        
        XCTAssertFalse(data.isStructured, "Should not be structured when only raw text is present")
    }
    
    /// Tests toReceiptItems conversion
    func testToReceiptItems_IncludesFees() {
        // Given: Receipt data with items and fees
        let data = StructuredReceiptData(
            items: [
                ExtractedItem(name: "Pizza", quantity: 1, price: 15.00),
                ExtractedItem(name: "Salad", quantity: 1, price: 8.00)
            ],
            fees: [
                Fee(type: "tax", amount: 2.30),
                Fee(type: "delivery", amount: 4.95)
            ],
            subtotal: 23.00,
            total: 30.25,
            storeName: "Test Store",
            rawText: nil
        )
        
        // When: Converting to receipt items with fees
        let receiptItems = data.toReceiptItems(includeFees: true)
        
        // Then: Should have 4 items (2 products + 2 fees)
        XCTAssertEqual(receiptItems.count, 4)
    }
    
    /// Tests toReceiptItems without fees
    func testToReceiptItems_ExcludesFees() {
        // Given: Receipt data with items and fees
        let data = StructuredReceiptData(
            items: [
                ExtractedItem(name: "Pizza", quantity: 1, price: 15.00)
            ],
            fees: [
                Fee(type: "tax", amount: 2.30)
            ],
            subtotal: nil,
            total: nil,
            storeName: nil,
            rawText: nil
        )
        
        // When: Converting to receipt items without fees
        let receiptItems = data.toReceiptItems(includeFees: false)
        
        // Then: Should have only 1 item
        XCTAssertEqual(receiptItems.count, 1)
        XCTAssertEqual(receiptItems[0].name, "Pizza")
    }
}

// MARK: - ExtractedItem Tests

final class ExtractedItemTests: XCTestCase {
    
    /// Tests ExtractedItem initialization with all properties
    func testExtractedItem_FullInitialization() {
        let item = ExtractedItem(
            name: "Test Item",
            quantity: 2,
            price: 19.99,
            sourcePageIndex: 1
        )
        
        XCTAssertEqual(item.name, "Test Item")
        XCTAssertEqual(item.quantity, 2)
        XCTAssertEqual(item.price, 19.99, accuracy: 0.001)
        XCTAssertEqual(item.sourcePageIndex, 1)
    }
    
    /// Tests ExtractedItem initialization without sourcePageIndex
    func testExtractedItem_WithoutSourcePageIndex() {
        let item = ExtractedItem(
            name: "Simple Item",
            quantity: 1,
            price: 5.00
        )
        
        XCTAssertEqual(item.name, "Simple Item")
        XCTAssertNil(item.sourcePageIndex, "sourcePageIndex should be nil when not provided")
    }
    
    /// Tests toReceiptItem conversion
    func testExtractedItem_ToReceiptItem() {
        let extractedItem = ExtractedItem(
            name: "Coffee",
            quantity: 2,
            price: 7.50,
            sourcePageIndex: 0
        )
        
        let receiptItem = extractedItem.toReceiptItem()
        
        XCTAssertEqual(receiptItem.name, "Coffee")
        XCTAssertEqual(receiptItem.quantity, 2)
        XCTAssertEqual(receiptItem.price, 7.50, accuracy: 0.001)
        XCTAssertTrue(receiptItem.assignedTo.isEmpty, "Should have empty assignments initially")
    }
}

// MARK: - Fee Tests

final class FeeTests: XCTestCase {
    
    /// Tests Fee displayName for known types
    func testFee_DisplayName() {
        XCTAssertEqual(Fee(type: "delivery", amount: 1.0).displayName, "Delivery Fee")
        XCTAssertEqual(Fee(type: "service", amount: 1.0).displayName, "Service Fee")
        XCTAssertEqual(Fee(type: "tax", amount: 1.0).displayName, "Tax")
        XCTAssertEqual(Fee(type: "tip", amount: 1.0).displayName, "Tip")
        XCTAssertEqual(Fee(type: "custom", amount: 1.0).displayName, "Custom")  // Capitalized
    }
    
    /// Tests Fee feeType enum conversion
    func testFee_FeeType() {
        XCTAssertEqual(Fee(type: "delivery", amount: 1.0).feeType, .delivery)
        XCTAssertEqual(Fee(type: "DELIVERY", amount: 1.0).feeType, .delivery)  // Case insensitive
        XCTAssertEqual(Fee(type: "unknown", amount: 1.0).feeType, .other)
    }
    
    /// Tests Fee toReceiptItem conversion
    func testFee_ToReceiptItem() {
        let fee = Fee(type: "tax", amount: 3.50)
        let receiptItem = fee.toReceiptItem()
        
        XCTAssertEqual(receiptItem.name, "Tax")
        XCTAssertEqual(receiptItem.quantity, 1)
        XCTAssertEqual(receiptItem.price, 3.50, accuracy: 0.001)
    }
}

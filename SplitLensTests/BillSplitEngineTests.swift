//
//  BillSplitEngineTests.swift
//  SplitLensTests
//
//  Comprehensive unit tests for bill splitting calculations
//

import XCTest
@testable import SplitLens

final class BillSplitEngineTests: XCTestCase {
    
    var engine: BillSplitEngine!
    
    override func setUp() {
        super.setUp()
        engine = BillSplitEngine()
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Basic Split Tests
    
    func testEqualSplits() throws {
        // Test simple 50/50 split between two people
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 20.00, assignedTo: ["Alice", "Bob"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 20.00,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // Bob owes Alice $10.00 (half of $20)
        XCTAssertEqual(result.splits.count, 1)
        XCTAssertEqual(result.splits[0].from, "Bob")
        XCTAssertEqual(result.splits[0].to, "Alice")
        XCTAssertEqual(result.splits[0].amount, 10.00, accuracy: 0.01)
        XCTAssertFalse(result.hasWarnings)
    }
    
    func testMultiPersonItems() throws {
        // Test: Pizza costs $24, shared by Alice, Bob, Carol
        // Each person pays: $24 / 3 = $8.00
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 24.00, assignedTo: ["Alice", "Bob", "Carol"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol"],
            totalAmount: 24.00,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // Bob and Carol each owe Alice $8.00
        XCTAssertEqual(result.splits.count, 2)
        
        let bobSplit = result.splits.first { $0.from == "Bob" }
        let carolSplit = result.splits.first { $0.from == "Carol" }
        
        XCTAssertNotNil(bobSplit)
        XCTAssertNotNil(carolSplit)
        XCTAssertEqual(bobSplit?.amount, 8.00, accuracy: 0.01)
        XCTAssertEqual(carolSplit?.amount, 8.00, accuracy: 0.01)
    }
    
    func testAllAssignments() throws {
        // Test: Tax $5, assigned to "All" (4 participants)
        // Each person pays: $5 / 4 = $1.25
        let items = [
            ReceiptItem(name: "Tax", quantity: 1, price: 5.00, assignedTo: ["All"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol", "David"],
            totalAmount: 5.00,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // 3 people owe Alice $1.25 each
        XCTAssertEqual(result.splits.count, 3)
        
        for split in result.splits {
            XCTAssertEqual(split.amount, 1.25, accuracy: 0.01)
            XCTAssertTrue(split.explanation.contains("All"))
        }
    }
    
    func testQuantityHandling() throws {
        // Test: 3 Beers at $5 each = $15 total, assigned to Bob
        let items = [
            ReceiptItem(name: "Beer", quantity: 3, price: 5.00, assignedTo: ["Bob"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 15.00,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // Bob owes Alice $15.00 (3 × $5)
        XCTAssertEqual(result.splits.count, 1)
        XCTAssertEqual(result.splits[0].from, "Bob")
        XCTAssertEqual(result.splits[0].amount, 15.00, accuracy: 0.01)
        XCTAssertTrue(result.splits[0].explanation.contains("×3"))
    }
    
    func testRoundingAccuracy() throws {
        // Test: $10 split 3 ways = $3.33, $3.33, $3.34
        // Should round to 2 decimal places
        let items = [
            ReceiptItem(name: "Item", quantity: 1, price: 10.00, assignedTo: ["Alice", "Bob", "Carol"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol"],
            totalAmount: 10.00,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // Each person should owe $3.33 (rounded)
        for split in result.splits {
            XCTAssertEqual(split.amount, 3.33, accuracy: 0.01)
            // Verify amount has at most 2 decimal places
            let amountString = String(format: "%.2f", split.amount)
            XCTAssertEqual(Double(amountString), split.amount)
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testSingleParticipant() throws {
        // Edge case: Only one participant (no splits needed)
        let items = [
            ReceiptItem(name: "Coffee", quantity: 1, price: 5.00, assignedTo: ["Alice"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice"],
            totalAmount: 5.00,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // No splits, but should have warning
        XCTAssertEqual(result.splits.count, 0)
        XCTAssertTrue(result.hasWarnings)
        XCTAssertTrue(result.warnings.contains(where: {
            if case .singleParticipant = $0.type { return true }
            return false
        }))
    }
    
    func testZeroAmounts() throws {
        // Test: Amounts < $0.01 are filtered out
        let items = [
            ReceiptItem(name: "Tiny Item", quantity: 1, price: 0.005, assignedTo: ["Bob"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 0.01,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // Should have no splits (amount too small)
        XCTAssertEqual(result.splits.count, 0)
    }
    
    func testPayerOnlyParticipant() throws {
        // Edge case: Payer is the only one who ordered items
        let items = [
            ReceiptItem(name: "Steak", quantity: 1, price: 30.00, assignedTo: ["Alice"]),
            ReceiptItem(name: "Wine", quantity: 1, price: 15.00, assignedTo: ["Alice"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 45.00,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // Bob owes nothing (didn't order anything)
        XCTAssertEqual(result.splits.count, 0)
    }
    
    func testUnassignedItems() throws {
        // Test: Warning for unassigned items
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 20.00, assignedTo: ["Alice", "Bob"]),
            ReceiptItem(name: "Dessert", quantity: 1, price: 8.00, assignedTo: []) // Unassigned
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 28.00,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // Should have warning about unassigned items
        XCTAssertTrue(result.hasWarnings)
        XCTAssertTrue(result.warnings.contains(where: {
            if case .unassignedItems = $0.type { return true }
            return false
        }))
    }
    
    // MARK: - Validation Tests
    
    func testTotalValidation_WithinTolerance() throws {
        // Test: Calculated total matches within 1% variance (no warning)
        let items = [
            ReceiptItem(name: "Item", quantity: 1, price: 100.00, assignedTo: ["Alice", "Bob"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 100.50, // 0.5% variance
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // Should NOT have variance warning (within 1%)
        XCTAssertFalse(result.warnings.contains(where: {
            if case .totalVariance = $0.type { return true }
            return false
        }))
    }
    
    func testTotalValidation_ExceedsTolerance() throws {
        // Test: Calculated total exceeds 1% variance (show warning)
        let items = [
            ReceiptItem(name: "Item", quantity: 1, price: 100.00, assignedTo: ["Alice", "Bob"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 110.00, // 10% variance
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // Should have variance warning (> 1%)
        XCTAssertTrue(result.hasWarnings)
        XCTAssertTrue(result.warnings.contains(where: {
            if case .totalVariance(let calc, let exp, let var) = $0.type {
                return var > 1.0
            }
            return false
        }))
    }
    
    func testValidation_NoParticipants() {
        let session = ReceiptSession(
            participants: [],
            totalAmount: 10.00,
            paidBy: "",
            items: []
        )
        
        XCTAssertThrowsError(try engine.computeSplits(session: session)) { error in
            if case BillSplitError.noParticipants = error {
                // Expected
            } else {
                XCTFail("Expected noParticipants error")
            }
        }
    }
    
    func testValidation_NoItems() {
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 0.00,
            paidBy: "Alice",
            items: []
        )
        
        XCTAssertThrowsError(try engine.computeSplits(session: session)) { error in
            if case BillSplitError.noItems = error {
                // Expected
            } else {
                XCTFail("Expected noItems error")
            }
        }
    }
    
    func testValidation_InvalidPayer() {
        let items = [
            ReceiptItem(name: "Item", quantity: 1, price: 10.00, assignedTo: ["Alice"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 10.00,
            paidBy: "Charlie", // Not in participants
            items: items
        )
        
        XCTAssertThrowsError(try engine.computeSplits(session: session)) { error in
            if case BillSplitError.invalidPayer = error {
                // Expected
            } else {
                XCTFail("Expected invalidPayer error")
            }
        }
    }
    
    // MARK: - Complex Scenario Tests
    
    func testComplexScenario() throws {
        // Mix of individual items, shared items, and "All" items
        let items = [
            ReceiptItem(name: "Alice's Salad", quantity: 1, price: 12.00, assignedTo: ["Alice"]),
            ReceiptItem(name: "Bob's Burger", quantity: 1, price: 15.00, assignedTo: ["Bob"]),
            ReceiptItem(name: "Shared Pizza", quantity: 1, price: 24.00, assignedTo: ["Alice", "Bob", "Carol"]),
            ReceiptItem(name: "Tax", quantity: 1, price: 5.10, assignedTo: ["All"]),
            ReceiptItem(name: "Tip", quantity: 1, price: 10.00, assignedTo: ["All"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol"],
            totalAmount: 66.10,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        
        // Verify splits exist
        XCTAssertEqual(result.splits.count, 2) // Bob and Carol owe Alice
        
        // Bob's calculation:
        // - Burger: $15.00
        // - Pizza: $24 / 3 = $8.00
        // - Tax: $5.10 / 3 = $1.70
        // - Tip: $10 / 3 = $3.33
        // Total: $28.03
        let bobSplit = result.splits.first { $0.from == "Bob" }
        XCTAssertNotNil(bobSplit)
        XCTAssertEqual(bobSplit?.amount ?? 0, 28.03, accuracy: 0.01)
        
        // Carol's calculation:
        // - Pizza: $24 / 3 = $8.00
        // - Tax: $5.10 / 3 = $1.70
        // - Tip: $10 / 3 = $3.33
        // Total: $13.03
        let carolSplit = result.splits.first { $0.from == "Carol" }
        XCTAssertNotNil(carolSplit)
        XCTAssertEqual(carolSplit?.amount ?? 0, 13.03, accuracy: 0.01)
        
        // Verify explanations are detailed
        XCTAssertTrue(bobSplit?.explanation.contains("÷") ?? false)
        XCTAssertTrue(carolSplit?.explanation.contains("÷") ?? false)
    }
    
    func testExplanationFormat() throws {
        // Verify explanation format matches Part 3 requirements
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 24.00, assignedTo: ["Alice", "Bob", "Carol"])
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol"],
            totalAmount: 24.00,
            paidBy: "Alice",
            items: items
        )
        
        let result = try engine.computeSplits(session: session)
        let bobSplit = result.splits.first { $0.from == "Bob" }
        
        // Explanation should be: "Pizza: $24.00 ÷ 3 = $8.00"
        XCTAssertTrue(bobSplit?.explanation.contains("Pizza: $24.0") ?? false)
        XCTAssertTrue(bobSplit?.explanation.contains("÷ 3 =") ?? false)
        XCTAssertTrue(bobSplit?.explanation.contains("$8.0") ?? false)
    }
}

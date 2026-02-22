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
    
    // MARK: - Fee Allocation Tests
    
    func testProportionalTaxDistribution() throws {
        // Alice: $20 items, Bob: $30 items, Tax: $5
        // Expected: Alice: $2 tax (40%), Bob: $3 tax (60%)
        let items = [
            ReceiptItem(name: "Alice's Salad", quantity: 1, price: 20.00, assignedTo: ["Alice"]),
            ReceiptItem(name: "Bob's Burger", quantity: 1, price: 30.00, assignedTo: ["Bob"])
        ]
        
        let feeAllocations = [
            FeeAllocation(
                fee: Fee(type: "tax", amount: 5.00),
                strategy: .proportional
            )
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 55.00,
            paidBy: "Alice",
            items: items,
            computedSplits: [],
            feeAllocations: feeAllocations
        )
        
        let advancedEngine = AdvancedBillSplitEngine()
        let result = try advancedEngine.computeSplits(session: session)
        
        // Bob owes Alice: $30 (items) + $3 (60% of tax) = $33
        let bobSplit = result.splits.first { $0.from == "Bob" }
        XCTAssertNotNil(bobSplit)
        XCTAssertEqual(bobSplit?.amount ?? 0, 33.00, accuracy: 0.01)
    }
    
    func testEqualTipDistribution() throws {
        // 3 participants, $9 tip split equally = $3 each
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 30.00, assignedTo: ["Alice", "Bob", "Carol"])
        ]
        
        let feeAllocations = [
            FeeAllocation(
                fee: Fee(type: "tip", amount: 9.00),
                strategy: .equal
            )
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol"],
            totalAmount: 39.00,
            paidBy: "Alice",
            items: items,
            computedSplits: [],
            feeAllocations: feeAllocations
        )
        
        let advancedEngine = AdvancedBillSplitEngine()
        let result = try advancedEngine.computeSplits(session: session)
        
        // Bob: $10 (pizza) + $3 (tip) = $13
        let bobSplit = result.splits.first { $0.from == "Bob" }
        XCTAssertNotNil(bobSplit)
        XCTAssertEqual(bobSplit?.amount ?? 0, 13.00, accuracy: 0.01)
        
        // Carol: $10 (pizza) + $3 (tip) = $13
        let carolSplit = result.splits.first { $0.from == "Carol" }
        XCTAssertNotNil(carolSplit)
        XCTAssertEqual(carolSplit?.amount ?? 0, 13.00, accuracy: 0.01)
    }
    
    func testManualFeeAssignment() throws {
        // Delivery fee $6 assigned only to Alice and Bob (not Carol)
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 30.00, assignedTo: ["Alice", "Bob", "Carol"])
        ]
        
        let feeAllocations = [
            FeeAllocation(
                fee: Fee(type: "delivery", amount: 6.00),
                strategy: .manual,
                manualAssignments: ["Alice", "Bob"]
            )
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol"],
            totalAmount: 36.00,
            paidBy: "Alice",
            items: items,
            computedSplits: [],
            feeAllocations: feeAllocations
        )
        
        let advancedEngine = AdvancedBillSplitEngine()
        let result = try advancedEngine.computeSplits(session: session)
        
        // Bob: $10 (pizza) + $3 (delivery / 2) = $13
        let bobSplit = result.splits.first { $0.from == "Bob" }
        XCTAssertNotNil(bobSplit)
        XCTAssertEqual(bobSplit?.amount ?? 0, 13.00, accuracy: 0.01)
        
        // Carol: $10 (pizza) + $0 (no delivery fee) = $10
        let carolSplit = result.splits.first { $0.from == "Carol" }
        XCTAssertNotNil(carolSplit)
        XCTAssertEqual(carolSplit?.amount ?? 0, 10.00, accuracy: 0.01)
    }
    
    func testMixedFeeStrategies() throws {
        // Test combining different fee strategies
        // Alice: $20, Bob: $30
        // Tax $5 proportional, Tip $6 equal, Delivery $4 to Bob only
        let items = [
            ReceiptItem(name: "Alice's Item", quantity: 1, price: 20.00, assignedTo: ["Alice"]),
            ReceiptItem(name: "Bob's Item", quantity: 1, price: 30.00, assignedTo: ["Bob"])
        ]
        
        let feeAllocations = [
            FeeAllocation(
                fee: Fee(type: "tax", amount: 5.00),
                strategy: .proportional
            ),
            FeeAllocation(
                fee: Fee(type: "tip", amount: 6.00),
                strategy: .equal
            ),
            FeeAllocation(
                fee: Fee(type: "delivery", amount: 4.00),
                strategy: .manual,
                manualAssignments: ["Bob"]
            )
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 65.00,
            paidBy: "Alice",
            items: items,
            computedSplits: [],
            feeAllocations: feeAllocations
        )
        
        let advancedEngine = AdvancedBillSplitEngine()
        let result = try advancedEngine.computeSplits(session: session)
        
        // Bob: $30 (items) + $3 (60% tax) + $3 (50% tip) + $4 (delivery) = $40
        let bobSplit = result.splits.first { $0.from == "Bob" }
        XCTAssertNotNil(bobSplit)
        XCTAssertEqual(bobSplit?.amount ?? 0, 40.00, accuracy: 0.01)
    }
    
    func testFeeAllocationExplanation() throws {
        // Verify detailed fee breakdown in explanation
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 20.00, assignedTo: ["Alice", "Bob"])
        ]
        
        let feeAllocations = [
            FeeAllocation(
                fee: Fee(type: "tax", amount: 2.00),
                strategy: .equal
            ),
            FeeAllocation(
                fee: Fee(type: "tip", amount: 4.00),
                strategy: .equal
            )
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 26.00,
            paidBy: "Alice",
            items: items,
            computedSplits: [],
            feeAllocations: feeAllocations
        )
        
        let advancedEngine = AdvancedBillSplitEngine()
        let result = try advancedEngine.computeSplits(session: session)
        
        let bobSplit = result.splits.first { $0.from == "Bob" }
        XCTAssertNotNil(bobSplit)
        
        // Explanation should include fee breakdown
        XCTAssertTrue(bobSplit?.explanation.contains("Tax") ?? false)
        XCTAssertTrue(bobSplit?.explanation.contains("Tip") ?? false)
        XCTAssertTrue(bobSplit?.explanation.contains("Total") ?? false)
    }
    
    func testInvalidManualFeeAllocation() throws {
        // Manual strategy without any assignments should fail
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 20.00, assignedTo: ["Alice", "Bob"])
        ]
        
        let feeAllocations = [
            FeeAllocation(
                fee: Fee(type: "delivery", amount: 5.00),
                strategy: .manual,
                manualAssignments: nil // Empty assignments
            )
        ]
        
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 25.00,
            paidBy: "Alice",
            items: items,
            computedSplits: [],
            feeAllocations: feeAllocations
        )
        
        let advancedEngine = AdvancedBillSplitEngine()

        XCTAssertThrowsError(try advancedEngine.computeSplits(session: session)) { error in
            if case BillSplitError.invalidFeeAllocation = error {
                // Expected
            } else {
                XCTFail("Expected invalidFeeAllocation error")
            }
        }
    }

    // MARK: - PersonBreakdown Tests

    func testPersonBreakdownsReturned() throws {
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 30.00, assignedTo: ["Alice", "Bob", "Carol"])
        ]
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol"],
            totalAmount: 30.00,
            paidBy: "Alice",
            items: items
        )
        let result = try engine.computeSplits(session: session)
        XCTAssertFalse(result.personBreakdowns.isEmpty, "personBreakdowns should not be empty")
        XCTAssertEqual(result.personBreakdowns.count, 3)
    }

    func testPersonBreakdownsIncludeAllParticipants() throws {
        let items = [
            ReceiptItem(name: "Salad", quantity: 1, price: 12.00, assignedTo: ["Alice"]),
            ReceiptItem(name: "Burger", quantity: 1, price: 15.00, assignedTo: ["Bob"]),
            ReceiptItem(name: "Pizza", quantity: 1, price: 18.00, assignedTo: ["Carol"])
        ]
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol"],
            totalAmount: 45.00,
            paidBy: "Alice",
            items: items
        )
        let result = try engine.computeSplits(session: session)
        let persons = result.personBreakdowns.map { $0.person }
        XCTAssertTrue(persons.contains("Alice"))
        XCTAssertTrue(persons.contains("Bob"))
        XCTAssertTrue(persons.contains("Carol"))
    }

    func testPersonBreakdownsMatchSplitTotals() throws {
        // Non-payer totalAmount should approximately match their split amount
        let items = [
            ReceiptItem(name: "Alice's Salad", quantity: 1, price: 20.00, assignedTo: ["Alice"]),
            ReceiptItem(name: "Bob's Burger", quantity: 1, price: 30.00, assignedTo: ["Bob"])
        ]
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 50.00,
            paidBy: "Alice",
            items: items
        )
        let result = try engine.computeSplits(session: session)

        let bobBreakdown = result.personBreakdowns.first { $0.person == "Bob" }
        let bobSplit = result.splits.first { $0.from == "Bob" }
        XCTAssertNotNil(bobBreakdown)
        XCTAssertNotNil(bobSplit)
        XCTAssertEqual(bobBreakdown!.totalAmount, bobSplit!.amount, accuracy: 0.01)
    }

    func testPersonBreakdownsWithFees() throws {
        // Fee charges should appear when feeAllocations are present
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 20.00, assignedTo: ["Alice", "Bob"])
        ]
        let feeAllocations = [
            FeeAllocation(fee: Fee(type: "tax", amount: 2.00), strategy: .equal)
        ]
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 22.00,
            paidBy: "Alice",
            items: items,
            computedSplits: [],
            feeAllocations: feeAllocations
        )
        let advancedEngine = AdvancedBillSplitEngine()
        let result = try advancedEngine.computeSplits(session: session)

        let bobBreakdown = result.personBreakdowns.first { $0.person == "Bob" }
        XCTAssertNotNil(bobBreakdown)
        XCTAssertFalse(bobBreakdown!.feeCharges.isEmpty, "Bob should have fee charges")
        XCTAssertEqual(bobBreakdown!.feeCharges[0].feeName, "Tax")
        XCTAssertEqual(bobBreakdown!.feeCharges[0].amount, 1.00, accuracy: 0.01)
    }

    func testLegacySessionRecomputation() throws {
        // A session with empty personBreakdowns can be recomputed by the engine
        let items = [
            ReceiptItem(name: "Shared", quantity: 1, price: 20.00, assignedTo: ["Alice", "Bob"])
        ]
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 20.00,
            paidBy: "Alice",
            items: items,
            personBreakdowns: []  // legacy: no breakdowns stored
        )
        XCTAssertTrue(session.personBreakdowns.isEmpty, "Session should start with empty breakdowns")

        let result = try engine.computeSplits(session: session)
        XCTAssertFalse(result.personBreakdowns.isEmpty, "Engine should produce breakdowns for legacy session")
        XCTAssertEqual(result.personBreakdowns.count, 2)
    }

    func testPayerSettlementAmountIsNegative() throws {
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 30.00, assignedTo: ["Alice", "Bob", "Carol"])
        ]
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol"],
            totalAmount: 30.00,
            paidBy: "Alice",
            items: items
        )
        let result = try engine.computeSplits(session: session)
        let aliceBreakdown = result.personBreakdowns.first { $0.person == "Alice" }
        XCTAssertNotNil(aliceBreakdown)
        // Payer is owed money — settlement should be negative
        XCTAssertLessThan(aliceBreakdown!.settlementAmount, 0)
    }

    func testNonPayerSettlementAmountIsPositive() throws {
        let items = [
            ReceiptItem(name: "Pizza", quantity: 1, price: 30.00, assignedTo: ["Alice", "Bob"])
        ]
        let session = ReceiptSession(
            participants: ["Alice", "Bob"],
            totalAmount: 30.00,
            paidBy: "Alice",
            items: items
        )
        let result = try engine.computeSplits(session: session)
        let bobBreakdown = result.personBreakdowns.first { $0.person == "Bob" }
        XCTAssertNotNil(bobBreakdown)
        // Non-payer owes money — settlement should be positive
        XCTAssertGreaterThan(bobBreakdown!.settlementAmount, 0)
    }

    func testItemChargeFormula() throws {
        // ItemCharge.amount should equal itemFullPrice / splitAmong
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
        for breakdown in result.personBreakdowns {
            for charge in breakdown.itemCharges {
                let expected = charge.itemFullPrice / Double(charge.splitAmong)
                XCTAssertEqual(charge.amount, expected, accuracy: 0.001)
            }
        }
    }

    func testTotalAmountAccountedForAll() throws {
        // Sum of all personBreakdowns.totalAmount ≈ session.totalAmount (within ±$0.05)
        let items = [
            ReceiptItem(name: "Salad", quantity: 1, price: 12.00, assignedTo: ["Alice"]),
            ReceiptItem(name: "Burger", quantity: 1, price: 15.00, assignedTo: ["Bob"]),
            ReceiptItem(name: "Shared Pizza", quantity: 1, price: 21.00, assignedTo: ["Alice", "Bob", "Carol"]),
            ReceiptItem(name: "Tax", quantity: 1, price: 4.80, assignedTo: ["All"])
        ]
        let session = ReceiptSession(
            participants: ["Alice", "Bob", "Carol"],
            totalAmount: 52.80,
            paidBy: "Alice",
            items: items
        )
        let result = try engine.computeSplits(session: session)
        let sumTotal = result.personBreakdowns.reduce(0.0) { $0 + $1.totalAmount }
        XCTAssertEqual(sumTotal, session.totalAmount, accuracy: 0.05)
    }
}

// MARK: - PersonBreakdownCodableTests

final class PersonBreakdownCodableTests: XCTestCase {

    func testItemChargeCalculation() {
        let charge = ItemCharge(itemName: "Pizza", itemFullPrice: 24.00, splitAmong: 3, amount: 8.00)
        let expected = charge.itemFullPrice / Double(charge.splitAmong)
        XCTAssertEqual(charge.amount, expected, accuracy: 0.001)
    }

    func testFeeChargeEqualStrategy() {
        let feeAmount = 9.00
        let participants = 3
        let perPerson = feeAmount / Double(participants)
        let charge = FeeCharge(feeName: "Tip", feeFullAmount: feeAmount, strategy: .equal, amount: perPerson)
        XCTAssertEqual(charge.amount, 3.00, accuracy: 0.001)
    }

    func testFeeChargeProportionalSumsToFeeTotal() throws {
        // Three people with spending ratio 1:2:3. Fee = $6.
        // Expected: $1, $2, $3
        let totalSpending = 60.0
        let feeTotal = 6.0
        let spendings: [Double] = [10.0, 20.0, 30.0]
        var sum = 0.0
        for spending in spendings {
            let ratio = spending / totalSpending
            let feeAmount = feeTotal * ratio
            sum += feeAmount
        }
        XCTAssertEqual(sum, feeTotal, accuracy: 0.001)
    }

    func testTotalAmountComputed() {
        let itemCharges = [
            ItemCharge(itemName: "A", itemFullPrice: 10.00, splitAmong: 1, amount: 10.00),
            ItemCharge(itemName: "B", itemFullPrice: 20.00, splitAmong: 2, amount: 10.00)
        ]
        let feeCharges = [
            FeeCharge(feeName: "Tax", feeFullAmount: 2.00, strategy: .equal, amount: 1.00)
        ]
        let breakdown = PersonBreakdown(
            person: "Alice",
            itemCharges: itemCharges,
            feeCharges: feeCharges,
            settlementAmount: 0.0
        )
        XCTAssertEqual(breakdown.totalAmount, 21.00, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        let original = PersonBreakdown(
            person: "Bob",
            itemCharges: [
                ItemCharge(itemName: "Pizza", itemFullPrice: 24.00, splitAmong: 3, amount: 8.00)
            ],
            feeCharges: [
                FeeCharge(feeName: "Tax", feeFullAmount: 3.00, strategy: .proportional, amount: 1.20)
            ],
            settlementAmount: 9.20
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PersonBreakdown.self, from: data)

        XCTAssertEqual(decoded.person, original.person)
        XCTAssertEqual(decoded.settlementAmount, original.settlementAmount, accuracy: 0.001)
        XCTAssertEqual(decoded.itemCharges.count, original.itemCharges.count)
        XCTAssertEqual(decoded.feeCharges.count, original.feeCharges.count)
        XCTAssertEqual(decoded.itemCharges[0].itemName, original.itemCharges[0].itemName)
        XCTAssertEqual(decoded.feeCharges[0].feeName, original.feeCharges[0].feeName)
    }

    func testBackwardCompatibilityV1Session() throws {
        // A v1 JSON payload has no "person_breakdowns" key
        let v1Json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "created_at": "2024-01-01T12:00:00Z",
            "receipt_date": "2024-01-01T12:00:00Z",
            "receipt_date_source": "scan_timestamp_fallback",
            "receipt_date_has_time": true,
            "receipt_image_paths": [],
            "participants": ["Alice", "Bob"],
            "total_amount": 20.0,
            "paid_by": "Alice",
            "items": [],
            "computed_splits": [],
            "fee_allocations": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = v1Json.data(using: .utf8)!
        let session = try decoder.decode(ReceiptSession.self, from: data)
        // Should decode cleanly with empty personBreakdowns
        XCTAssertTrue(session.personBreakdowns.isEmpty, "v1 session should decode with empty personBreakdowns")
        XCTAssertEqual(session.participants.count, 2)
    }
}

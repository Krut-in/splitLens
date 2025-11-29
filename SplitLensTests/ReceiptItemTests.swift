//
//  ReceiptItemTests.swift
//  SplitLensTests
//
//  Unit tests for ReceiptItem model edge cases
//

import XCTest
@testable import SplitLens

final class ReceiptItemTests: XCTestCase {
    
    // MARK: - Price Calculation Tests
    
    func testTotalPriceCalculation() {
        let item = ReceiptItem(name: "Beer", quantity: 3, price: 5.00, assignedTo: ["Alice"])
        
        // totalPrice = quantity × price = 3 × $5 = $15
        XCTAssertEqual(item.totalPrice, 15.00, accuracy: 0.01)
    }
    
    func testPricePerPersonCalculation_SinglePerson() {
        let item = ReceiptItem(name: "Burger", quantity: 1, price: 12.00, assignedTo: ["Alice"])
        
        // pricePerPerson = $12 / 1 = $12
        XCTAssertEqual(item.pricePerPerson, 12.00, accuracy: 0.01)
    }
    
    func testPricePerPersonCalculation_MultiplePeople() {
        let item = ReceiptItem(name: "Pizza", quantity: 1, price: 24.00, assignedTo: ["Alice", "Bob", "Carol"])
        
        // pricePerPerson = $24 / 3 = $8
        XCTAssertEqual(item.pricePerPerson, 8.00, accuracy: 0.01)
    }
    
    func testPricePerPersonCalculation_WithQuantity() {
        let item = ReceiptItem(name: "Soda", quantity: 4, price: 2.00, assignedTo: ["Alice", "Bob"])
        
        // totalPrice = 4 × $2 = $8
        // pricePerPerson = $8 / 2 = $4
        XCTAssertEqual(item.pricePerPerson, 4.00, accuracy: 0.01)
    }
    
    func testPricePerPersonCalculation_NoAssignment() {
        let item = ReceiptItem(name: "Item", quantity: 1, price: 10.00, assignedTo: [])
        
        // Not assigned to anyone, should return 0
        XCTAssertEqual(item.pricePerPerson, 0.00)
    }
    
    // MARK: - Assignment Tests
    
    func testAssignmentToggle() {
        var item = ReceiptItem(name: "Pizza", quantity: 1, price: 20.00, assignedTo: [])
        
        // Toggle on
        item.toggleAssignment(for: "Alice")
        XCTAssertTrue(item.isAssigned(to: "Alice"))
        XCTAssertEqual(item.sharingCount, 1)
        
        // Toggle off
        item.toggleAssignment(for: "Alice")
        XCTAssertFalse(item.isAssigned(to: "Alice"))
        XCTAssertEqual(item.sharingCount, 0)
    }
    
    func testAssignMultiplePeople() {
        var item = ReceiptItem(name: "Pizza", quantity: 1, price: 24.00, assignedTo: [])
        
        item.assign(to: "Alice")
        item.assign(to: "Bob")
        item.assign(to: "Carol")
        
        XCTAssertEqual(item.sharingCount, 3)
        XCTAssertTrue(item.isAssigned(to: "Alice"))
        XCTAssertTrue(item.isAssigned(to: "Bob"))
        XCTAssertTrue(item.isAssigned(to: "Carol"))
    }
    
    func testUnassign() {
        var item = ReceiptItem(
            name: "Pizza",
            quantity: 1,
            price: 24.00,
            assignedTo: ["Alice", "Bob", "Carol"]
        )
        
        item.unassign(from: "Bob")
        
        XCTAssertEqual(item.sharingCount, 2)
        XCTAssertTrue(item.isAssigned(to: "Alice"))
        XCTAssertFalse(item.isAssigned(to: "Bob"))
        XCTAssertTrue(item.isAssigned(to: "Carol"))
    }
    
    func testDuplicateAssignment() {
        var item = ReceiptItem(name: "Item", quantity: 1, price: 10.00, assignedTo: [])
        
        item.assign(to: "Alice")
        item.assign(to: "Alice") // Duplicate
        
        // Should only be assigned once
        XCTAssertEqual(item.sharingCount, 1)
    }
    
    // MARK: - Validation Tests
    
    func testIsValid_ValidItem() {
        let item = ReceiptItem(name: "Pizza", quantity: 1, price: 20.00, assignedTo: ["Alice"])
        XCTAssertTrue(item.isValid)
    }
    
    func testIsValid_EmptyName() {
        let item = ReceiptItem(name: "", quantity: 1, price: 20.00, assignedTo: ["Alice"])
        XCTAssertFalse(item.isValid)
    }
    
    func testIsValid_WhitespaceName() {
        let item = ReceiptItem(name: "   ", quantity: 1, price: 20.00, assignedTo: ["Alice"])
        XCTAssertFalse(item.isValid)
    }
    
    func testIsValid_ZeroQuantity() {
        let item = ReceiptItem(name: "Pizza", quantity: 0, price: 20.00, assignedTo: ["Alice"])
        XCTAssertFalse(item.isValid)
    }
    
    func testIsValid_NegativePrice() {
        let item = ReceiptItem(name: "Pizza", quantity: 1, price: -5.00, assignedTo: ["Alice"])
        XCTAssertFalse(item.isValid)
    }
    
    func testIsValid_ZeroPrice() {
        let item = ReceiptItem(name: "Free Item", quantity: 1, price: 0.00, assignedTo: ["Alice"])
        XCTAssertTrue(item.isValid) // Zero price is valid (free items)
    }
    
    // MARK: - Formatting Tests
    
    func testFormattedTotalPrice() {
        let item = ReceiptItem(name: "Item", quantity: 2, price: 5.50, assignedTo: ["Alice"])
        
        // totalPrice = 2 × $5.50 = $11.00
        XCTAssertTrue(item.formattedTotalPrice.contains("11.00"))
        XCTAssertTrue(item.formattedTotalPrice.contains("$"))
    }
    
    func testFormattedPricePerPerson_Single() {
        let item = ReceiptItem(name: "Item", quantity: 1, price: 10.00, assignedTo: ["Alice"])
        
        // Should show "$10.00" without "each"
        XCTAssertTrue(item.formattedPricePerPerson.contains("10.00"))
        XCTAssertFalse(item.formattedPricePerPerson.contains("each"))
    }
    
    func testFormattedPricePerPerson_Multiple() {
        let item = ReceiptItem(name: "Pizza", quantity: 1, price: 20.00, assignedTo: ["Alice", "Bob"])
        
        // Should show "$10.00 each"
        XCTAssertTrue(item.formattedPricePerPerson.contains("10.00"))
        XCTAssertTrue(item.formattedPricePerPerson.contains("each"))
    }
}

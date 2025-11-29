//
//  ItemsEditorViewModel.swift
//  SplitLens
//
//  ViewModel for editing receipt items
//

import Foundation
import SwiftUI

@MainActor
final class ItemsEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// List of receipt items
    @Published var items: [ReceiptItem] = []
    
    /// Total amount entered by user (may differ from calculated total)
    @Published var totalAmount: Double = 0.0
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Whether to show add item sheet
    @Published var showAddItemSheet = false
    
    // MARK: - Computed Properties
    
    /// Calculated total from all items
    var calculatedTotal: Double {
        items.reduce(0.0) { $0 + $1.totalPrice }
    }
    
    /// Formatted calculated total
    var formattedCalculatedTotal: String {
        formatCurrency(calculatedTotal)
    }
    
    /// Formatted entered total
    var formattedEnteredTotal: String {
        formatCurrency(totalAmount)
    }
    
    /// Difference between entered and calculated totals
    var totalDiscrepancy: Double {
        totalAmount - calculatedTotal
    }
    
    /// Whether there's a significant discrepancy
    var hasTotalDiscrepancy: Bool {
        abs(totalDiscrepancy) > 0.05
    }
    
    /// Discrepancy warning message
    var discrepancyWarning: String? {
        guard hasTotalDiscrepancy else { return nil }
        let diff = formatCurrency(abs(totalDiscrepancy))
        if totalDiscrepancy > 0 {
            return "Entered total is \(diff) more than items"
        } else {
            return "Entered total is \(diff) less than items"
        }
    }
    
    // MARK: - Initialization
    
    init(items: [ReceiptItem] = []) {
        self.items = items
        self.totalAmount = items.reduce(0.0) { $0 + $1.totalPrice }
    }
    
    // MARK: - Item Management
    
    /// Adds a new item
    func addItem(_ item: ReceiptItem) {
        items.append(item)
        recalculateTotal()
        errorMessage = nil
    }
    
    /// Adds a new item with provided details
    func addItem(name: String, quantity: Int, price: Double) {
        // Validate item name
        if let nameError = ValidationHelper.validateItemName(name) {
            errorMessage = nameError
            return
        }
        
        // Validate price
        if let priceError = ValidationHelper.validateItemPrice(price) {
            errorMessage = priceError
            return
        }
        
        let item = ReceiptItem(
            name: name,
            quantity: max(1, quantity),
            price: price
        )
        addItem(item)
    }
    
    /// Updates an existing item
    func updateItem(at index: Int, with updatedItem: ReceiptItem) {
        guard items.indices.contains(index) else { return }
        items[index] = updatedItem
        recalculateTotal()
    }
    
    /// Updates an item by ID
    func updateItem(id: UUID, with updatedItem: ReceiptItem) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        updateItem(at: index, with: updatedItem)
    }
    
    /// Deletes items at specified indices
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        recalculateTotal()
    }
    
    /// Deletes a specific item
    func deleteItem(_ item: ReceiptItem) {
        items.removeAll { $0.id == item.id }
        recalculateTotal()
    }
    
    /// Moves items (for reordering)
    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
    
    /// Clears all items
    func clearAllItems() {
        items = []
        totalAmount = 0.0
        errorMessage = nil
    }
    
    // MARK: - Total Management
    
    /// Updates the total amount
    func setTotal(_ amount: Double) {
        // Validate total amount
        if let totalError = ValidationHelper.validateTotalAmount(amount) {
            errorMessage = totalError
            return
        }
        
        totalAmount = max(0, amount)
        errorMessage = nil
    }
    
    /// Recalculates total based on items
    func recalculateTotal() {
        // Only auto-update if user hasn't manually set a different total
        if abs(totalAmount - calculatedTotal) < 0.01 {
            totalAmount = calculatedTotal
        }
    }
    
    /// Uses calculated total as the entered total
    func useCalculatedTotal() {
        totalAmount = calculatedTotal
        errorMessage = nil
    }
    
    // MARK: - Validation
    
    /// Validates the current state
    func validate() -> [String] {
        var errors: [String] = []
        
        if items.isEmpty {
            errors.append("Add at least one item")
        }
        
        for (index, item) in items.enumerated() {
            if !item.isValid {
                errors.append("Item \(index + 1) has invalid data")
            }
        }
        
        if totalAmount <= 0 {
            errors.append("Total amount must be greater than 0")
        }
        
        return errors
    }
    
    /// Whether the current state is valid
    var isValid: Bool {
        validate().isEmpty
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Double) -> String {
        CurrencyFormatter.shared.format(value)
    }
}

// MARK: - Item Creation Helper

extension ItemsEditorViewModel {
    /// Creates a default item for quick adding
    func createDefaultItem() -> ReceiptItem {
        ReceiptItem(
            name: "Item \(items.count + 1)",
            quantity: 1,
            price: 0.0
        )
    }
}

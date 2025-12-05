//
//  ItemsEditorView.swift
//  SplitLens
//
//  Edit receipt items with improved UX design
//

import SwiftUI

/// Screen for editing extracted receipt items
struct ItemsEditorView: View {
    // MARK: - Navigation
    
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel: ItemsEditorViewModel
    
    // MARK: - State
    
    @State private var showAddItemSheet = false
    @State private var editingItem: ReceiptItem?
    @FocusState private var focusedField: UUID?
    
    // MARK: - Initialization
    
    init(items: [ReceiptItem], navigationPath: Binding<NavigationPath>) {
        _viewModel = StateObject(wrappedValue: ItemsEditorViewModel(items: items))
        _navigationPath = navigationPath
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header section
            headerSection
            
            // Scrollable items list
            if viewModel.items.isEmpty {
                emptyStateView
            } else {
                itemsScrollView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Edit Items")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isValid {
                    Button("Next") {
                        navigationPath.append(Route.participantsEntry(viewModel.items))
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.green)
                }
            }
            
            ToolbarItem(placement: .bottomBar) {
                Button(action: {
                    showAddItemSheet = true
                }) {
                    Label("Add Item", systemImage: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showAddItemSheet) {
            AddItemSheet(viewModel: viewModel)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Total summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Items Total")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text(viewModel.formattedCalculatedTotal)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Item count badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(viewModel.items.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    
                    Text(viewModel.items.count == 1 ? "item" : "items")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 16)
            
            // Warning if applicable
            if let warning = viewModel.discrepancyWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(warning)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.orange.opacity(0.1))
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Items List
    
    private var itemsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach($viewModel.items) { $item in
                    ItemRowCard(
                        item: $item,
                        onDelete: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                viewModel.deleteItem(item)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 80) // Extra space for bottom toolbar
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "cart.badge.plus",
                message: "No items yet. Add your first item!",
                actionLabel: "Add Item"
            ) {
                showAddItemSheet = true
            }
            Spacer()
        }
    }
}

// MARK: - Item Row Card Component

struct ItemRowCard: View {
    @Binding var item: ReceiptItem
    let onDelete: () -> Void
    
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedPrice: String = ""
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case name, price
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 12) {
                // Item name row
                HStack {
                    if isEditing {
                        TextField("Item name", text: $editedName)
                            .font(.system(size: 16, weight: .semibold))
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.done)
                            .onSubmit { saveChanges() }
                    } else {
                        Text(item.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Edit/Save button
                    Button(action: {
                        if isEditing {
                            saveChanges()
                        } else {
                            startEditing()
                        }
                    }) {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isEditing ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                // Quantity and price row
                HStack(alignment: .center, spacing: 16) {
                    // Quantity controls with label always visible
                    HStack(spacing: 8) {
                        Text("Qty")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize() // Prevent text from being compressed
                        
                        HStack(spacing: 0) {
                            Button(action: {
                                if item.quantity > 1 {
                                    // Keep unit price, reduce quantity
                                    let unitPrice = item.unitPrice
                                    item.quantity -= 1
                                    item.price = unitPrice * Double(item.quantity)
                                    hapticFeedback(.light)
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(item.quantity > 1 ? .primary : .tertiary)
                            }
                            .disabled(item.quantity <= 1)
                            
                            Text("\(item.quantity)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(minWidth: 32)
                            
                            Button(action: {
                                // Keep unit price, increase quantity
                                let unitPrice = item.unitPrice
                                item.quantity += 1
                                item.price = unitPrice * Double(item.quantity)
                                hapticFeedback(.light)
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.tertiarySystemFill))
                        )
                    }
                    .layoutPriority(1) // Ensure this section gets priority in layout
                    
                    // Unit price display - always visible when quantity > 1
                    if item.quantity > 1 {
                        HStack(spacing: 4) {
                            Text("×")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(CurrencyFormatter.shared.format(item.unitPrice))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                    
                    // Total price
                    VStack(alignment: .trailing, spacing: 2) {
                        if isEditing {
                            HStack(spacing: 4) {
                                Text("$")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.green)
                                TextField("0.00", text: $editedPrice)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.green)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 80)
                                    .focused($focusedField, equals: .price)
                            }
                        } else {
                            Text(CurrencyFormatter.shared.format(item.totalPrice))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                        
                        Text("Total")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Item", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func startEditing() {
        editedName = item.name
        editedPrice = String(format: "%.2f", item.price)
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = true
        }
        focusedField = .name
        hapticFeedback(.light)
    }
    
    private func saveChanges() {
        // Validate and save
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            item.name = trimmedName
        }
        
        if let newPrice = Double(editedPrice.replacingOccurrences(of: ",", with: ".")), newPrice >= 0 {
            item.price = newPrice
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
        focusedField = nil
        hapticFeedback(.medium)
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Add Item Sheet

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ItemsEditorViewModel
    
    @State private var name = ""
    @State private var quantity = 1
    @State private var price = 0.0
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, price
    }
    
    private var calculatedTotal: Double {
        price // Price is now the line total
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $name)
                        .focused($focusedField, equals: .name)
                    
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                    
                    HStack {
                        Text("Total Price")
                        Spacer()
                        TextField("0.00", value: $price, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .price)
                    }
                } header: {
                    Text("Item Details")
                } footer: {
                    if quantity > 1 && price > 0 {
                        Text("Unit price: \(CurrencyFormatter.shared.format(price / Double(quantity)))")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(CurrencyFormatter.shared.format(calculatedTotal))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // Create item with total price
                        let newItem = ReceiptItem(
                            name: name,
                            quantity: quantity,
                            price: price
                        )
                        viewModel.addItem(newItem)
                        dismiss()
                    }
                    .disabled(name.isEmpty || price <= 0)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                focusedField = .name
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ItemsEditorView(
            items: ReceiptItem.samples,
            navigationPath: .constant(NavigationPath())
        )
    }
}

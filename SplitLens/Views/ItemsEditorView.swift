//
//  ItemsEditorView.swift
//  SplitLens
//
//  Edit receipt items with liquid glass design
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
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Total summary card
                totalSummaryCard
                    .padding()
                
                // Items list
                if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    itemsList
                }
            }
        }
        .navigationTitle("Edit Items")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isValid {
                    Button("Next") {
                        navigationPath.append(Route.participantsEntry(viewModel.items))
                    }
                    .font(.system(size: 17, weight: .semibold))
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
    
    // MARK: - Sections
    
    private var totalSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                SummaryCard(
                    title: "Items Total",
                    value: viewModel.formattedCalculatedTotal,
                    icon: "cart.fill",
                    color: .blue
                )
                
                if let warning = viewModel.discrepancyWarning {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(warning)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: 100)
                }
            }
        }
    }
    
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
    
    private var itemsList: some View {
        List {
            ForEach($viewModel.items) { $item in
                ItemRow(
                    item: $item,
                    onDelete: {
                        viewModel.deleteItem(item)
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .onDelete { indexSet in
                viewModel.deleteItems(at: indexSet)
            }
        }
        .listStyle(.insetGrouped)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.items.count)
    }
}

// MARK: - Item Row Component

struct ItemRow: View {
    @Binding var item: ReceiptItem
    let onDelete: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name
            HStack {
                Text("Name")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                
                TextField("Item name", text: $item.name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
            }
            
            // Quantity and Price
            HStack(spacing: 16) {
                HStack {
                    Text("Qty")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    
                    Stepper("\(item.quantity)", value: $item.quantity, in: 1...99)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }
                
                HStack {
                    Text("Price")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                    
                    TextField("0.00", value: $item.price, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
            }
            
            // Total
            HStack {
                Text("Total")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(CurrencyFormatter.shared.format(item.totalPrice))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item name", text: $name)
                        .focused($focusedField, equals: .name)
                    
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                    
                    HStack {
                        Text("Price")
                        TextField("0.00", value: $price, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .price)
                    }
                }
                
                Section {
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(CurrencyFormatter.shared.format(price * Double(quantity)))
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
                        viewModel.addItem(name: name, quantity: quantity, price: price)
                        dismiss()
                    }
                    .disabled(name.isEmpty || price <= 0)
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

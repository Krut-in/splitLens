//
//  TotalConfirmationSheet.swift
//  SplitLens
//
//  Sheet for confirming and validating receipt total
//

import SwiftUI

/// Sheet for user to confirm the receipt total with discrepancy warnings
struct TotalConfirmationSheet: View {
    // MARK: - Bindings
    
    @Binding var enteredTotal: Double?
    @Binding var isPresented: Bool
    
    // MARK: - Properties
    
    let detectedTotal: Double?
    let calculatedItemsTotal: Double
    let onConfirm: () -> Void
    let onManualFix: () -> Void
    
    // MARK: - State
    
    @State private var totalText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: - Computed Properties
    
    private var parsedTotal: Double? {
        Double(totalText.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ""))
    }
    
    private var discrepancy: Double? {
        guard let entered = parsedTotal, let detected = detectedTotal else { return nil }
        return abs(entered - detected)
    }
    
    private var discrepancyPercentage: Double? {
        guard let entered = parsedTotal,
              let discrepancy = discrepancy,
              entered > 0 else { return nil }
        return (discrepancy / entered) * 100
    }
    
    private var hasSignificantDiscrepancy: Bool {
        (discrepancyPercentage ?? 0) > 5.0
    }
    
    private var itemsToDetectedDiscrepancy: Double? {
        guard let detected = detectedTotal else { return nil }
        return abs(calculatedItemsTotal - detected)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Detected total (if available)
                    if let detected = detectedTotal {
                        detectedTotalSection(detected)
                    }
                    
                    // User input section
                    userInputSection
                    
                    // Discrepancy warning
                    if hasSignificantDiscrepancy {
                        discrepancyWarningSection
                    }
                    
                    // Items total comparison
                    itemsTotalSection
                    
                    // Action buttons
                    actionButtonsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Verify Total")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                setupInitialValue()
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text("Confirm Receipt Total")
                .font(.system(size: 20, weight: .bold))
            
            Text("Enter the total amount from your receipt to verify extraction accuracy")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private func detectedTotalSection(_ detected: Double) -> some View {
        VStack(spacing: 8) {
            Text("Detected from Receipt")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            Text(CurrencyFormatter.shared.format(detected))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Button {
                totalText = String(format: "%.2f", detected)
                HapticFeedback.shared.lightImpact()
            } label: {
                Text("Use this amount")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var userInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter Total Amount")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            
            HStack {
                Text("$")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                TextField("0.00", text: $totalText)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($isTextFieldFocused)
                    .onChange(of: totalText) { _, newValue in
                        enteredTotal = parsedTotal
                    }
                
                if !totalText.isEmpty {
                    Button {
                        totalText = ""
                        HapticFeedback.shared.lightImpact()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var discrepancyWarningSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Discrepancy Detected")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                
                if let percentage = discrepancyPercentage {
                    Text("The entered amount differs by \(String(format: "%.1f", percentage))% from the detected total")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var itemsTotalSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Extracted Items Total")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(CurrencyFormatter.shared.format(calculatedItemsTotal))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            
            if let discrepancy = itemsToDetectedDiscrepancy, discrepancy > 0.01 {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                    
                    Text("Difference includes fees, tax, or tips")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(CurrencyFormatter.shared.format(discrepancy))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Confirm button
            Button {
                enteredTotal = parsedTotal
                HapticFeedback.shared.success()
                onConfirm()
                isPresented = false
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Looks Correct")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.green)
                )
            }
            .disabled(parsedTotal == nil || parsedTotal == 0)
            .opacity((parsedTotal == nil || parsedTotal == 0) ? 0.5 : 1.0)
            
            // Manual fix button
            Button {
                HapticFeedback.shared.lightImpact()
                onManualFix()
                isPresented = false
            } label: {
                HStack {
                    Image(systemName: "pencil.circle")
                    Text("I'll Fix Items Manually")
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.blue, lineWidth: 1.5)
                )
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Setup
    
    private func setupInitialValue() {
        if let detected = detectedTotal {
            totalText = String(format: "%.2f", detected)
            enteredTotal = detected
        } else if enteredTotal != nil {
            totalText = String(format: "%.2f", enteredTotal!)
        }
        
        // Delay focus to allow sheet animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Preview

#Preview {
    TotalConfirmationSheet(
        enteredTotal: .constant(65.96),
        isPresented: .constant(true),
        detectedTotal: 65.96,
        calculatedItemsTotal: 61.95,
        onConfirm: {},
        onManualFix: {}
    )
}

#Preview("With Discrepancy") {
    TotalConfirmationSheet(
        enteredTotal: .constant(75.00),
        isPresented: .constant(true),
        detectedTotal: 65.96,
        calculatedItemsTotal: 61.95,
        onConfirm: {},
        onManualFix: {}
    )
}

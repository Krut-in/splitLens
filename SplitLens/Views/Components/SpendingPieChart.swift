//
//  SpendingPieChart.swift
//  SplitLens
//
//  Pie chart showing spending breakdown per person
//

import SwiftUI
import Charts

/// Pie chart visualization of per-person spending breakdown
struct SpendingPieChart: View {
    // MARK: - Properties
    
    let personTotals: [String: Double]
    
    // MARK: - Computed Properties
    
    private var sortedData: [(String, Double)] {
        personTotals.sorted { $0.key < $1.key }
    }
    
    private var total: Double {
        personTotals.values.reduce(0, +)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Breakdown")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            
            if sortedData.isEmpty {
                emptyState
            } else {
                chartView
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Chart View
    
    private var chartView: some View {
        VStack(spacing: 16) {
            Chart(sortedData, id: \.0) { person, amount in
                SectorMark(
                    angle: .value("Amount", amount),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("Person", person))
                .cornerRadius(4)
                .opacity(0.9)
            }
            .chartLegend(position: .bottom, alignment: .center, spacing: 12)
            .frame(height: 280)
            .accessibilityLabel("Spending breakdown pie chart")
            .accessibilityValue(accessibilityDescription)
            
            // Summary
            totalSummary
        }
    }
    
    private var totalSummary: some View {
        HStack {
            Text("Total")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(CurrencyFormatter.shared.format(total))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.top, 8)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No spending data available")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Color Mapping
    
    private func createColorMapping() -> [String: Color] {
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .teal, .indigo, .cyan
        ]
        
        var mapping: [String: Color] = [:]
        for (index, person) in sortedData.enumerated() {
            mapping[person.0] = colors[index % colors.count]
        }
        return mapping
    }
    
    // MARK: - Accessibility
    
    private var accessibilityDescription: String {
        let descriptions = sortedData.map { person, amount in
            let percentage = (amount / total) * 100
            return "\(person): \(CurrencyFormatter.shared.format(amount)) (\(String(format: "%.1f", percentage))%)"
        }
        return descriptions.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("Standard Chart") {
    SpendingPieChart(personTotals: [
        "Alice": 42.50,
        "Bob": 28.00,
        "Carol": 15.75
    ])
    .padding()
}

#Preview("Many Participants") {
    SpendingPieChart(personTotals: [
        "Alice": 42.50,
        "Bob": 28.00,
        "Carol": 15.75,
        "David": 31.00,
        "Eve": 19.25,
        "Frank": 25.50
    ])
    .padding()
}

#Preview("Empty State") {
    SpendingPieChart(personTotals: [:])
        .padding()
}

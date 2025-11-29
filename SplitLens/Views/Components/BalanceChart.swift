//
//  BalanceChart.swift
//  SplitLens
//
//  Vertical bar chart showing net balances per person
//

import SwiftUI
import Charts

/// Bar chart showing net balance per person with color coding
struct BalanceChart: View {
    // MARK: - Properties
    
    /// Net balances: Positive = owed to them, Negative = they owe
    let balances: [String: Double]
    
    // MARK: - Computed Properties
    
    private var sortedData: [(String, Double)] {
        balances.sorted { $0.key < $1.key }
    }
    
    private var maxAbsoluteValue: Double {
        let values = sortedData.map { abs($0.1) }
        return (values.max() ?? 100) * 1.1  // Add 10% padding
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Net Balance")
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
        VStack(spacing: 12) {
            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text("Positive (owed to them)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Text("Negative (they owe)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)
            
            // Chart
            Chart(sortedData, id: \.0) { person, balance in
                BarMark(
                    x: .value("Person", person),
                    y: .value("Balance", balance)
                )
                .foregroundStyle(balance >= 0 ? Color.green.gradient : Color.red.gradient)
                .cornerRadius(6)
                .opacity(0.9)
                
                // Add value label on top of bars
                if abs(balance) > 0.01 {
                    BarMark(
                        x: .value("Person", person),
                        y: .value("Balance", balance)
                    )
                    .foregroundStyle(.clear)
                    .annotation(position: balance >= 0 ? .top : .bottom) {
                        Text(CurrencyFormatter.shared.format(balance))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(balance >= 0 ? .green : .red)
                    }
                }
            }
            .chartYScale(domain: -maxAbsoluteValue...maxAbsoluteValue)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(CurrencyFormatter.shared.format(amount))
                                .font(.system(size: 11))
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let person = value.as(String.self) {
                            Text(person)
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                }
            }
            .frame(height: 280)
            .animation(.easeInOut(duration: 0.8), value: sortedData.count)
            .accessibilityLabel("Net balance bar chart")
            .accessibilityValue(accessibilityDescription)
            
            // Zero line explanation
            Text("Zero line represents even split")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No balance data available")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Accessibility
    
    private var accessibilityDescription: String {
        let descriptions = sortedData.map { person, balance in
            if balance > 0 {
                return "\(person) is owed \(CurrencyFormatter.shared.format(balance))"
            } else if balance < 0 {
                return "\(person) owes \(CurrencyFormatter.shared.format(abs(balance)))"
            } else {
                return "\(person) is even"
            }
        }
        return descriptions.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("Mixed Balances") {
    BalanceChart(balances: [
        "Alice": 35.50,
        "Bob": -20.00,
        "Carol": -15.50
    ])
    .padding()
}

#Preview("All Positive") {
    BalanceChart(balances: [
        "Alice": 50.00,
        "Bob": 25.00,
        "Carol": 15.00
    ])
    .padding()
}

#Preview("All Negative") {
    BalanceChart(balances: [
        "Bob": -30.00,
        "Carol": -20.00,
        "David": -10.00
    ])
    .padding()
}

#Preview("Empty State") {
    BalanceChart(balances: [:])
        .padding()
}

//
//  OweLentChart.swift
//  SplitLens
//
//  Horizontal bar chart showing owe/lent visualization
//

import SwiftUI
import Charts

/// Bar chart showing what each person owes or is owed
struct OweLentChart: View {
    // MARK: - Properties
    
    /// Per-person data: Positive = lent (owed to them), Negative = owe
    let oweLentData: [(String, Double)]
    
    // MARK: - Computed Properties
    
    private var sortedData: [(String, Double)] {
        oweLentData.sorted { $0.0 < $1.0 }
    }
    
    private var maxAbsoluteValue: Double {
        sortedData.map { abs($0.1) }.max() ?? 100
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Owe vs. Lent")
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
                    Text("Lent (owed to them)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                    Text("Owe")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)
            
            // Chart
            Chart(sortedData, id: \.0) { person, amount in
                BarMark(
                    x: .value("Amount", amount),
                    y: .value("Person", person)
                )
                .foregroundStyle(amount >= 0 ? Color.green : Color.red)
                .cornerRadius(6)
                .opacity(0.9)
            }
            .chartXScale(domain: -maxAbsoluteValue...maxAbsoluteValue)
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(CurrencyFormatter.shared.format(abs(amount)))
                                .font(.system(size: 11))
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let person = value.as(String.self) {
                            Text(person)
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                }
            }
            .frame(height: max(CGFloat(sortedData.count) * 50, 200))
            .accessibilityLabel("Owe versus lent bar chart")
            .accessibilityValue(accessibilityDescription)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No owe/lent data available")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Accessibility
    
    private var accessibilityDescription: String {
        let descriptions = sortedData.map { person, amount in
            if amount > 0 {
                return "\(person) is owed \(CurrencyFormatter.shared.format(amount))"
            } else if amount < 0 {
                return "\(person) owes \(CurrencyFormatter.shared.format(abs(amount)))"
            } else {
                return "\(person) is settled"
            }
        }
        return descriptions.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("Mixed Balances") {
    OweLentChart(oweLentData: [
        ("Alice", 25.50),   // Lent (positive)
        ("Bob", -15.75),    // Owes (negative)
        ("Carol", -9.75),   // Owes (negative)
        ("David", 0.0)      // Settled
    ])
    .padding()
}

#Preview("All Owe") {
    OweLentChart(oweLentData: [
        ("Bob", -20.00),
        ("Carol", -15.50),
        ("David", -12.25)
    ])
    .padding()
}

#Preview("Empty State") {
    OweLentChart(oweLentData: [])
        .padding()
}

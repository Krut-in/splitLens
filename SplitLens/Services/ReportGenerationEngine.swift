//
//  ReportGenerationEngine.swift
//  SplitLens
//
//  Service for generating formatted reports and exports
//

import Foundation
import PDFKit


// MARK: - Report Generation Protocol

/// Protocol defining report generation capabilities
protocol ReportGenerationEngineProtocol {
    /// Generates a formatted text report for a session
    func generateTextReport(for session: ReceiptSession) -> String
    
    /// Generates a detailed breakdown report
    func generateDetailedReport(for session: ReceiptSession) -> String
    
    /// Generates a summary suitable for sharing
    func generateShareableSummary(for session: ReceiptSession) -> String
    
    /// Generates CSV format for spreadsheet import
    func generateCSV(for session: ReceiptSession) -> String
    
    /// Generates JSON format for API integration
    func generateJSON(for session: ReceiptSession) throws -> Data
    
    /// Generates PDF format for professional reports
    func generatePDF(for session: ReceiptSession) -> Data
}

// MARK: - Report Generation Engine

/// Implements report generation with multiple format options
final class ReportGenerationEngine: ReportGenerationEngineProtocol {
    
    // MARK: - Dependencies
    
    private let pdfGenerator: PDFGenerator
    
    // MARK: - Initialization
    
    init(pdfGenerator: PDFGenerator = PDFGenerator()) {
        self.pdfGenerator = pdfGenerator
    }
    
    // MARK: - Text Report
    
    /// Generates a basic text report
    func generateTextReport(for session: ReceiptSession) -> String {
        var report = ""
        
        // Header
        report += "📊 BILL SPLIT REPORT\n"
        report += "═══════════════════════════════\n\n"
        
        // Session info
        report += "Date: \(session.formattedDate)\n"
        report += "Total: \(session.formattedTotal)\n"
        report += "Paid by: \(session.paidBy)\n"
        report += "Participants: \(session.participants.joined(separator: ", "))\n\n"
        
        // Split summary
        report += "💰 PAYMENT SUMMARY\n"
        report += "───────────────────────────────\n"
        
        if session.computedSplits.isEmpty {
            report += "No payments needed - all settled!\n"
        } else {
            for split in session.computedSplits {
                report += "• \(split.from) → \(split.to): \(split.formattedAmount)\n"
            }
        }
        
        return report
    }
    
    // MARK: - Detailed Report
    
    /// Generates a detailed report with item breakdown
    func generateDetailedReport(for session: ReceiptSession) -> String {
        var report = ""
        
        // Header
        report += "📋 DETAILED BILL SPLIT REPORT\n"
        report += "═══════════════════════════════════════════════\n\n"
        
        // Session info
        report += "📅 Date: \(session.formattedDate)\n"
        report += "💵 Total Amount: \(session.formattedTotal)\n"
        report += "👤 Paid By: \(session.paidBy)\n"
        report += "👥 Participants (\(session.participantCount)): \(session.participants.joined(separator: ", "))\n\n"
        
        // Items breakdown
        report += "🧾 ITEMS (\(session.itemCount))\n"
        report += "───────────────────────────────────────────────\n"
        
        for item in session.items {
            report += "\(item.name)\n"
            // Keep currency formatting centralized to avoid drift across reports.
            report += "  Qty: \(item.quantity) × \(CurrencyFormatter.shared.format(item.price)) = \(item.formattedTotalPrice)\n"
            
            if item.isAssigned {
                if item.sharingCount > 1 {
                    report += "  Shared by: \(item.assignedTo.joined(separator: ", "))\n"
                    report += "  Each pays: \(item.formattedPricePerPerson)\n"
                } else {
                    report += "  Assigned to: \(item.assignedTo[0])\n"
                }
            } else {
                report += "  ⚠️ Not assigned\n"
            }
            report += "\n"
        }
        
        // Per-person breakdown
        report += "👤 PER-PERSON BREAKDOWN\n"
        report += "───────────────────────────────────────────────\n"
        
        for participant in session.participants.sorted() {
            let itemsForPerson = session.items(assignedTo: participant)
            let totalOwed = session.totalOwed(by: participant)
            
            report += "\(participant):\n"
            
            if itemsForPerson.isEmpty {
                report += "  No items assigned\n"
            } else {
                for item in itemsForPerson {
                    if item.sharingCount > 1 {
                        report += "  • \(item.name): \(item.formattedPricePerPerson)\n"
                    } else {
                        report += "  • \(item.name): \(item.formattedTotalPrice)\n"
                    }
                }
                report += "  Subtotal: \(CurrencyFormatter.shared.format(totalOwed))\n"
            }
            report += "\n"
        }
        
        // Payment summary
        report += "💰 PAYMENTS REQUIRED\n"
        report += "───────────────────────────────────────────────\n"
        
        if session.computedSplits.isEmpty {
            report += "✅ All settled! No payments needed.\n"
        } else {
            for (index, split) in session.computedSplits.enumerated() {
                report += "\(index + 1). \(split.summary)\n"
                if !split.explanation.isEmpty {
                    report += "   (\(split.explanation))\n"
                }
            }
        }
        
        report += "\n═══════════════════════════════════════════════\n"
        
        return report
    }
    
    // MARK: - Shareable Summary

    /// Generates a rich text summary suitable for messaging apps.
    /// Includes payer label, full per-item breakdown with assignees,
    /// fee allocations, and what each person owes the payer.
    func generateShareableSummary(for session: ReceiptSession) -> String {
        var lines: [String] = []
        let payer = session.paidBy
        let totalParticipantCount = session.participants.count

        // Header
        lines.append("🧾 SplitLens")
        if let storeName = session.storeName, !storeName.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append(storeName)
        }
        lines.append(Self.shareDateFormatter.string(from: session.receiptDate))
        lines.append("")

        // Payer + total
        lines.append("Paid by: \(payer)")
        lines.append("Total: \(session.formattedTotal)")
        lines.append("")

        // Items
        if !session.items.isEmpty {
            lines.append("ITEMS")
            for item in session.items {
                let qtyLabel = item.quantity > 1 ? " (x\(item.quantity))" : ""
                let priceLabel = CurrencyFormatter.shared.format(item.totalPrice)
                lines.append("• \(item.name)\(qtyLabel) - \(priceLabel)")
                let assignees = formatAssignees(
                    item.assignedTo,
                    totalParticipants: totalParticipantCount
                )
                lines.append("  Assigned to: \(assignees)")
            }
            lines.append("")
        }

        // Fees
        if !session.feeAllocations.isEmpty {
            lines.append("FEES")
            for allocation in session.feeAllocations {
                let amount = CurrencyFormatter.shared.format(allocation.fee.amount)
                let strategy = allocation.strategy.displayName.lowercased()
                lines.append("• \(allocation.fee.displayName) (\(strategy)): \(amount)")
            }
            lines.append("")
        }

        // Settlement section
        let owedToPayer = session.computedSplits.filter { $0.to == payer }
        if owedToPayer.isEmpty {
            lines.append("✅ Everyone is settled with \(payer)")
        } else {
            lines.append("WHO OWES \(payer.uppercased())")
            for split in owedToPayer.sorted(by: { $0.from < $1.from }) {
                lines.append("• \(split.from) owes \(split.formattedAmount)")
            }
        }

        lines.append("")
        lines.append("Sent via SplitLens")

        return lines.joined(separator: "\n")
    }

    /// Formats an assignee list as either "Everyone" (when all participants are assigned)
    /// or a comma-separated name list. Falls back to "Unassigned" for empty arrays.
    private func formatAssignees(_ assignees: [String], totalParticipants: Int) -> String {
        if assignees.isEmpty {
            return "Unassigned"
        }
        if assignees.count >= totalParticipants && totalParticipants > 0 {
            return "Everyone"
        }
        return assignees.joined(separator: ", ")
    }

    /// Date formatter used in the share summary header.
    private static let shareDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // MARK: - Export Formats
    
    /// Generates CSV format for spreadsheet import
    func generateCSV(for session: ReceiptSession) -> String {
        var csv = "Item,Quantity,Price,Total,Assigned To\n"
        
        for item in session.items {
            let assignedTo = item.assignedTo.joined(separator: "; ")
            csv += "\"\(item.name)\",\(item.quantity),\(item.price),\(item.totalPrice),\"\(assignedTo)\"\n"
        }
        
        return csv
    }
    
    /// Generates JSON format for API integration
    func generateJSON(for session: ReceiptSession) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(session)
    }
    
    /// Generates PDF format for professional reports
    func generatePDF(for session: ReceiptSession) -> Data {
        return pdfGenerator.generateReport(session: session)
    }
}

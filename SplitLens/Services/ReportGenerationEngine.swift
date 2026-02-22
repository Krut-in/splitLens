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
    
    /// Generates a concise summary suitable for messaging apps
    func generateShareableSummary(for session: ReceiptSession) -> String {
        var summary = ""
        
        summary += "💸 Bill Split - \(session.formattedTotal)\n"
        summary += "Paid by \(session.paidBy)\n\n"
        
        if session.computedSplits.isEmpty {
            summary += "✅ All settled!"
        } else {
            summary += "Please pay:\n"
            for split in session.computedSplits {
                summary += "• \(split.from) → \(split.to): \(split.formattedAmount)\n"
            }
        }
        
        summary += "\n- Sent via SplitLens 📱"
        
        return summary
    }
    
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

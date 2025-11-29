//
//  PDFGenerator.swift
//  SplitLens
//
//  Service for generating professional PDF reports with embedded charts
//

import Foundation
import UIKit
import PDFKit
import SwiftUI

/// Service for generating PDF reports from receipt sessions
final class PDFGenerator {
    
    // MARK: - Constants
    
    private let pageWidth: CGFloat = 612.0   // 8.5 inches * 72 points/inch
    private let pageHeight: CGFloat = 792.0  // 11 inches * 72 points/inch
    private let margin: CGFloat = 50.0
    
    private var contentWidth: CGFloat {
        pageWidth - (margin * 2)
    }
    
    // MARK: - PDF Generation
    
    /// Generates a complete PDF report for a receipt session
    /// - Parameter session: The receipt session to generate report for
    /// - Returns: PDF data
    func generateReport(session: ReceiptSession) -> Data {
        let reportData = ReportData(session: session)
        
        // Create PDF context
        let pdfMetaData = [
            kCGPDFContextCreator: "SplitLens",
            kCGPDFContextAuthor: session.paidBy,
            kCGPDFContextTitle: "Receipt Split Report - \(session.formattedDate)"
        ]
        
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfData = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfMetaData as CFDictionary) else {
            return Data()
        }
        
        // Begin PDF
        context.beginPDFPage(nil)
        
        var yPosition: CGFloat = margin
        
        // Title page
        yPosition = drawTitlePage(context: context, session: session, startY: yPosition)
        
        // Participants section
        yPosition = drawParticipantsSection(context: context, session: session, startY: yPosition + 30)
        
        // Items table
        yPosition = drawItemsTable(context: context, session: session, startY: yPosition + 30)
        
        // Settlement table
        yPosition = drawSettlementTable(context: context, session: session, startY: yPosition + 30)
        
        // Charts (on new page if needed)
        if yPosition > pageHeight - 400 {
            context.endPDFPage()
            context.beginPDFPage(nil)
            yPosition = margin
        }
        
        yPosition = drawCharts(context: context, reportData: reportData, startY: yPosition + 30)
        
        // Footer
        drawFooter(context: context)
        
        context.endPDFPage()
        context.closePDF()
        
        return pdfData as Data
    }
    
    // MARK: - Title Page
    
    private func drawTitlePage(context: CGContext, session: ReceiptSession, startY: CGFloat) -> CGFloat {
        var yPos = startY
        
        // App name
        drawText(
            "SplitLens",
            at: CGPoint(x: margin, y: yPos),
            font: .boldSystemFont(ofSize: 32),
            color: .systemBlue,
            in: context
        )
        yPos += 45
        
        // Report title
        drawText(
            "Receipt Split Report",
            at: CGPoint(x: margin, y: yPos),
            font: .boldSystemFont(ofSize: 24),
            in: context
        )
        yPos += 35
        
        // Date
        drawText(
            "Date: \(session.formattedDate)",
            at: CGPoint(x: margin, y: yPos),
            font: .systemFont(ofSize: 14),
            color: .darkGray,
            in: context
        )
        yPos += 25
        
        // Summary box
        let summaryRect = CGRect(x: margin, y: yPos, width: contentWidth, height: 80)
        context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.1).cgColor)
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(1.5)
        let roundedRect = CGPath(roundedRect: summaryRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.addPath(roundedRect)
        context.drawPath(using: .fillStroke)
        
        // Summary content
        yPos += 20
        drawText(
            "Total: \(session.formattedTotal)",
            at: CGPoint(x: margin + 15, y: yPos),
            font: .boldSystemFont(ofSize: 18),
            in: context
        )
        yPos += 25
        drawText(
            "Paid by: \(session.paidBy)",
            at: CGPoint(x: margin + 15, y: yPos),
            font: .systemFont(ofSize: 14),
            in: context
        )
        yPos += 20
        drawText(
            "Participants: \(session.participantCount)  •  Items: \(session.itemCount)",
            at: CGPoint(x: margin + 15, y: yPos),
            font: .systemFont(ofSize: 14),
            color: .darkGray,
            in: context
        )
        yPos += 30
        
        return yPos
    }
    
    // MARK: - Participants Section
    
    private func drawParticipantsSection(context: CGContext, session: ReceiptSession, startY: CGFloat) -> CGFloat {
        var yPos = startY
        
        // Section title
        drawText(
            "PARTICIPANTS",
            at: CGPoint(x: margin, y: yPos),
            font: .boldSystemFont(ofSize: 16),
            in: context
        )
        yPos += 25
        
        // Participants list
        for participant in session.participants.sorted() {
            let isPayer = participant == session.paidBy
            let text = isPayer ? "\(participant) (Payer)" : participant
            let font: UIFont = isPayer ? .boldSystemFont(ofSize: 13) : .systemFont(ofSize: 13)
            
            drawText(
                "• \(text)",
                at: CGPoint(x: margin + 10, y: yPos),
                font: font,
                in: context
            )
            yPos += 20
        }
        
        return yPos
    }
    
    // MARK: - Items Table
    
    private func drawItemsTable(context: CGContext, session: ReceiptSession, startY: CGFloat) -> CGFloat {
        var yPos = startY
        
        // Section title
        drawText(
            "ITEMS",
            at: CGPoint(x: margin, y: yPos),
            font: .boldSystemFont(ofSize: 16),
            in: context
        )
        yPos += 30
        
        // Table headers
        let headers = ["Item", "Qty", "Price", "Total", "Assigned To"]
        let columnWidths: [CGFloat] = [180, 50, 70, 70, 142]
        
        var xPos: CGFloat = margin
        for (index, header) in headers.enumerated() {
            drawText(
                header,
                at: CGPoint(x: xPos, y: yPos),
                font: .boldSystemFont(ofSize: 12),
                color: .darkGray,
                in: context
            )
            xPos += columnWidths[index]
        }
        yPos += 20
        
        // Header line
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: margin, y: yPos))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: yPos))
        context.strokePath()
        yPos += 15
        
        // Table rows
        for item in session.items {
            xPos = margin
            
            // Item name
            drawText(
                item.name,
                at: CGPoint(x: xPos, y: yPos),
                font: .systemFont(ofSize: 11),
                in: context
            )
            xPos += columnWidths[0]
            
            // Quantity
            drawText(
                "\(item.quantity)",
                at: CGPoint(x: xPos, y: yPos),
                font: .systemFont(ofSize: 11),
                in: context
            )
            xPos += columnWidths[1]
            
            // Price
            drawText(
                CurrencyFormatter.shared.format(item.price),
                at: CGPoint(x: xPos, y: yPos),
                font: .systemFont(ofSize: 11),
                in: context
            )
            xPos += columnWidths[2]
            
            // Total
            drawText(
                item.formattedTotalPrice,
                at: CGPoint(x: xPos, y: yPos),
                font: .systemFont(ofSize: 11),
                in: context
            )
            xPos += columnWidths[3]
            
            // Assigned to
            let assignedText = item.assignedTo.joined(separator: ", ")
            drawText(
                assignedText.count > 20 ? String(assignedText.prefix(20)) + "..." : assignedText,
                at: CGPoint(x: xPos, y: yPos),
                font: .systemFont(ofSize: 10),
                color: .darkGray,
                in: context
            )
            
            yPos += 18
        }
        
        return yPos
    }
    
    // MARK: - Settlement Table
    
    private func drawSettlementTable(context: CGContext, session: ReceiptSession, startY: CGFloat) -> CGFloat {
        var yPos = startY
        
        // Section title
        drawText(
            "SETTLEMENTS",
            at: CGPoint(x: margin, y: yPos),
            font: .boldSystemFont(ofSize: 16),
            in: context
        )
        yPos += 25
        
        if session.computedSplits.isEmpty {
            drawText(
                "✓ All settled! No payments needed.",
                at: CGPoint(x: margin + 10, y: yPos),
                font: .systemFont(ofSize: 13),
                color: .systemGreen,
                in: context
            )
            yPos += 25
        } else {
            for (index, split) in session.computedSplits.enumerated() {
                // Settlement entry
                drawText(
                    "\(index + 1). \(split.summary)",
                    at: CGPoint(x: margin + 10, y: yPos),
                    font: .boldSystemFont(ofSize: 13),
                    in: context
                )
                yPos += 20
                
                // Explanation (if available)
                if !split.explanation.isEmpty {
                    drawText(
                        "   \(split.explanation)",
                        at: CGPoint(x: margin + 20, y: yPos),
                        font: .systemFont(ofSize: 11),
                        color: .darkGray,
                        in: context
                    )
                    yPos += 18
                }
            }
        }
        
        return yPos
    }
    
    // MARK: - Charts
    
    private func drawCharts(context: CGContext, reportData: ReportData, startY: CGFloat) -> CGFloat {
        var yPos = startY
        
        // Section title
        drawText(
            "VISUALIZATIONS",
            at: CGPoint(x: margin, y: yPos),
            font: .boldSystemFont(ofSize: 16),
            in: context
        )
        yPos += 30
        
        let chartSize = CGSize(width: contentWidth, height: 220)
        
        // Spending Pie Chart
        let spendingChart = SpendingPieChart(personTotals: reportData.personTotals)
        if let image = ChartRenderer.renderChartForPDF(spendingChart, size: chartSize) {
            ChartRenderer.embedInPDF(
                image,
                in: CGRect(x: margin, y: yPos, width: chartSize.width, height: chartSize.height),
                context: context
            )
            yPos += chartSize.height + 20
        }
        
        // Balance Chart
        let balanceChart = BalanceChart(balances: reportData.balances)
        if let image = ChartRenderer.renderChartForPDF(balanceChart, size: chartSize) {
            ChartRenderer.embedInPDF(
                image,
                in: CGRect(x: margin, y: yPos, width: chartSize.width, height: chartSize.height),
                context: context
            )
            yPos += chartSize.height + 20
        }
        
        return yPos
    }
    
    // MARK: - Footer
    
    private func drawFooter(context: CGContext) {
        let footerY = pageHeight - margin + 10
        
        // App version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let footerText = "Generated by SplitLens v\(version) • \(Date().formatted(date: .abbreviated, time: .shortened))"
        
        drawText(
            footerText,
            at: CGPoint(x: margin, y: footerY),
            font: .systemFont(ofSize: 10),
            color: .lightGray,
            in: context
        )
    }
    
    // MARK: - Helper Methods
    
    private func drawText(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor = .black,
        in context: CGContext
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: point.x, y: pageHeight - point.y)
        context.scaleBy(x: 1.0, y: -1.0)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

// MARK: - Preview Helper

#if DEBUG
extension PDFGenerator {
    /// Generates a preview PDF for testing
    static func generatePreviewPDF() -> Data {
        let generator = PDFGenerator()
        return generator.generateReport(session: .sample)
    }
}
#endif

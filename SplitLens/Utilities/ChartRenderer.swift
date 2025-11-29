//
//  ChartRenderer.swift
//  SplitLens
//
//  Utility for converting SwiftUI charts to images for PDF embedding
//

import SwiftUI
import UIKit

/// Utility class for rendering SwiftUI views (especially charts) as images
final class ChartRenderer {
    
    // MARK: - View to Image Conversion
    
    /// Renders a SwiftUI view to a UIImage
    /// - Parameters:
    ///   - view: The SwiftUI view to render
    ///   - size: Target size for the rendered image
    /// - Returns: UIImage representation of the view, or nil if rendering fails
    static func renderToImage<V: View>(_ view: V, size: CGSize) -> UIImage? {
        // Create a hosting controller with the view
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        
        // Create image renderer
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    
    /// Renders a SwiftUI view to a UIImage with custom scale
    /// - Parameters:
    ///   - view: The SwiftUI view to render
    ///   - size: Target size for the rendered image
    ///   - scale: Scale factor (1.0 = standard, 2.0 = @2x, 3.0 = @3x)
    /// - Returns: UIImage representation of the view
    static func renderToImage<V: View>(_ view: V, size: CGSize, scale: CGFloat) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        return renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    
    // MARK: - PDF Embedding
    
    /// Draws an image in a PDF context
    /// - Parameters:
    ///   - image: The image to embed
    ///   - point: The origin point where to draw the image
    ///   - context: The CGContext for PDF drawing
    static func embedInPDF(_ image: UIImage, at point: CGPoint, in context: CGContext) {
        guard let cgImage = image.cgImage else { return }
        
        // Calculate the rect for drawing
        let rect = CGRect(
            origin: point,
            size: image.size
        )
        
        // Save the graphics state
        context.saveGState()
        
        // Flip the coordinate system (PDF coordinates are bottom-up)
        context.translateBy(x: 0, y: rect.origin.y + rect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the image
        let flippedRect = CGRect(
            origin: CGPoint(x: rect.origin.x, y: 0),
            size: rect.size
        )
        context.draw(cgImage, in: flippedRect)
        
        // Restore the graphics state
        context.restoreGState()
    }
    
    /// Draws an image in a PDF context with custom size
    /// - Parameters:
    ///   - image: The image to embed
    ///   - rect: The rectangle where to draw the image
    ///   - context: The CGContext for PDF drawing
    static func embedInPDF(_ image: UIImage, in rect: CGRect, context: CGContext) {
        guard let cgImage = image.cgImage else { return }
        
        context.saveGState()
        
        // Flip coordinate system
        context.translateBy(x: 0, y: rect.origin.y + rect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        let flippedRect = CGRect(
            origin: CGPoint(x: rect.origin.x, y: 0),
            size: rect.size
        )
        context.draw(cgImage, in: flippedRect)
        
        context.restoreGState()
    }
    
    // MARK: - Convenience Methods
    
    /// Renders a chart view and returns it as PDF-ready image
    /// - Parameters:
    ///   - chart: The chart view to render
    ///   - size: Desired size for the chart
    /// - Returns: High-quality image suitable for PDF embedding
    static func renderChartForPDF<V: View>(_ chart: V, size: CGSize) -> UIImage? {
        // Use 2x scale for better quality in PDF
        return renderToImage(chart, size: size, scale: 2.0)
    }
    
    /// Standard chart size for PDF reports (landscape orientation)
    static let standardPDFChartSize = CGSize(width: 500, height: 300)
    
    /// Compact chart size for smaller PDF sections
    static let compactPDFChartSize = CGSize(width: 350, height: 220)
}

// MARK: - Preview Helper

#if DEBUG
extension ChartRenderer {
    /// Helper for previewing rendered images in SwiftUI
    struct ImagePreview: View {
        let image: UIImage?
        
        var body: some View {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Text("Failed to render image")
                    .foregroundStyle(.red)
            }
        }
    }
}
#endif

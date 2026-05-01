#!/usr/bin/env swift
//
//  GenerateAppIcon.swift
//  SplitLens
//
//  Renders a 1024x1024 app icon PNG into the asset catalog.
//  Run from the project root:
//      swift Tools/GenerateAppIcon.swift
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Configuration

let canvasSize: CGFloat = 1024
let outputPath = "SplitLens/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

// Brand palette
let tealTop  = CGColor(red: 0.16, green: 0.78, blue: 0.78, alpha: 1.0)   // bright teal
let indigoBR = CGColor(red: 0.18, green: 0.32, blue: 0.65, alpha: 1.0)   // deep indigo
let tealMid  = CGColor(red: 0.16, green: 0.62, blue: 0.66, alpha: 1.0)   // for the split line
let receiptInk = CGColor(red: 0.13, green: 0.18, blue: 0.28, alpha: 1.0) // dark slate
let receiptBg  = CGColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0)
let shadowCol  = CGColor(red: 0, green: 0, blue: 0, alpha: 0.22)

// MARK: - Setup context

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bytesPerRow = Int(canvasSize) * 4

guard let ctx = CGContext(
    data: nil,
    width: Int(canvasSize),
    height: Int(canvasSize),
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("Failed to create graphics context\n".utf8))
    exit(1)
}

// MARK: - 1. Background gradient

let gradientColors = [tealTop, indigoBR] as CFArray
let gradientLocations: [CGFloat] = [0.0, 1.0]
guard let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: gradientColors,
    locations: gradientLocations
) else { exit(2) }

ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: canvasSize),       // top-left
    end:   CGPoint(x: canvasSize, y: 0),       // bottom-right
    options: []
)

// MARK: - 2. Receipt silhouette

let receiptW: CGFloat = 540
let receiptH: CGFloat = 680
let receiptX = (canvasSize - receiptW) / 2
let receiptY = (canvasSize - receiptH) / 2 - 10
let receiptRect = CGRect(x: receiptX, y: receiptY, width: receiptW, height: receiptH)

let cornerRadius: CGFloat = 28

func makeReceiptPath(in rect: CGRect, cornerRadius r: CGFloat, teethCount: Int) -> CGPath {
    let path = CGMutablePath()
    let teethW = rect.width / CGFloat(teethCount)
    let toothDepth: CGFloat = 28

    // Start at the top-left, just below the rounded corner
    path.move(to: CGPoint(x: rect.minX, y: rect.maxY - r))

    // Top-left corner
    path.addArc(
        tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
        tangent2End: CGPoint(x: rect.minX + r, y: rect.maxY),
        radius: r
    )
    // Top edge
    path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
    // Top-right corner
    path.addArc(
        tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
        tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - r),
        radius: r
    )
    // Right edge down to just above zigzag start
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + toothDepth))

    // Zigzag bottom (right to left)
    for i in (0..<teethCount).reversed() {
        let xMid = rect.minX + CGFloat(i) * teethW + teethW / 2
        let xEnd = rect.minX + CGFloat(i) * teethW
        path.addLine(to: CGPoint(x: xMid, y: rect.minY))
        path.addLine(to: CGPoint(x: xEnd, y: rect.minY + toothDepth))
    }

    // Close along left edge
    path.closeSubpath()
    return path
}

let receiptPath = makeReceiptPath(in: receiptRect, cornerRadius: cornerRadius, teethCount: 11)

// 2a. Drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: shadowCol)
ctx.setFillColor(receiptBg)
ctx.addPath(receiptPath)
ctx.fillPath()
ctx.restoreGState()

// MARK: - 3. Horizontal "line items"

ctx.setStrokeColor(receiptInk)
ctx.setLineWidth(14)
ctx.setLineCap(.round)

let linePaddingX: CGFloat = 56
let lineWidths: [CGFloat] = [0.78, 0.88, 0.62, 0.92]
let lineSpacing: CGFloat = 88
let firstLineY = receiptRect.maxY - 110

for (i, widthRatio) in lineWidths.enumerated() {
    let y = firstLineY - CGFloat(i) * lineSpacing
    let startX = receiptRect.minX + linePaddingX
    let maxLineW = receiptW - linePaddingX * 2
    let endX = startX + maxLineW * widthRatio
    ctx.move(to: CGPoint(x: startX, y: y))
    ctx.addLine(to: CGPoint(x: endX, y: y))
    ctx.strokePath()
}

// MARK: - 4. Vertical dashed split line down the middle

ctx.setStrokeColor(tealMid)
ctx.setLineWidth(8)
ctx.setLineCap(.round)
ctx.setLineDash(phase: 0, lengths: [16, 14])

let midX = receiptRect.midX
let splitTopY = receiptRect.maxY - 60
let splitBottomY = receiptRect.minY + 60
ctx.move(to: CGPoint(x: midX, y: splitTopY))
ctx.addLine(to: CGPoint(x: midX, y: splitBottomY))
ctx.strokePath()

ctx.setLineDash(phase: 0, lengths: [])

// MARK: - 5. Save the PNG

guard let cgImage = ctx.makeImage() else {
    FileHandle.standardError.write(Data("Failed to render image\n".utf8))
    exit(3)
}

let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(
    url as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    FileHandle.standardError.write(Data("Failed to create destination at \(outputPath)\n".utf8))
    exit(4)
}

CGImageDestinationAddImage(dest, cgImage, nil)

guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("Failed to finalize PNG write\n".utf8))
    exit(5)
}

print("Wrote \(Int(canvasSize))x\(Int(canvasSize)) icon: \(outputPath)")

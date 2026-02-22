//
//  ScanMetadata.swift
//  SplitLens
//
//  Metadata captured during receipt scanning and carried through the flow.
//

import Foundation
import UIKit

struct ScanMetadata: Hashable {
    let id: UUID
    let scanCapturedAt: Date
    let ocrReceiptDate: Date?
    let ocrReceiptDateHasTime: Bool
    let selectedImages: [UIImage]

    init(
        id: UUID = UUID(),
        scanCapturedAt: Date,
        ocrReceiptDate: Date?,
        ocrReceiptDateHasTime: Bool,
        selectedImages: [UIImage]
    ) {
        self.id = id
        self.scanCapturedAt = scanCapturedAt
        self.ocrReceiptDate = ocrReceiptDate
        self.ocrReceiptDateHasTime = ocrReceiptDateHasTime
        self.selectedImages = selectedImages
    }

    static var empty: ScanMetadata {
        ScanMetadata(
            scanCapturedAt: Date(),
            ocrReceiptDate: nil,
            ocrReceiptDateHasTime: true,
            selectedImages: []
        )
    }

    static func == (lhs: ScanMetadata, rhs: ScanMetadata) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

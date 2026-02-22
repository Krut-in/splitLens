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
    /// Store/vendor name extracted from the receipt by OCR (nil if not detected)
    let storeName: String?

    init(
        id: UUID = UUID(),
        scanCapturedAt: Date,
        ocrReceiptDate: Date?,
        ocrReceiptDateHasTime: Bool,
        selectedImages: [UIImage],
        storeName: String? = nil
    ) {
        self.id = id
        self.scanCapturedAt = scanCapturedAt
        self.ocrReceiptDate = ocrReceiptDate
        self.ocrReceiptDateHasTime = ocrReceiptDateHasTime
        self.selectedImages = selectedImages
        self.storeName = storeName
    }

    static var empty: ScanMetadata {
        ScanMetadata(
            scanCapturedAt: Date(),
            ocrReceiptDate: nil,
            ocrReceiptDateHasTime: true,
            selectedImages: [],
            storeName: nil
        )
    }

    static func == (lhs: ScanMetadata, rhs: ScanMetadata) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

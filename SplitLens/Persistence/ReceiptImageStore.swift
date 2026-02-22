//
//  ReceiptImageStore.swift
//  SplitLens
//
//  Local file storage for persisted receipt images.
//

import Foundation
import UIKit

protocol ReceiptImageStoreProtocol {
    func saveCompressedImages(_ images: [UIImage], sessionId: UUID) throws -> [String]
    func deleteImages(for sessionId: UUID) throws
    func loadImage(atPath path: String) -> UIImage?
}

enum ReceiptImageStoreError: Error, LocalizedError {
    case invalidImageData(index: Int)
    case ioFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImageData(let index):
            return "Could not process receipt image at page \(index + 1)."
        case .ioFailed(let message):
            return "Image storage failed: \(message)"
        }
    }
}

final class LocalReceiptImageStore: ReceiptImageStoreProtocol {
    private let fileManager: FileManager
    private let compressionQuality: CGFloat
    private let maxLongestEdge: CGFloat
    private let baseDirectory: URL

    init(
        fileManager: FileManager = .default,
        compressionQuality: CGFloat = 0.72,
        maxLongestEdge: CGFloat = 1800
    ) {
        self.fileManager = fileManager
        self.compressionQuality = compressionQuality
        self.maxLongestEdge = maxLongestEdge

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        baseDirectory = appSupport.appendingPathComponent("ReceiptImages", isDirectory: true)
    }

    func saveCompressedImages(_ images: [UIImage], sessionId: UUID) throws -> [String] {
        guard !images.isEmpty else {
            return []
        }

        try ensureDirectoryExists(baseDirectory)

        let destinationDirectory = baseDirectory.appendingPathComponent(sessionId.uuidString, isDirectory: true)
        let stagingDirectory = baseDirectory.appendingPathComponent("\(sessionId.uuidString)-tmp-\(UUID().uuidString)", isDirectory: true)

        do {
            try ensureDirectoryExists(stagingDirectory)

            var paths: [String] = []
            paths.reserveCapacity(images.count)

            for (index, image) in images.enumerated() {
                let resizedImage = image.resizedKeepingAspectRatio(maxLongestEdge: maxLongestEdge)
                guard let imageData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
                    throw ReceiptImageStoreError.invalidImageData(index: index)
                }

                let fileName = String(format: "page-%02d.jpg", index + 1)
                let fileURL = stagingDirectory.appendingPathComponent(fileName)
                try imageData.write(to: fileURL, options: [.atomic])
                paths.append(fileURL.path)
            }

            if fileManager.fileExists(atPath: destinationDirectory.path) {
                try fileManager.removeItem(at: destinationDirectory)
            }

            try fileManager.moveItem(at: stagingDirectory, to: destinationDirectory)

            return paths.enumerated().map { index, _ in
                destinationDirectory.appendingPathComponent(String(format: "page-%02d.jpg", index + 1)).path
            }
        } catch {
            if fileManager.fileExists(atPath: stagingDirectory.path) {
                try? fileManager.removeItem(at: stagingDirectory)
            }

            if let storeError = error as? ReceiptImageStoreError {
                throw storeError
            }

            throw ReceiptImageStoreError.ioFailed(error.localizedDescription)
        }
    }

    func deleteImages(for sessionId: UUID) throws {
        let sessionDirectory = baseDirectory.appendingPathComponent(sessionId.uuidString, isDirectory: true)
        guard fileManager.fileExists(atPath: sessionDirectory.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: sessionDirectory)
        } catch {
            throw ReceiptImageStoreError.ioFailed(error.localizedDescription)
        }
    }

    func loadImage(atPath path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    private func ensureDirectoryExists(_ directory: URL) throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}

private extension UIImage {
    func resizedKeepingAspectRatio(maxLongestEdge: CGFloat) -> UIImage {
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxLongestEdge else {
            return self
        }

        let scaleFactor = maxLongestEdge / longestEdge
        let targetSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

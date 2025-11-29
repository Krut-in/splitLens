//
//  ShareSheet.swift
//  SplitLens
//
//  UIKit share sheet integration wrapper
//

import SwiftUI
import UIKit

/// UIViewControllerRepresentable wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    // MARK: - Properties
    
    let items: [Any]
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

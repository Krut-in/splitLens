//
//  ImageReorderSheet.swift
//  SplitLens
//
//  Sheet for reordering multi-page receipt images with drag & drop
//

import SwiftUI

/// Sheet view for reordering receipt images using drag and drop
struct ImageReorderSheet: View {
    // MARK: - Properties
    
    @Binding var images: [UIImage]
    @Binding var isPresented: Bool
    let onReorderComplete: () -> Void
    
    // MARK: - State
    
    @State private var editMode: EditMode = .active
    @State private var hasChanges = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Instructions banner
                HStack(spacing: 12) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Drag to Reorder")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        Text("Arrange pages in the order they appear on your receipt")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                
                // Image list with reordering
                List {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ImageReorderRow(image: image, pageNumber: index + 1)
                    }
                    .onMove { from, to in
                        images.move(fromOffsets: from, toOffset: to)
                        hasChanges = true
                        HapticFeedback.shared.selection()
                    }
                    .onDelete { offsets in
                        images.remove(atOffsets: offsets)
                        hasChanges = true
                        HapticFeedback.shared.lightImpact()
                    }
                }
                .listStyle(.insetGrouped)
                .environment(\.editMode, $editMode)
            }
            .navigationTitle("Reorder Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if hasChanges {
                            onReorderComplete()
                        }
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Image Reorder Row

struct ImageReorderRow: View {
    let image: UIImage
    let pageNumber: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Page number badge
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Text("\(pageNumber)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }
            
            // Thumbnail
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // Page label
            VStack(alignment: .leading, spacing: 4) {
                Text("Page \(pageNumber)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("Tap and hold to drag")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    ImageReorderSheet(
        images: .constant([UIImage(systemName: "doc")!, UIImage(systemName: "doc.fill")!]),
        isPresented: .constant(true),
        onReorderComplete: {}
    )
}

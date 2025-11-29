//
//  Route.swift
//  SplitLens
//
//  Navigation routes for the app
//

import Foundation

/// Navigation routes for NavigationStack
enum Route: Hashable {
    case imageUpload
    case itemsEditor([ReceiptItem])
    case participantsEntry([ReceiptItem])
    case itemAssignment([ReceiptItem], [String], String, Double)
    case finalReport(ReceiptSession)
    case history
    case sessionDetail(ReceiptSession)
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .imageUpload:
            hasher.combine("imageUpload")
        case .itemsEditor(let items):
            hasher.combine("itemsEditor")
            hasher.combine(items.map { $0.id })
        case .participantsEntry(let items):
            hasher.combine("participantsEntry")
            hasher.combine(items.map { $0.id })
        case .itemAssignment(let items, let participants, let paidBy, let total):
            hasher.combine("itemAssignment")
            hasher.combine(items.map { $0.id })
            hasher.combine(participants)
            hasher.combine(paidBy)
            hasher.combine(total)
        case .finalReport(let session):
            hasher.combine("finalReport")
            hasher.combine(session.id)
        case .history:
            hasher.combine("history")
        case .sessionDetail(let session):
            hasher.combine("sessionDetail")
            hasher.combine(session.id)
        }
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.imageUpload, .imageUpload):
            return true
        case (.itemsEditor(let lItems), .itemsEditor(let rItems)):
            return lItems.map { $0.id } == rItems.map { $0.id }
        case (.participantsEntry(let lItems), .participantsEntry(let rItems)):
            return lItems.map { $0.id } == rItems.map { $0.id }
        case (.itemAssignment(let lItems, let lPart, let lPaid, let lTotal),
              .itemAssignment(let rItems, let rPart, let rPaid, let rTotal)):
            return lItems.map { $0.id } == rItems.map { $0.id } &&
                   lPart == rPart &&
                   lPaid == rPaid &&
                   lTotal == rTotal
        case (.finalReport(let lSession), .finalReport(let rSession)):
            return lSession.id == rSession.id
        case (.history, .history):
            return true
        case (.sessionDetail(let lSession), .sessionDetail(let rSession)):
            return lSession.id == rSession.id
        default:
            return false
        }
    }
}

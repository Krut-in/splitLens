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
    case itemsEditor([ReceiptItem], [Fee])
    case participantsEntry([ReceiptItem], [Fee])
    case taxTipAllocation([ReceiptItem], [Fee], [String], String, Double)
    case itemAssignment([ReceiptItem], [String], String, Double, [FeeAllocation])
    case finalReport(ReceiptSession)
    case history
    case sessionDetail(ReceiptSession)
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .imageUpload:
            hasher.combine("imageUpload")
        case .itemsEditor(let items, let fees):
            hasher.combine("itemsEditor")
            hasher.combine(items.map { $0.id })
            hasher.combine(fees.map { $0.amount })
        case .participantsEntry(let items, let fees):
            hasher.combine("participantsEntry")
            hasher.combine(items.map { $0.id })
            hasher.combine(fees.map { $0.amount })
        case .taxTipAllocation(let items, let fees, let participants, let paidBy, let total):
            hasher.combine("taxTipAllocation")
            hasher.combine(items.map { $0.id })
            hasher.combine(fees.map { $0.amount })
            hasher.combine(participants)
            hasher.combine(paidBy)
            hasher.combine(total)
        case .itemAssignment(let items, let participants, let paidBy, let total, let feeAllocations):
            hasher.combine("itemAssignment")
            hasher.combine(items.map { $0.id })
            hasher.combine(participants)
            hasher.combine(paidBy)
            hasher.combine(total)
            hasher.combine(feeAllocations.map { $0.id })
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
        case (.itemsEditor(let lItems, let lFees), .itemsEditor(let rItems, let rFees)):
            return lItems.map { $0.id } == rItems.map { $0.id } &&
                   lFees.map { $0.amount } == rFees.map { $0.amount }
        case (.participantsEntry(let lItems, let lFees), .participantsEntry(let rItems, let rFees)):
            return lItems.map { $0.id } == rItems.map { $0.id } &&
                   lFees.map { $0.amount } == rFees.map { $0.amount }
        case (.taxTipAllocation(let lItems, let lFees, let lPart, let lPaid, let lTotal),
              .taxTipAllocation(let rItems, let rFees, let rPart, let rPaid, let rTotal)):
            return lItems.map { $0.id } == rItems.map { $0.id } &&
                   lFees.map { $0.amount } == rFees.map { $0.amount } &&
                   lPart == rPart &&
                   lPaid == rPaid &&
                   lTotal == rTotal
        case (.itemAssignment(let lItems, let lPart, let lPaid, let lTotal, let lFees),
              .itemAssignment(let rItems, let rPart, let rPaid, let rTotal, let rFees)):
            return lItems.map { $0.id } == rItems.map { $0.id } &&
                   lPart == rPart &&
                   lPaid == rPaid &&
                   lTotal == rTotal &&
                   lFees.map { $0.id } == rFees.map { $0.id }
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

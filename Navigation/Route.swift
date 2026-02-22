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
    case itemsEditor([ReceiptItem], [Fee], ScanMetadata)
    case participantsEntry([ReceiptItem], [Fee], ScanMetadata)
    case taxTipAllocation([ReceiptItem], [Fee], [String], String, Double, ScanMetadata)
    case itemAssignment([ReceiptItem], [String], String, Double, [FeeAllocation], ScanMetadata)
    case finalReport(ReceiptSession, ScanMetadata)
    case history
    case sessionDetail(ReceiptSession)
    case groupManagement
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .imageUpload:
            hasher.combine("imageUpload")
        case .itemsEditor(let items, let fees, let metadata):
            hasher.combine("itemsEditor")
            hasher.combine(items.map { $0.id })
            hasher.combine(fees.map { $0.amount })
            hasher.combine(metadata.id)
        case .participantsEntry(let items, let fees, let metadata):
            hasher.combine("participantsEntry")
            hasher.combine(items.map { $0.id })
            hasher.combine(fees.map { $0.amount })
            hasher.combine(metadata.id)
        case .taxTipAllocation(let items, let fees, let participants, let paidBy, let total, let metadata):
            hasher.combine("taxTipAllocation")
            hasher.combine(items.map { $0.id })
            hasher.combine(fees.map { $0.amount })
            hasher.combine(participants)
            hasher.combine(paidBy)
            hasher.combine(total)
            hasher.combine(metadata.id)
        case .itemAssignment(let items, let participants, let paidBy, let total, let feeAllocations, let metadata):
            hasher.combine("itemAssignment")
            hasher.combine(items.map { $0.id })
            hasher.combine(participants)
            hasher.combine(paidBy)
            hasher.combine(total)
            hasher.combine(feeAllocations.map { $0.id })
            hasher.combine(metadata.id)
        case .finalReport(let session, let metadata):
            hasher.combine("finalReport")
            hasher.combine(session.id)
            hasher.combine(metadata.id)
        case .history:
            hasher.combine("history")
        case .sessionDetail(let session):
            hasher.combine("sessionDetail")
            hasher.combine(session.id)
        case .groupManagement:
            hasher.combine("groupManagement")
        }
    }
    
    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.imageUpload, .imageUpload):
            return true
        case (.itemsEditor(let lItems, let lFees, let lMeta), .itemsEditor(let rItems, let rFees, let rMeta)):
            return lItems.map { $0.id } == rItems.map { $0.id } &&
                   lFees.map { $0.amount } == rFees.map { $0.amount } &&
                   lMeta.id == rMeta.id
        case (.participantsEntry(let lItems, let lFees, let lMeta), .participantsEntry(let rItems, let rFees, let rMeta)):
            return lItems.map { $0.id } == rItems.map { $0.id } &&
                   lFees.map { $0.amount } == rFees.map { $0.amount } &&
                   lMeta.id == rMeta.id
        case (.taxTipAllocation(let lItems, let lFees, let lPart, let lPaid, let lTotal, let lMeta),
              .taxTipAllocation(let rItems, let rFees, let rPart, let rPaid, let rTotal, let rMeta)):
            return lItems.map { $0.id } == rItems.map { $0.id } &&
                   lFees.map { $0.amount } == rFees.map { $0.amount } &&
                   lPart == rPart &&
                   lPaid == rPaid &&
                   lTotal == rTotal &&
                   lMeta.id == rMeta.id
        case (.itemAssignment(let lItems, let lPart, let lPaid, let lTotal, let lFees, let lMeta),
              .itemAssignment(let rItems, let rPart, let rPaid, let rTotal, let rFees, let rMeta)):
            return lItems.map { $0.id } == rItems.map { $0.id } &&
                   lPart == rPart &&
                   lPaid == rPaid &&
                   lTotal == rTotal &&
                   lFees.map { $0.id } == rFees.map { $0.id } &&
                   lMeta.id == rMeta.id
        case (.finalReport(let lSession, let lMeta), .finalReport(let rSession, let rMeta)):
            return lSession.id == rSession.id && lMeta.id == rMeta.id
        case (.history, .history):
            return true
        case (.sessionDetail(let lSession), .sessionDetail(let rSession)):
            return lSession.id == rSession.id
        case (.groupManagement, .groupManagement):
            return true
        default:
            return false
        }
    }
}

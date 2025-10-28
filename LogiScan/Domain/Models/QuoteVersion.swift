//
//  QuoteVersion.swift
//  LogiScan
//
//  Created by Assistant on 27/10/2025.
//

import Foundation
import SwiftData

@Model
final class QuoteVersion {
    @Attribute(.unique) var versionId: String
    var eventId: String
    var versionNumber: Int
    var createdAt: Date
    var createdBy: String  // userId
    var createdByName: String
    
    // URL du PDF dans Firebase Storage
    var pdfStoragePath: String  // Ex: "quotes/EVENT123/versions/v1.pdf"
    var pdfUrl: String?  // URL de téléchargement (peut être régénérée)
    
    // Snapshot des données du devis à ce moment
    var totalAmount: Double
    var finalAmount: Double
    var discountPercent: Double
    var deliveryFee: Double
    var assemblyFee: Double
    var disassemblyFee: Double
    var tvaRate: Double
    
    // Status de cette version
    var status: String  // "draft", "finalized", "sent", "accepted", "refused"
    
    // Notes optionnelles sur cette version
    var notes: String
    
    init(
        versionId: String = UUID().uuidString,
        eventId: String,
        versionNumber: Int,
        createdBy: String,
        createdByName: String,
        pdfStoragePath: String,
        pdfUrl: String? = nil,
        totalAmount: Double,
        finalAmount: Double,
        discountPercent: Double,
        deliveryFee: Double = 0.0,
        assemblyFee: Double = 0.0,
        disassemblyFee: Double = 0.0,
        tvaRate: Double = 20.0,
        status: String = "finalized",
        notes: String = ""
    ) {
        self.versionId = versionId
        self.eventId = eventId
        self.versionNumber = versionNumber
        self.createdAt = Date()
        self.createdBy = createdBy
        self.createdByName = createdByName
        self.pdfStoragePath = pdfStoragePath
        self.pdfUrl = pdfUrl
        self.totalAmount = totalAmount
        self.finalAmount = finalAmount
        self.discountPercent = discountPercent
        self.deliveryFee = deliveryFee
        self.assemblyFee = assemblyFee
        self.disassemblyFee = disassemblyFee
        self.tvaRate = tvaRate
        self.status = status
        self.notes = notes
    }
    
    /// Nom de fichier pour l'affichage
    var displayName: String {
        return "Version \(versionNumber) - \(formattedDate)"
    }
    
    /// Date formatée
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    /// Icône selon le statut
    var statusIcon: String {
        switch status {
        case "draft": return "doc.text"
        case "finalized": return "checkmark.seal.fill"
        case "sent": return "paperplane.fill"
        case "accepted": return "hand.thumbsup.fill"
        case "refused": return "hand.thumbsdown.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - Firestore Codable Version

struct FirestoreQuoteVersion: Codable {
    var versionId: String
    var eventId: String
    var versionNumber: Int
    var createdAt: Date
    var createdBy: String
    var createdByName: String
    var pdfStoragePath: String
    var pdfUrl: String?
    var totalAmount: Double
    var finalAmount: Double
    var discountPercent: Double
    var deliveryFee: Double
    var assemblyFee: Double
    var disassemblyFee: Double
    var tvaRate: Double
    var status: String
    var notes: String
    var quoteItemsSnapshot: [FirestoreQuoteItemSnapshot]  // Snapshot des items
    
    /// Convertir vers SwiftData
    func toSwiftData() -> QuoteVersion {
        return QuoteVersion(
            versionId: versionId,
            eventId: eventId,
            versionNumber: versionNumber,
            createdBy: createdBy,
            createdByName: createdByName,
            pdfStoragePath: pdfStoragePath,
            pdfUrl: pdfUrl,
            totalAmount: totalAmount,
            finalAmount: finalAmount,
            discountPercent: discountPercent,
            deliveryFee: deliveryFee,
            assemblyFee: assemblyFee,
            disassemblyFee: disassemblyFee,
            tvaRate: tvaRate,
            status: status,
            notes: notes
        )
    }
}

// MARK: - Snapshot des QuoteItems (pour historique)

struct FirestoreQuoteItemSnapshot: Codable {
    var sku: String
    var name: String
    var category: String
    var quantity: Int
    var unitPrice: Double
    var totalPrice: Double
}

extension QuoteVersion {
    /// Convertir vers Firestore (sans les items, ils sont gérés séparément)
    func toFirestore(quoteItems: [QuoteItem]) -> FirestoreQuoteVersion {
        return FirestoreQuoteVersion(
            versionId: versionId,
            eventId: eventId,
            versionNumber: versionNumber,
            createdAt: createdAt,
            createdBy: createdBy,
            createdByName: createdByName,
            pdfStoragePath: pdfStoragePath,
            pdfUrl: pdfUrl,
            totalAmount: totalAmount,
            finalAmount: finalAmount,
            discountPercent: discountPercent,
            deliveryFee: deliveryFee,
            assemblyFee: assemblyFee,
            disassemblyFee: disassemblyFee,
            tvaRate: tvaRate,
            status: status,
            notes: notes,
            quoteItemsSnapshot: quoteItems.map { item in
                FirestoreQuoteItemSnapshot(
                    sku: item.sku,
                    name: item.name,
                    category: item.category,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    totalPrice: item.totalPrice
                )
            }
        )
    }
}

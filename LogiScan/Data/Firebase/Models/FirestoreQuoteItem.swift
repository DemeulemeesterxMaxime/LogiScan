//
//  FirestoreQuoteItem.swift
//  LogiScan
//
//  Created by Demeulemeester on 12/10/2025.
//

import Foundation

/// Représentation Firestore d'un QuoteItem
struct FirestoreQuoteItem: Codable {
    var quoteItemId: String
    var eventId: String
    var sku: String
    var name: String
    var category: String
    var quantity: Int
    var unitPrice: Double
    var customPrice: Double
    var totalPrice: Double
    var assignedAssets: [String]
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case quoteItemId
        case eventId
        case sku
        case name
        case category
        case quantity
        case unitPrice
        case customPrice
        case totalPrice
        case assignedAssets
        case createdAt
        case updatedAt
    }
}

// MARK: - Extensions de conversion

extension QuoteItem {
    /// Convertir vers Firestore
    func toFirestoreQuoteItem() -> FirestoreQuoteItem {
        FirestoreQuoteItem(
            quoteItemId: quoteItemId,
            eventId: eventId,
            sku: sku,
            name: name,
            category: category,
            quantity: quantity,
            unitPrice: unitPrice,
            customPrice: customPrice,
            totalPrice: totalPrice,
            assignedAssets: assignedAssets,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension FirestoreQuoteItem {
    /// Convertir vers SwiftData QuoteItem
    func toQuoteItem() -> QuoteItem {
        QuoteItem(
            quoteItemId: quoteItemId,
            eventId: eventId,
            sku: sku,
            name: name,
            category: category,
            quantity: quantity,
            unitPrice: unitPrice,
            customPrice: customPrice,
            assignedAssets: assignedAssets
        )
    }
}

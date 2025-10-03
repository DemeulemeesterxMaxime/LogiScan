//
//  FirestoreStockItem.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import FirebaseFirestore
import Foundation

/// Modèle Firestore pour les références produits (StockItem)
struct FirestoreStockItem: Codable, Identifiable {
    @DocumentID var id: String?
    var sku: String
    var name: String
    var category: String
    var itemDescription: String
    var quantity: Int
    var unitPrice: Double
    var itemWeight: Double
    var itemVolume: Double
    var tags: [String]
    var isSerialized: Bool

    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case sku
        case name
        case category
        case itemDescription = "description"
        case quantity
        case unitPrice
        case itemWeight = "weight"
        case itemVolume = "volume"
        case tags
        case isSerialized
        case createdAt
        case updatedAt
    }

    /// Convertir vers le modèle SwiftData local (pour cache)
    func toStockItem() -> StockItem {
        StockItem(
            sku: sku,
            name: name,
            category: category,
            itemDescription: itemDescription,
            totalQuantity: quantity,
            unitWeight: itemWeight,
            unitVolume: itemVolume,
            unitValue: unitPrice,
            tags: tags
        )
    }
}

/// Extension pour convertir StockItem vers Firestore
extension StockItem {
    func toFirestoreStockItem() -> FirestoreStockItem {
        FirestoreStockItem(
            id: nil,
            sku: sku,
            name: name,
            category: category,
            itemDescription: itemDescription,
            quantity: totalQuantity,
            unitPrice: unitValue,
            itemWeight: unitWeight,
            itemVolume: unitVolume,
            tags: tags,
            isSerialized: false,  // Valeur par défaut
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

//
//  QuoteItem.swift
//  LogiScan
//
//  Created by Demeulemeester on 02/10/2025.
//

import Foundation
import SwiftData

@Model
final class QuoteItem {
    var quoteItemId: String
    var eventId: String
    var sku: String
    var name: String
    var category: String
    var quantity: Int
    var unitPrice: Double  // Prix configuré dans StockItem
    var customPrice: Double  // Prix modifié dans le devis
    var totalPrice: Double  // customPrice * quantity
    
    @Attribute(.externalStorage)
    var assignedAssets: [String]  // Liste asset IDs spécifiques
    
    var createdAt: Date
    var updatedAt: Date

    init(
        quoteItemId: String,
        eventId: String,
        sku: String,
        name: String,
        category: String,
        quantity: Int,
        unitPrice: Double,
        customPrice: Double? = nil,
        assignedAssets: [String] = []
    ) {
        self.quoteItemId = quoteItemId
        self.eventId = eventId
        self.sku = sku
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.customPrice = customPrice ?? unitPrice
        self.totalPrice = (customPrice ?? unitPrice) * Double(quantity)
        self.assignedAssets = assignedAssets
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // Calcul du pourcentage de remise/augmentation
    var discountPercent: Double {
        guard unitPrice > 0 else { return 0 }
        return ((customPrice - unitPrice) / unitPrice) * 100
    }

    // Mise à jour du prix personnalisé
    func updateCustomPrice(_ newPrice: Double) {
        self.customPrice = newPrice
        self.totalPrice = newPrice * Double(quantity)
        self.updatedAt = Date()
    }

    // Mise à jour de la quantité
    func updateQuantity(_ newQuantity: Int) {
        self.quantity = newQuantity
        self.totalPrice = customPrice * Double(newQuantity)
        self.updatedAt = Date()
    }
}

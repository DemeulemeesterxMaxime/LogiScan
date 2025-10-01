//
//  StockItem.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

@Model
final class StockItem {
    @Attribute(.unique) var sku: String
    var name: String
    var category: String
    var totalQuantity: Int
    var maintenanceQuantity: Int
    var unitWeight: Double
    var unitVolume: Double
    var unitValue: Double
    var images: [String] // URLs ou noms de fichiers
    var substituables: [String] // SKUs équivalents
    var createdAt: Date
    var updatedAt: Date
    
    init(
        sku: String,
        name: String,
        category: String,
        totalQuantity: Int = 0,
        maintenanceQuantity: Int = 0,
        unitWeight: Double,
        unitVolume: Double,
        unitValue: Double,
        images: [String] = [],
        substituables: [String] = []
    ) {
        self.sku = sku
        self.name = name
        self.category = category
        self.totalQuantity = totalQuantity
        self.maintenanceQuantity = maintenanceQuantity
        self.unitWeight = unitWeight
        self.unitVolume = unitVolume
        self.unitValue = unitValue
        self.images = images
        self.substituables = substituables
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var availableQuantity: Int {
        totalQuantity - maintenanceQuantity
    }
}

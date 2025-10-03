//
//  StockItem.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

// MARK: - Ownership Type
enum OwnershipType: String, Codable, CaseIterable {
    case owned = "PROPRIETE"
    case rented = "LOCATION"

    var displayName: String {
        switch self {
        case .owned: return "Notre matériel"
        case .rented: return "Location"
        }
    }

    var icon: String {
        switch self {
        case .owned: return "house.fill"
        case .rented: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Dimensions
struct Dimensions: Codable, Equatable {
    var length: Double  // cm
    var width: Double  // cm
    var height: Double  // cm

    var volumeInM3: Double {
        // Conversion de cm³ en m³
        (length * width * height) / 1_000_000
    }

    var displayString: String {
        String(format: "%.0f × %.0f × %.0f cm", length, width, height)
    }
}

// MARK: - StockItem Model
@Model
final class StockItem {
    var sku: String  // Retiré @Attribute(.unique) temporairement
    var name: String
    var category: String
    var itemDescription: String  // Description technique détaillée
    var totalQuantity: Int
    var maintenanceQuantity: Int
    var unitWeight: Double
    var unitVolume: Double
    var unitValue: Double
    var images: [String]  // URLs ou noms de fichiers
    var substituables: [String]  // SKUs équivalents
    var tags: [String]  // Étiquettes personnalisables

    // Nouveaux champs - Propriété et tarification
    var ownershipType: OwnershipType
    var rentalPrice: Double?  // Prix de location par jour (si applicable)
    var purchasePrice: Double?  // Prix d'achat initial

    // Nouveaux champs - Caractéristiques techniques
    var dimensions: Dimensions?
    var powerConsumption: Double?  // Consommation électrique en W
    var technicalSpecs: [String: String]  // Specs techniques flexibles (ex: {"Voltage": "220V", "Poids net": "2.5kg"})

    var createdAt: Date
    var updatedAt: Date

    init(
        sku: String,
        name: String,
        category: String,
        itemDescription: String = "",
        totalQuantity: Int = 0,
        maintenanceQuantity: Int = 0,
        unitWeight: Double,
        unitVolume: Double,
        unitValue: Double,
        images: [String] = [],
        substituables: [String] = [],
        tags: [String] = [],
        ownershipType: OwnershipType = .owned,
        rentalPrice: Double? = nil,
        purchasePrice: Double? = nil,
        dimensions: Dimensions? = nil,
        powerConsumption: Double? = nil,
        technicalSpecs: [String: String] = [:]
    ) {
        self.sku = sku
        self.name = name
        self.category = category
        self.itemDescription = itemDescription
        self.totalQuantity = totalQuantity
        self.maintenanceQuantity = maintenanceQuantity
        self.unitWeight = unitWeight
        self.unitVolume = unitVolume
        self.unitValue = unitValue
        self.images = images
        self.substituables = substituables
        self.tags = tags
        self.ownershipType = ownershipType
        self.rentalPrice = rentalPrice
        self.purchasePrice = purchasePrice
        self.dimensions = dimensions
        self.powerConsumption = powerConsumption
        self.technicalSpecs = technicalSpecs
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var availableQuantity: Int {
        totalQuantity - maintenanceQuantity
    }

    // Prix effectif selon le type de propriété
    var effectivePrice: Double {
        switch ownershipType {
        case .owned:
            return unitValue
        case .rented:
            return rentalPrice ?? unitValue
        }
    }
}

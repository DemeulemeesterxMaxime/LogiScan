//
//  Asset.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

@Model
final class Asset {
    var assetId: String // Retiré @Attribute(.unique) temporairement
    var sku: String
    var name: String
    var category: String
    var serialNumber: String?
    var status: AssetStatus
    var weight: Double
    var volume: Double
    var value: Double
    var qrPayload: String
    var currentLocationId: String?
    
    // Nouveaux champs
    var comments: String // Commentaires (état, dommages, etc.)
    var tags: [String] // Étiquettes héritées + spécifiques
    var lastMaintenanceDate: Date?
    var nextMaintenanceDate: Date?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(
        assetId: String,
        sku: String,
        name: String,
        category: String,
        serialNumber: String? = nil,
        status: AssetStatus = .available,
        weight: Double,
        volume: Double,
        value: Double,
        qrPayload: String,
        currentLocationId: String? = nil,
        comments: String = "",
        tags: [String] = [],
        lastMaintenanceDate: Date? = nil,
        nextMaintenanceDate: Date? = nil
    ) {
        self.assetId = assetId
        self.sku = sku
        self.name = name
        self.category = category
        self.serialNumber = serialNumber
        self.status = status
        self.weight = weight
        self.volume = volume
        self.value = value
        self.qrPayload = qrPayload
        self.currentLocationId = currentLocationId
        self.comments = comments
        self.tags = tags
        self.lastMaintenanceDate = lastMaintenanceDate
        self.nextMaintenanceDate = nextMaintenanceDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Propriété calculée pour savoir si l'asset est disponible
    var isAvailable: Bool {
        status == .available
    }
    
    // Vérifie si maintenance est nécessaire
    var needsMaintenance: Bool {
        guard let nextDate = nextMaintenanceDate else { return false }
        return nextDate <= Date()
    }
}

enum AssetStatus: String, CaseIterable, Codable {
    case available = "DISPONIBLE"
    case reserved = "RESERVE"
    case inUse = "EN_UTILISATION"
    case damaged = "ENDOMMAGE"
    case maintenance = "MAINTENANCE"
    case lost = "PERDU"
    
    var displayName: String {
        switch self {
        case .available: return "Disponible"
        case .reserved: return "Réservé"
        case .inUse: return "En utilisation"
        case .damaged: return "Endommagé"
        case .maintenance: return "En maintenance"
        case .lost: return "Perdu"
        }
    }
    
    var color: String {
        switch self {
        case .available: return "green"
        case .reserved: return "blue"
        case .inUse: return "purple"
        case .damaged: return "red"
        case .maintenance: return "orange"
        case .lost: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .available: return "checkmark.circle.fill"
        case .reserved: return "calendar.badge.clock"
        case .inUse: return "arrow.right.circle.fill"
        case .damaged: return "exclamationmark.triangle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .lost: return "questionmark.circle.fill"
        }
    }
}

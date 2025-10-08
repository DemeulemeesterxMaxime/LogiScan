//
//  Movement.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

@Model
final class Movement {
    var movementId: String // Retiré @Attribute(.unique) temporairement
    var type: MovementType
    var assetId: String?
    var sku: String?
    var quantity: Int
    var fromLocationId: String?
    var toLocationId: String?
    var performedBy: String? // User ID
    var timestamp: Date
    var eventId: String?
    var orderId: String?
    var scanPayload: String?
    var notes: String
    var isSynced: Bool // Pour la sync offline
    
    init(
        movementId: String = UUID().uuidString,
        type: MovementType,
        assetId: String? = nil,
        sku: String? = nil,
        quantity: Int = 1,
        fromLocationId: String? = nil,
        toLocationId: String? = nil,
        performedBy: String? = nil,
        timestamp: Date = Date(),
        eventId: String? = nil,
        orderId: String? = nil,
        scanPayload: String? = nil,
        notes: String = "",
        isSynced: Bool = false
    ) {
        self.movementId = movementId
        self.type = type
        self.assetId = assetId
        self.sku = sku
        self.quantity = quantity
        self.fromLocationId = fromLocationId
        self.toLocationId = toLocationId
        self.performedBy = performedBy
        self.timestamp = timestamp
        self.eventId = eventId
        self.orderId = orderId
        self.scanPayload = scanPayload
        self.notes = notes
        self.isSynced = isSynced
    }
}

enum MovementType: String, CaseIterable, Codable {
    case reserve = "RESERVE"
    case pick = "PICK"
    case load = "LOAD"
    case unload = "UNLOAD"
    case reload = "RELOAD"
    case returnWarehouse = "RETURN"
    case transfer = "TRANSFER"
    case maintenanceIn = "MAINTENANCE_IN"
    case maintenanceOut = "MAINTENANCE_OUT"
    
    var displayName: String {
        switch self {
        case .reserve: return "Réservation"
        case .pick: return "Préparation"
        case .load: return "Chargement"
        case .unload: return "Déchargement"
        case .reload: return "Rechargement"
        case .returnWarehouse: return "Retour"
        case .transfer: return "Transfert"
        case .maintenanceIn: return "Entrée maintenance"
        case .maintenanceOut: return "Sortie maintenance"
        }
    }
    
    var icon: String {
        switch self {
        case .reserve: return "calendar.badge.plus"
        case .pick: return "hand.point.up"
        case .load: return "arrow.up.square"
        case .unload: return "arrow.down.square"
        case .reload: return "arrow.clockwise"
        case .returnWarehouse: return "arrow.uturn.left"
        case .transfer: return "arrow.left.arrow.right"
        case .maintenanceIn: return "wrench"
        case .maintenanceOut: return "checkmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .reserve: return "blue"
        case .pick: return "orange"
        case .load: return "green"
        case .unload: return "red"
        case .reload: return "purple"
        case .returnWarehouse: return "brown"
        case .transfer: return "teal"
        case .maintenanceIn: return "yellow"
        case .maintenanceOut: return "mint"
        }
    }
}

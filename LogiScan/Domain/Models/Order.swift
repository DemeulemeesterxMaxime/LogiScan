//
//  Order.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

@Model
final class Order {
    @Attribute(.unique) var orderId: String
    var eventId: String
    var status: OrderStatus
    var assignedTruckId: String?
    var prepLeadHours: Int // Temps de préparation en heures
    var returnBufferHours: Int // Marge de retour en heures
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    
    // Relations
    @Relationship(deleteRule: .cascade) var orderLines: [OrderLine] = []
    @Relationship(deleteRule: .cascade) var timestamps: [OrderTimestamp] = []
    
    init(
        orderId: String,
        eventId: String,
        status: OrderStatus = .quoteDraft,
        assignedTruckId: String? = nil,
        prepLeadHours: Int = 24,
        returnBufferHours: Int = 12,
        notes: String = ""
    ) {
        self.orderId = orderId
        self.eventId = eventId
        self.status = status
        self.assignedTruckId = assignedTruckId
        self.prepLeadHours = prepLeadHours
        self.returnBufferHours = returnBufferHours
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class OrderLine {
    var sku: String?
    var assetId: String?
    var requestedQuantity: Int
    var confirmedQuantity: Int
    var unitPrice: Double
    var order: Order?
    
    init(
        sku: String? = nil,
        assetId: String? = nil,
        requestedQuantity: Int,
        confirmedQuantity: Int = 0,
        unitPrice: Double = 0.0
    ) {
        self.sku = sku
        self.assetId = assetId
        self.requestedQuantity = requestedQuantity
        self.confirmedQuantity = confirmedQuantity
        self.unitPrice = unitPrice
    }
}

@Model
final class OrderTimestamp {
    var status: OrderStatus
    var timestamp: Date
    var userId: String?
    var notes: String
    var order: Order?
    
    init(
        status: OrderStatus,
        timestamp: Date = Date(),
        userId: String? = nil,
        notes: String = ""
    ) {
        self.status = status
        self.timestamp = timestamp
        self.userId = userId
        self.notes = notes
    }
}

enum OrderStatus: String, CaseIterable, Codable {
    case quoteDraft = "DEVIS_BROUILLON"
    case quoteSent = "DEVIS_ENVOYE"
    case quoteAccepted = "DEVIS_ACCEPTE"
    case preparation = "EN_PREPA"
    case ready = "PRET"
    case loadedTruck = "CHARGE_CAMION"
    case deliveredSite = "LIVRE_SITE"
    case inUse = "EN_PRESTA"
    case reloaded = "RECHARGE"
    case returnedWarehouse = "RETOUR_HANGAR"
    case closed = "CLOS"
    
    var displayName: String {
        switch self {
        case .quoteDraft: return "Devis brouillon"
        case .quoteSent: return "Devis envoyé"
        case .quoteAccepted: return "Devis accepté"
        case .preparation: return "En préparation"
        case .ready: return "Prêt"
        case .loadedTruck: return "Chargé camion"
        case .deliveredSite: return "Livré sur site"
        case .inUse: return "En prestation"
        case .reloaded: return "Rechargé"
        case .returnedWarehouse: return "Retour hangar"
        case .closed: return "Clôturé"
        }
    }
    
    var color: String {
        switch self {
        case .quoteDraft: return "gray"
        case .quoteSent: return "blue"
        case .quoteAccepted: return "green"
        case .preparation: return "orange"
        case .ready: return "purple"
        case .loadedTruck: return "teal"
        case .deliveredSite: return "indigo"
        case .inUse: return "pink"
        case .reloaded: return "yellow"
        case .returnedWarehouse: return "brown"
        case .closed: return "mint"
        }
    }
}

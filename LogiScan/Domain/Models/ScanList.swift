//
//  ScanList.swift
//  LogiScan
//
//  Created by Assistant on 15/10/2025.
//

import Foundation
import SwiftData

@Model
final class ScanList {
    @Attribute(.unique) var scanListId: String
    var eventId: String
    var eventName: String
    var scanDirection: ScanDirection  // Direction du scan (NON OPTIONAL pour SwiftData)
    var totalItems: Int
    var scannedItems: Int
    var status: ScanListStatus
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    
    // Relation avec les items
    @Relationship(deleteRule: .cascade, inverse: \PreparationListItem.scanList)
    var items: [PreparationListItem] = []
    
    init(
        scanListId: String = UUID().uuidString,
        eventId: String,
        eventName: String,
        scanDirection: ScanDirection,
        totalItems: Int = 0,
        scannedItems: Int = 0,
        status: ScanListStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.scanListId = scanListId
        self.eventId = eventId
        self.eventName = eventName
        self.scanDirection = scanDirection
        self.totalItems = totalItems
        self.scannedItems = scannedItems
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
    
    /// Progression en pourcentage (0.0 à 1.0)
    var progress: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(scannedItems) / Double(totalItems)
    }
    
    /// Progression en pourcentage (0 à 100)
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    /// Items restants à scanner
    var remainingItems: Int {
        max(0, totalItems - scannedItems)
    }
    
    /// Vérifie si la liste est complète
    var isComplete: Bool {
        scannedItems >= totalItems && totalItems > 0
    }
    
    /// Nom descriptif de la liste basé sur la direction
    var displayName: String {
        return scanDirection.listName
    }
}

enum ScanListStatus: String, Codable {
    case pending = "pending"           // En attente
    case inProgress = "in_progress"    // En cours
    case completed = "completed"       // Terminée
    case cancelled = "cancelled"       // Annulée
    
    var displayName: String {
        switch self {
        case .pending: return "En attente"
        case .inProgress: return "En cours"
        case .completed: return "Terminée"
        case .cancelled: return "Annulée"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

enum ScanDirection: String, Codable, CaseIterable {
    case stockToTruck = "stock_to_truck"       // Stock → Camion
    case truckToEvent = "truck_to_event"       // Camion → Event
    case eventToTruck = "event_to_truck"       // Event → Camion
    case truckToStock = "truck_to_stock"       // Camion → Stock
    
    var displayName: String {
        switch self {
        case .stockToTruck: return "Stock → Camion"
        case .truckToEvent: return "Camion → Événement"
        case .eventToTruck: return "Événement → Camion"
        case .truckToStock: return "Camion → Stock"
        }
    }
    
    var listName: String {
        switch self {
        case .stockToTruck: return "Stock → Camion"
        case .truckToEvent: return "Camion → Lieu livraison"
        case .eventToTruck: return "Event → Camion"
        case .truckToStock: return "Camion → Stock"
        }
    }
    
    var icon: String {
        switch self {
        case .stockToTruck: return "arrow.up.bin"
        case .truckToEvent: return "arrow.forward.circle"
        case .eventToTruck: return "arrow.backward.circle"
        case .truckToStock: return "arrow.down.circle"
        }
    }
    
    var description: String {
        switch self {
        case .stockToTruck: return "Préparer et charger le matériel dans le camion au stock"
        case .truckToEvent: return "Décharger le matériel du camion sur le site de l'événement"
        case .eventToTruck: return "Recharger le matériel dans le camion après l'événement"
        case .truckToStock: return "Décharger le matériel du camion et le ranger au stock"
        }
    }
}

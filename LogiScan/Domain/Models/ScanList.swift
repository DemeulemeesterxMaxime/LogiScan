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

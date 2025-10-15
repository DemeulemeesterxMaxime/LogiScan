//
//  PreparationListItem.swift
//  LogiScan
//
//  Created by Assistant on 15/10/2025.
//

import Foundation
import SwiftData

@Model
final class PreparationListItem {
    @Attribute(.unique) var preparationListItemId: String
    var scanListId: String
    var sku: String
    var name: String
    var category: String
    var quantityRequired: Int
    var quantityScanned: Int
    var scannedAssets: [String]  // Liste des assetId scannés
    var status: ScanItemStatus
    var lastScannedAt: Date?
    
    // Relation inverse avec ScanList
    var scanList: ScanList?
    
    init(
        preparationListItemId: String = UUID().uuidString,
        scanListId: String,
        sku: String,
        name: String,
        category: String,
        quantityRequired: Int,
        quantityScanned: Int = 0,
        scannedAssets: [String] = [],
        status: ScanItemStatus = .pending,
        lastScannedAt: Date? = nil
    ) {
        self.preparationListItemId = preparationListItemId
        self.scanListId = scanListId
        self.sku = sku
        self.name = name
        self.category = category
        self.quantityRequired = quantityRequired
        self.quantityScanned = quantityScanned
        self.scannedAssets = scannedAssets
        self.status = status
        self.lastScannedAt = lastScannedAt
    }
    
    /// Items restants à scanner
    var remainingQuantity: Int {
        max(0, quantityRequired - quantityScanned)
    }
    
    /// Progression en pourcentage (0.0 à 1.0)
    var progress: Double {
        guard quantityRequired > 0 else { return 0.0 }
        return Double(quantityScanned) / Double(quantityRequired)
    }
    
    /// Progression en pourcentage (0 à 100)
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    /// Vérifie si l'item est complètement scanné
    var isComplete: Bool {
        quantityScanned >= quantityRequired && quantityRequired > 0
    }
    
    /// Met à jour le statut en fonction de la progression
    func updateStatus() {
        if quantityScanned >= quantityRequired {
            status = .completed
        } else if quantityScanned > 0 {
            status = .partial
        } else {
            status = .pending
        }
    }
    
    /// Ajoute un asset scanné
    func addScannedAsset(_ assetId: String) {
        if !scannedAssets.contains(assetId) {
            scannedAssets.append(assetId)
            quantityScanned = scannedAssets.count
            lastScannedAt = Date()
            updateStatus()
        }
    }
    
    /// Retire un asset scanné
    func removeScannedAsset(_ assetId: String) {
        if let index = scannedAssets.firstIndex(of: assetId) {
            scannedAssets.remove(at: index)
            quantityScanned = scannedAssets.count
            updateStatus()
        }
    }
}

enum ScanItemStatus: String, Codable {
    case pending = "pending"     // En attente
    case partial = "partial"     // Partiellement scanné
    case completed = "completed" // Complètement scanné
    
    var displayName: String {
        switch self {
        case .pending: return "À scanner"
        case .partial: return "Partiel"
        case .completed: return "Terminé"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "circle"
        case .partial: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "gray"
        case .partial: return "orange"
        case .completed: return "green"
        }
    }
}

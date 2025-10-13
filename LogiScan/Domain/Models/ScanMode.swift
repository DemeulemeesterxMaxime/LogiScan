//
//  ScanMode.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import Foundation
import SwiftUI

/// Mode de scan qui détermine le comportement et les actions disponibles
enum ScanMode: String, CaseIterable, Identifiable, Codable {
    case free = "FREE"
    case inventory = "INVENTORY"
    case stockToTruck = "STOCK_TO_TRUCK"
    case truckToEvent = "TRUCK_TO_EVENT"
    case eventToTruck = "EVENT_TO_TRUCK"
    case truckToStock = "TRUCK_TO_STOCK"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .free:
            return "Scan libre"
        case .inventory:
            return "Inventaire"
        case .stockToTruck:
            return "Stock → Camion"
        case .truckToEvent:
            return "Camion → Événement"
        case .eventToTruck:
            return "Événement → Camion"
        case .truckToStock:
            return "Camion → Stock"
        }
    }
    
    var description: String {
        switch self {
        case .free:
            return "Scanner un asset pour consulter ses détails"
        case .inventory:
            return "Compter et vérifier le stock disponible"
        case .stockToTruck:
            return "Charger un camion depuis le dépôt"
        case .truckToEvent:
            return "Décharger le camion sur le site d'événement"
        case .eventToTruck:
            return "Remettre le matériel dans le camion"
        case .truckToStock:
            return "Ranger le matériel au dépôt"
        }
    }
    
    var icon: String {
        switch self {
        case .free:
            return "qrcode.viewfinder"
        case .inventory:
            return "list.clipboard"
        case .stockToTruck:
            return "arrow.right.to.line.circle.fill"
        case .truckToEvent:
            return "truck.box.fill"
        case .eventToTruck:
            return "arrow.uturn.backward.circle.fill"
        case .truckToStock:
            return "arrow.left.to.line.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .free:
            return .blue
        case .inventory:
            return .purple
        case .stockToTruck:
            return .green
        case .truckToEvent:
            return .orange
        case .eventToTruck:
            return .yellow
        case .truckToStock:
            return .cyan
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .free:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .inventory:
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .stockToTruck:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .truckToEvent:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .eventToTruck:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .truckToStock:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    /// Détermine les mouvements à créer automatiquement selon le mode
    var autoMovementType: MovementType? {
        switch self {
        case .stockToTruck:
            return .load // Chargement du camion
        case .truckToEvent:
            return .unload // Déchargement sur site
        case .eventToTruck:
            return .reload // Rechargement
        case .truckToStock:
            return .returnWarehouse // Retour au dépôt
        case .free, .inventory:
            return nil // Pas de mouvement automatique
        }
    }
    
    /// Source et destination automatiques selon le mode
    func getAutoLocations(truckId: String?, eventId: String?) -> (from: String?, to: String?) {
        switch self {
        case .stockToTruck:
            return (from: "DEPOT", to: truckId)
        case .truckToEvent:
            return (from: truckId, to: eventId)
        case .eventToTruck:
            return (from: eventId, to: truckId)
        case .truckToStock:
            return (from: truckId, to: "DEPOT")
        case .free, .inventory:
            return (from: nil, to: nil)
        }
    }
    
    /// Permission requise pour ce mode
    var requiredPermission: User.Permission? {
        switch self {
        case .free:
            return .scanQR
        case .inventory:
            return .readStock
        case .stockToTruck, .truckToEvent, .eventToTruck, .truckToStock:
            return .updateAssetStatus // Modification d'assets
        }
    }
}

/// Session de scan pour tracer l'activité
struct ScanSession: Identifiable, Codable {
    let id: String
    let mode: ScanMode
    let startedAt: Date
    var endedAt: Date?
    var scannedAssets: [String] // Asset IDs
    var expectedAssets: [String]? // Pour le mode avec liste
    var truckId: String?
    var eventId: String?
    var userId: String
    var notes: String?
    
    init(
        mode: ScanMode,
        expectedAssets: [String]? = nil,
        truckId: String? = nil,
        eventId: String? = nil,
        userId: String,
        notes: String? = nil
    ) {
        self.id = UUID().uuidString
        self.mode = mode
        self.startedAt = Date()
        self.endedAt = nil
        self.scannedAssets = []
        self.expectedAssets = expectedAssets
        self.truckId = truckId
        self.eventId = eventId
        self.userId = userId
        self.notes = notes
    }
    
    var progress: Double {
        guard let expected = expectedAssets, !expected.isEmpty else {
            return 0
        }
        return Double(scannedAssets.count) / Double(expected.count)
    }
    
    var isComplete: Bool {
        guard let expected = expectedAssets else {
            return false
        }
        return Set(scannedAssets).isSuperset(of: expected)
    }
    
    var missingAssets: [String] {
        guard let expected = expectedAssets else {
            return []
        }
        return expected.filter { !scannedAssets.contains($0) }
    }
    
    var duration: TimeInterval? {
        guard let end = endedAt else {
            return Date().timeIntervalSince(startedAt)
        }
        return end.timeIntervalSince(startedAt)
    }
}

/// Item de scan pour affichage dans les listes
struct ScanListItem: Identifiable {
    let id: String // Asset ID
    let sku: String
    let name: String
    let serialNumber: String?
    var isScanned: Bool
    var scannedAt: Date?
    
    init(asset: Asset, isScanned: Bool = false) {
        self.id = asset.assetId
        self.sku = asset.sku
        self.name = asset.name
        self.serialNumber = asset.serialNumber
        self.isScanned = isScanned
        self.scannedAt = nil
    }
}

//
//  Truck.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Truck {
    var truckId: String // Retiré @Attribute(.unique) pour éviter les conflits
    var licensePlate: String
    var name: String? // Nom optionnel du camion
    var maxVolume: Double
    var maxWeight: Double
    var status: TruckStatus
    var currentDriverId: String?
    var currentLocationId: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        truckId: String,
        licensePlate: String,
        name: String? = nil,
        maxVolume: Double,
        maxWeight: Double,
        status: TruckStatus = .available,
        currentDriverId: String? = nil,
        currentLocationId: String? = nil
    ) {
        self.truckId = truckId
        self.licensePlate = licensePlate
        self.name = name
        self.maxVolume = maxVolume
        self.maxWeight = maxWeight
        self.status = status
        self.currentDriverId = currentDriverId
        self.currentLocationId = currentLocationId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Propriété calculée pour afficher le nom ou la plaque
    var displayName: String {
        name?.isEmpty == false ? name! : licensePlate
    }
}

enum TruckStatus: String, CaseIterable, Codable {
    case available = "DISPONIBLE"
    case loading = "CHARGEMENT"
    case enRoute = "EN_ROUTE"
    case atSite = "SUR_SITE"
    case returning = "RETOUR"
    case maintenance = "MAINTENANCE"
    
    var displayName: String {
        switch self {
        case .available: return "Disponible"
        case .loading: return "En chargement"
        case .enRoute: return "En route"
        case .atSite: return "Sur site"
        case .returning: return "En retour"
        case .maintenance: return "En maintenance"
        }
    }
    
    var colorName: String {
        switch self {
        case .available: return "green"
        case .loading: return "blue"
        case .enRoute: return "orange"
        case .atSite: return "purple"
        case .returning: return "yellow"
        case .maintenance: return "red"
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .available: return .green
        case .loading: return .blue
        case .enRoute: return .orange
        case .atSite: return .purple
        case .returning: return .yellow
        case .maintenance: return .red
        }
    }
}

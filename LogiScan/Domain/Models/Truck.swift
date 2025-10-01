//
//  Truck.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

@Model
final class Truck {
    @Attribute(.unique) var truckId: String
    var licensePlate: String
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
        maxVolume: Double,
        maxWeight: Double,
        status: TruckStatus = .available,
        currentDriverId: String? = nil,
        currentLocationId: String? = nil
    ) {
        self.truckId = truckId
        self.licensePlate = licensePlate
        self.maxVolume = maxVolume
        self.maxWeight = maxWeight
        self.status = status
        self.currentDriverId = currentDriverId
        self.currentLocationId = currentLocationId
        self.createdAt = Date()
        self.updatedAt = Date()
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
    
    var color: String {
        switch self {
        case .available: return "green"
        case .loading: return "blue"
        case .enRoute: return "orange"
        case .atSite: return "purple"
        case .returning: return "yellow"
        case .maintenance: return "red"
        }
    }
}

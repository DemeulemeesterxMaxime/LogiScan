//
//  Location.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

@Model
final class Location {
    var locationId: String // Retiré @Attribute(.unique) pour éviter les conflits
    var type: LocationType
    var name: String
    var parentLocationId: String?
    var isActive: Bool
    var capacity: LocationCapacity?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        locationId: String,
        type: LocationType,
        name: String,
        parentLocationId: String? = nil,
        isActive: Bool = true,
        capacity: LocationCapacity? = nil
    ) {
        self.locationId = locationId
        self.type = type
        self.name = name
        self.parentLocationId = parentLocationId
        self.isActive = isActive
        self.capacity = capacity
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum LocationType: String, CaseIterable, Codable {
    case hangar = "HANGAR"
    case zone = "ZONE"
    case truck = "CAMION"
    case site = "SITE"
    
    var displayName: String {
        switch self {
        case .hangar: return "Hangar"
        case .zone: return "Zone"
        case .truck: return "Camion"
        case .site: return "Site"
        }
    }
    
    var icon: String {
        switch self {
        case .hangar: return "building.2"
        case .zone: return "square.grid.3x3"
        case .truck: return "truck"
        case .site: return "location"
        }
    }
}

struct LocationCapacity: Codable {
    var maxWeight: Double?
    var maxVolume: Double?
    var maxItems: Int?
    
    init(maxWeight: Double? = nil, maxVolume: Double? = nil, maxItems: Int? = nil) {
        self.maxWeight = maxWeight
        self.maxVolume = maxVolume
        self.maxItems = maxItems
    }
}

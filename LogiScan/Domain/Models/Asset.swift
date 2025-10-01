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
    var createdAt: Date
    var updatedAt: Date
    
    init(
        assetId: String,
        sku: String,
        name: String,
        category: String,
        serialNumber: String? = nil,
        status: AssetStatus = .ok,
        weight: Double,
        volume: Double,
        value: Double,
        qrPayload: String,
        currentLocationId: String? = nil
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
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum AssetStatus: String, CaseIterable, Codable {
    case ok = "OK"
    case outOfOrder = "HS"
    case maintenance = "MAINTENANCE"
    case lost = "PERDU"
    
    var displayName: String {
        switch self {
        case .ok: return "En état"
        case .outOfOrder: return "Hors service"
        case .maintenance: return "En maintenance"
        case .lost: return "Perdu"
        }
    }
    
    var color: String {
        switch self {
        case .ok: return "green"
        case .outOfOrder: return "red"
        case .maintenance: return "orange"
        case .lost: return "gray"
        }
    }
}

//
//  ScanResult.swift
//  LogiScan
//
//  Created by Demeulemeester on 01/10/2025.
//

import Foundation

/// Résultat d'un scan QR/Code-barres
struct ScanResult {
    let type: ScanResultType
    let asset: Asset?
    let location: Location?
    let stockItem: StockItem?
    let title: String
    let subtitle: String
    let status: String
    let statusColor: String
    let rawPayload: String
    
    init(
        type: ScanResultType,
        asset: Asset? = nil,
        location: Location? = nil,
        stockItem: StockItem? = nil,
        title: String,
        subtitle: String,
        status: String,
        statusColor: String,
        rawPayload: String = ""
    ) {
        self.type = type
        self.asset = asset
        self.location = location
        self.stockItem = stockItem
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.statusColor = statusColor
        self.rawPayload = rawPayload
    }
}

enum ScanResultType: String, CaseIterable {
    case asset = "asset"
    case location = "location"
    case batch = "batch"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .asset: return "Asset"
        case .location: return "Emplacement"
        case .batch: return "Lot/Box"
        case .unknown: return "Inconnu"
        }
    }
    
    var icon: String {
        switch self {
        case .asset: return "cube.box.fill"
        case .location: return "location.fill"
        case .batch: return "shippingbox.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// Structure pour parser les QR codes JSON
struct QRPayload: Codable {
    let v: Int // Version
    let type: String
    let id: String
    let sku: String?
    let sn: String? // Serial Number
    let skus: [QRBatchItem]? // Pour les lots/boxes
    
    struct QRBatchItem: Codable {
        let sku: String
        let qty: Int
    }
}

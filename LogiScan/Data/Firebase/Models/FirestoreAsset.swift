//
//  FirestoreAsset.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import FirebaseFirestore
import Foundation

/// Modèle Firestore pour les références individuelles sérialisées (Asset)
struct FirestoreAsset: Codable, Identifiable {
    @DocumentID var id: String?
    var assetId: String
    var sku: String
    var name: String
    var category: String
    var serialNumber: String?
    var status: String  // "DISPONIBLE", "RESERVE", "EN_UTILISATION", etc.
    var weight: Double
    var volume: Double
    var value: Double
    var qrPayload: String
    var currentLocationId: String?
    var comments: String
    var tags: [String]

    @ServerTimestamp var lastMaintenanceDate: Date?
    @ServerTimestamp var nextMaintenanceDate: Date?
    @ServerTimestamp var lastScannedAt: Date?
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case assetId
        case sku
        case name
        case category
        case serialNumber
        case status
        case weight
        case volume
        case value
        case qrPayload
        case currentLocationId
        case comments
        case tags
        case lastMaintenanceDate
        case nextMaintenanceDate
        case lastScannedAt
        case createdAt
        case updatedAt
    }

    /// Convertir vers AssetStatus enum
    var assetStatus: AssetStatus {
        AssetStatus(rawValue: status) ?? .available
    }

    /// Convertir vers le modèle SwiftData local (pour cache)
    func toAsset() -> Asset {
        Asset(
            assetId: assetId,
            sku: sku,
            name: name,
            category: category,
            serialNumber: serialNumber,
            status: assetStatus,
            weight: weight,
            volume: volume,
            value: value,
            qrPayload: qrPayload,
            currentLocationId: currentLocationId,
            comments: comments,
            tags: tags,
            lastMaintenanceDate: lastMaintenanceDate,
            nextMaintenanceDate: nextMaintenanceDate
        )
    }
}

/// Extension pour convertir Asset vers Firestore
extension Asset {
    func toFirestoreAsset() -> FirestoreAsset {
        FirestoreAsset(
            id: nil,
            assetId: assetId,
            sku: sku,
            name: name,
            category: category,
            serialNumber: serialNumber,
            status: status.rawValue,
            weight: weight,
            volume: volume,
            value: value,
            qrPayload: qrPayload,
            currentLocationId: currentLocationId,
            comments: comments,
            tags: tags,
            lastMaintenanceDate: lastMaintenanceDate,
            nextMaintenanceDate: nextMaintenanceDate,
            lastScannedAt: nil,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

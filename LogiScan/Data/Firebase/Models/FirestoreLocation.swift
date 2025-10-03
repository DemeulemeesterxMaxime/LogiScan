//
//  FirestoreLocation.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import FirebaseFirestore
import Foundation

/// Modèle Firestore pour les emplacements
struct FirestoreLocation: Codable, Identifiable {
    @DocumentID var id: String?
    var locationId: String
    var name: String
    var locationType: String  // "warehouse", "truck", "site", "storage"
    var locationCapacity: Int?
    var currentAssets: [String]  // Array of asset IDs

    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case locationId
        case name
        case locationType = "type"
        case locationCapacity = "capacity"
        case currentAssets
        case createdAt
        case updatedAt
    }

    /// Convertir vers le modèle SwiftData local (pour cache)
    func toLocation() -> Location {
        let locType = LocationType(rawValue: locationType) ?? .zone
        let locCapacity = locationCapacity.map { maxItems in
            LocationCapacity(maxItems: maxItems)
        }

        return Location(
            locationId: locationId,
            type: locType,
            name: name,
            capacity: locCapacity
        )
    }
}

/// Extension pour convertir Location vers Firestore
extension Location {
    func toFirestoreLocation() -> FirestoreLocation {
        FirestoreLocation(
            id: nil,
            locationId: locationId,
            name: name,
            locationType: type.rawValue,
            locationCapacity: capacity?.maxItems,
            currentAssets: [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

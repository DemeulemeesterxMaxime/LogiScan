//
//  FirestoreMovement.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import FirebaseFirestore
import Foundation

/// Modèle Firestore pour les mouvements d'inventaire
struct FirestoreMovement: Codable, Identifiable {
    @DocumentID var id: String?
    var assetId: String?
    var sku: String
    var quantity: Int
    var fromLocation: String?
    var toLocation: String
    var movementType: String  // "entry", "exit", "transfer", "scan"
    var scannedBy: String?  // User ID
    var movementNotes: String

    @ServerTimestamp var timestamp: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case assetId
        case sku
        case quantity
        case fromLocation
        case toLocation
        case movementType = "type"
        case scannedBy
        case movementNotes = "notes"
        case timestamp
    }

    /// Convertir vers MovementType enum
    var typeEnum: MovementType {
        MovementType(rawValue: movementType) ?? .transfer
    }

    /// Convertir vers le modèle SwiftData local (pour cache)
    func toMovement() -> Movement {
        Movement(
            type: typeEnum,
            assetId: assetId,
            sku: sku,
            quantity: quantity,
            fromLocationId: fromLocation,
            toLocationId: toLocation,
            performedBy: scannedBy,
            timestamp: timestamp ?? Date(),
            notes: movementNotes
        )
    }
}

/// Extension pour convertir Movement vers Firestore
extension Movement {
    func toFirestoreMovement() -> FirestoreMovement {
        FirestoreMovement(
            id: nil,
            assetId: assetId,
            sku: sku ?? "",
            quantity: quantity,
            fromLocation: fromLocationId,
            toLocation: toLocationId ?? "",
            movementType: type.rawValue,
            scannedBy: performedBy,
            movementNotes: notes,
            timestamp: timestamp
        )
    }
}

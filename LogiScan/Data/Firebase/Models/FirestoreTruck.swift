//
//  FirestoreTruck.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import FirebaseFirestore
import Foundation

/// Représentation Firestore d'un Truck
struct FirestoreTruck: Codable {
    var truckId: String
    var licensePlate: String
    var name: String?
    var maxVolume: Double
    var maxWeight: Double
    var status: String
    var currentDriverId: String?
    var currentLocationId: String?
    var createdAt: Date
    var updatedAt: Date
    
    /// Convertir vers SwiftData Truck
    func toSwiftData() -> Truck {
        return Truck(
            truckId: truckId,
            licensePlate: licensePlate,
            name: name,
            maxVolume: maxVolume,
            maxWeight: maxWeight,
            status: TruckStatus(rawValue: status) ?? .available,
            currentDriverId: currentDriverId,
            currentLocationId: currentLocationId
        )
    }
}

// MARK: - Extension Truck

extension Truck {
    /// Convertir vers Firestore
    func toFirestoreTruck() -> FirestoreTruck {
        return FirestoreTruck(
            truckId: self.truckId,
            licensePlate: self.licensePlate,
            name: self.name,
            maxVolume: self.maxVolume,
            maxWeight: self.maxWeight,
            status: self.status.rawValue,
            currentDriverId: self.currentDriverId,
            currentLocationId: self.currentLocationId,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}

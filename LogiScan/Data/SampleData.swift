//
//  SampleData.swift
//  LogiScan
//
//  Created by Demeulemeester on 01/10/2025.
//

import Foundation
import SwiftData

class SampleData {
    static func createSampleData(modelContext: ModelContext) {
        // Vérifie si des données existent déjà
        let stockItemsCount = try? modelContext.fetchCount(FetchDescriptor<StockItem>())
        
        // Si des données existent déjà, ne pas les recréer
        if let count = stockItemsCount, count > 0 {
            return
        }
        
        // Création des emplacements de base pour distribution événementielle
        let hangar = Location(
            locationId: "LOC-HANGAR-001",
            type: .hangar,
            name: "Entrepôt Principal Toulon",
            parentLocationId: nil,
            capacity: LocationCapacity(maxWeight: 15000.0, maxVolume: 800.0)
        )
        
        let zoneAudio = Location(
            locationId: "LOC-ZONE-AUDIO",
            type: .zone,
            name: "Zone Audio (Rayonnage A1-A5)",
            parentLocationId: "LOC-HANGAR-001"
        )
        
        let zoneEclairage = Location(
            locationId: "LOC-ZONE-LIGHT",
            type: .zone,
            name: "Zone Éclairage (Rayonnage B1-B8)",
            parentLocationId: "LOC-HANGAR-001"
        )
        
        let zoneTransport = Location(
            locationId: "LOC-ZONE-TRANSPORT",
            type: .zone,
            name: "Zone Flight Cases (Rayonnage C1-C3)",
            parentLocationId: "LOC-HANGAR-001"
        )
        
        let zonePreparation = Location(
            locationId: "LOC-ZONE-PREPARATION",
            type: .zone,
            name: "Zone Préparation Commandes",
            parentLocationId: "LOC-HANGAR-001"
        )
        
        let camion1 = Location(
            locationId: "LOC-CAMION-001",
            type: .truck,
            name: "PL-123-AB (Mercedes Sprinter)",
            capacity: LocationCapacity(maxWeight: 3500.0, maxVolume: 50.0)
        )
        
        let camion2 = Location(
            locationId: "LOC-CAMION-002",
            type: .truck,
            name: "PL-456-CD (Iveco Daily)",
            capacity: LocationCapacity(maxWeight: 5000.0, maxVolume: 75.0)
        )
        
        modelContext.insert(hangar)
        modelContext.insert(zoneAudio)
        modelContext.insert(zoneEclairage)
        modelContext.insert(zoneTransport)
        modelContext.insert(zonePreparation)
        modelContext.insert(camion1)
        modelContext.insert(camion2)
        
        // Création de la flotte de camions
        let truck1 = Truck(
            truckId: "TRUCK-001",
            licensePlate: "PL-123-AB",
            maxVolume: 50.0,
            maxWeight: 3500.0,
            status: .available
        )
        
        let truck2 = Truck(
            truckId: "TRUCK-002", 
            licensePlate: "PL-456-CD",
            maxVolume: 75.0,
            maxWeight: 5000.0,
            status: .available
        )
        
        modelContext.insert(truck1)
        modelContext.insert(truck2)
        
        // Création des SKUs de base pour logistique événementielle
        let stockItems = [
            StockItem(
                sku: "SPK-12",
                name: "Enceinte Active 12\" 400W",
                category: "Audio",
                totalQuantity: 20,
                unitWeight: 15.0,
                unitVolume: 0.05,
                unitValue: 800.0,
                tags: ["Audio", "Enceinte", "Active", "400W", "Distribution"]
            ),
            StockItem(
                sku: "LIGHT-LED-PAR64",
                name: "Projecteur LED PAR64 RGBW",
                category: "Éclairage",
                totalQuantity: 60,
                unitWeight: 2.5,
                unitVolume: 0.015,
                unitValue: 180.0,
                tags: ["Éclairage", "LED", "PAR64", "RGBW", "DMX"]
            ),
            StockItem(
                sku: "TRIPOD-HEAVY",
                name: "Pied Enceinte Renforcé 35kg",
                category: "Support",
                totalQuantity: 30,
                unitWeight: 4.5,
                unitVolume: 0.025,
                unitValue: 85.0,
                tags: ["Support", "Pied", "35kg", "Renforcé"]
            ),
            StockItem(
                sku: "LASER-RGB-5W",
                name: "Laser RGB 5W Pro DMX",
                category: "Éclairage",
                totalQuantity: 12,
                unitWeight: 6.0,
                unitVolume: 0.035,
                unitValue: 1400.0,
                tags: ["Éclairage", "Laser", "RGB", "5W", "DMX", "Pro"]
            ),
            StockItem(
                sku: "CABLE-XLR-10M",
                name: "Câble XLR M/F 10m Neutrik",
                category: "Câblage",
                totalQuantity: 100,
                unitWeight: 0.8,
                unitVolume: 0.002,
                unitValue: 25.0,
                tags: ["Câblage", "XLR", "10m", "Neutrik", "Audio"]
            ),
            StockItem(
                sku: "FLIGHT-CASE-MEDIUM",
                name: "Flight Case Medium 60x40x40cm",
                category: "Transport",
                totalQuantity: 15,
                unitWeight: 8.0,
                unitVolume: 0.096,
                unitValue: 320.0,
                tags: ["Transport", "Flight Case", "Medium", "Protection"]
            )
        ]
        
        for item in stockItems {
            modelContext.insert(item)
        }
        
        // Création d'assets sérialisés pour distribution
        let assets = [
            Asset(
                assetId: "A-SPK-001",
                sku: "SPK-12",
                name: "Enceinte Active 12\" #001",
                category: "Audio",
                serialNumber: "SPK12-001",
                status: .ok,
                weight: 15.0,
                volume: 0.05,
                value: 800.0,
                qrPayload: #"{"v":1,"type":"asset","id":"A-SPK-001","sku":"SPK-12","sn":"SPK12-001"}"#,
                currentLocationId: "LOC-ZONE-AUDIO"
            ),
            Asset(
                assetId: "A-SPK-002",
                sku: "SPK-12",
                name: "Enceinte Active 12\" #002",
                category: "Audio",
                serialNumber: "SPK12-002",
                status: .ok,
                weight: 15.0,
                volume: 0.05,
                value: 800.0,
                qrPayload: #"{"v":1,"type":"asset","id":"A-SPK-002","sku":"SPK-12","sn":"SPK12-002"}"#,
                currentLocationId: "LOC-ZONE-AUDIO"
            ),
            Asset(
                assetId: "A-LASER-001",
                sku: "LASER-RGB-5W",
                name: "Laser RGB 5W Pro #001",
                category: "Éclairage",
                serialNumber: "LASER001",
                status: .ok,
                weight: 6.0,
                volume: 0.035,
                value: 1400.0,
                qrPayload: #"{"v":1,"type":"asset","id":"A-LASER-001","sku":"LASER-RGB-5W","sn":"LASER001"}"#,
                currentLocationId: "LOC-ZONE-LIGHT"
            ),
            Asset(
                assetId: "A-FLIGHT-001",
                sku: "FLIGHT-CASE-MEDIUM",
                name: "Flight Case Medium #001",
                category: "Transport",
                serialNumber: "FC-M001",
                status: .ok,
                weight: 8.0,
                volume: 0.096,
                value: 320.0,
                qrPayload: #"{"v":1,"type":"asset","id":"A-FLIGHT-001","sku":"FLIGHT-CASE-MEDIUM","sn":"FC-M001"}"#,
                currentLocationId: "LOC-ZONE-TRANSPORT"
            )
        ]
        
        for asset in assets {
            modelContext.insert(asset)
        }
        
        // Création d'événements de test pour distribution
        let event1 = Event(
            eventId: "EVT-001",
            name: "ISEN Gala de Fin d'Année 2025",
            client: "ISEN École d'Ingénieurs",
            address: "Campus ISEN, 20 Avenue de la Victoire, 83000 Toulon",
            startDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 8, to: Date()) ?? Date(),
            status: .confirmed,
            notes: "Soirée de gala pour 500 personnes. Configuration: système son complet + éclairage scène + lasers."
        )
        
        let event2 = Event(
            eventId: "EVT-002",
            name: "Festival Jazz'Var - Scène Plein Air",
            client: "Mairie de Toulon",
            address: "Place de la Liberté, 83000 Toulon",
            startDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 16, to: Date()) ?? Date(),
            status: .planning,
            notes: "Festival 3 jours. Prestation complète outdoor. Matériel renforcé requis."
        )
        
        modelContext.insert(event1)
        modelContext.insert(event2)
        
        // Création de mouvements d'exemple pour traçabilité
        let movements = [
            Movement(
                type: .pick,
                assetId: "A-SPK-001",
                sku: "SPK-12",
                quantity: 1,
                fromLocationId: "LOC-ZONE-AUDIO",
                toLocationId: "LOC-ZONE-PREPARATION",
                timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                eventId: "EVT-001",
                scanPayload: #"{"v":1,"type":"asset","id":"A-SPK-001","sku":"SPK-12","sn":"SPK12-001"}"#,
                notes: "Préparation pour ISEN Gala"
            ),
            Movement(
                type: .reserve,
                sku: "LIGHT-LED-PAR64",
                quantity: 20,
                fromLocationId: "LOC-ZONE-LIGHT",
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                eventId: "EVT-001",
                notes: "Réservation lights pour ISEN Gala"
            ),
            Movement(
                type: .transfer,
                sku: "CABLE-XLR-10M",
                quantity: 15,
                fromLocationId: "LOC-ZONE-LIGHT",
                toLocationId: "LOC-ZONE-AUDIO",
                timestamp: Calendar.current.date(byAdding: .hour, value: -4, to: Date()) ?? Date(),
                notes: "Réorganisation stock câbles"
            )
        ]
        
        for movement in movements {
            modelContext.insert(movement)
        }
        
        // Sauvegarde
        do {
            try modelContext.save()
            print("✅ Données d'exemple créées avec succès")
        } catch {
            print("❌ Erreur lors de la création des données d'exemple: \(error)")
        }
    }
}

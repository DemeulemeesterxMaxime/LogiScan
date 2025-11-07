//
//  TruckStatusService.swift
//  LogiScan
//
//  Created by Assistant on 28/10/2025.
//

import Foundation
import SwiftData

/// Service pour gérer automatiquement le statut des camions en fonction des listes de scan actives
class TruckStatusService {
    
    /// Met à jour le statut d'un camion en fonction des listes de scan actives
    /// 
    /// Logique:
    /// - Stock → Camion en cours : CHARGEMENT
    /// - Stock → Camion terminé + Camion → Event non commencé : EN_ROUTE
    /// - Camion → Event en cours : DÉCHARGEMENT (même statut que CHARGEMENT pour les opérations)
    /// - Camion → Event terminé + Event → Camion non commencé : SUR_SITE (événement en cours)
    /// - Event → Camion en cours : CHARGEMENT
    /// - Event → Camion terminé + Camion → Stock non commencé : EN_ROUTE
    /// - Camion → Stock en cours : DÉCHARGEMENT
    /// - Tous terminés ou aucun actif : DISPONIBLE
    static func updateTruckStatus(
        truck: Truck,
        events: [Event],
        scanLists: [ScanList],
        modelContext: ModelContext
    ) throws {
        // Éviter de modifier le statut maintenance
        if truck.status == .maintenance {
            print("🔧 [TruckStatusService] Camion \(truck.displayName) en maintenance - statut non modifié")
            return
        }
        
        // Trouver tous les événements actifs pour ce camion
        let activeEvents = events.filter { event in
            event.assignedTruckId == truck.truckId &&
            event.status != .cancelled &&
            event.status != .completed &&
            event.quoteStatus == .finalized
        }
        
        // Si aucun événement actif, camion disponible
        guard !activeEvents.isEmpty else {
            truck.status = .available
            truck.updatedAt = Date()
            try modelContext.save()
            print("🚚 [TruckStatusService] Camion \(truck.displayName) → DISPONIBLE (aucun événement)")
            return
        }
        
        // Récupérer toutes les ScanLists pour les événements actifs
        let relevantScanLists = scanLists.filter { scanList in
            activeEvents.contains(where: { $0.eventId == scanList.eventId }) &&
            scanList.status != .cancelled
        }
        
        // Déterminer le statut basé sur les listes de scan actives
        let newStatus = determineTruckStatus(from: relevantScanLists)
        
        if truck.status != newStatus {
            truck.status = newStatus
            truck.updatedAt = Date()
            try modelContext.save()
            print("🚚 [TruckStatusService] Camion \(truck.displayName) → \(newStatus.displayName)")
        }
    }
    
    /// Détermine le statut du camion en fonction des listes de scan
    private static func determineTruckStatus(from scanLists: [ScanList]) -> TruckStatus {
        // Trouver les listes par direction
        let stockToTruck = scanLists.filter { $0.scanDirection == .stockToTruck }
        let truckToEvent = scanLists.filter { $0.scanDirection == .truckToEvent }
        let eventToTruck = scanLists.filter { $0.scanDirection == .eventToTruck }
        let truckToStock = scanLists.filter { $0.scanDirection == .truckToStock }
        
        // Vérifier les statuts
        let stockToTruckInProgress = stockToTruck.contains { $0.status == .inProgress }
        let stockToTruckCompleted = stockToTruck.contains { $0.status == .completed }
        
        let truckToEventInProgress = truckToEvent.contains { $0.status == .inProgress }
        let truckToEventCompleted = truckToEvent.contains { $0.status == .completed }
        
        let eventToTruckInProgress = eventToTruck.contains { $0.status == .inProgress }
        let eventToTruckCompleted = eventToTruck.contains { $0.status == .completed }
        
        let truckToStockInProgress = truckToStock.contains { $0.status == .inProgress }
        
        // 🚛 LOGIQUE DU STATUT
        
        // 1. Stock → Camion en cours : CHARGEMENT
        if stockToTruckInProgress {
            return .loading
        }
        
        // 2. Camion → Event en cours : CHARGEMENT (déchargement au site)
        if truckToEventInProgress {
            return .loading // Utilise le même statut pour chargement/déchargement
        }
        
        // 3. Event → Camion en cours : CHARGEMENT (chargement retour)
        if eventToTruckInProgress {
            return .loading
        }
        
        // 4. Camion → Stock en cours : CHARGEMENT (déchargement au dépôt)
        if truckToStockInProgress {
            return .loading
        }
        
        // 5. Stock → Camion terminé + Camion → Event non commencé : EN_ROUTE
        if stockToTruckCompleted && !truckToEventInProgress && !truckToEventCompleted {
            return .enRoute
        }
        
        // 6. Event → Camion terminé + Camion → Stock non commencé : EN_ROUTE (retour)
        if eventToTruckCompleted && !truckToStockInProgress {
            return .returning
        }
        
        // 7. Camion → Event terminé + Event → Camion non commencé : SUR_SITE
        if truckToEventCompleted && !eventToTruckInProgress && !eventToTruckCompleted {
            return .atSite
        }
        
        // Par défaut : disponible
        return .available
    }
    
    /// Met à jour tous les camions en fonction de tous les événements et scan lists
    static func updateAllTruckStatuses(
        modelContext: ModelContext
    ) throws {
        let trucksDescriptor = FetchDescriptor<Truck>()
        let eventsDescriptor = FetchDescriptor<Event>()
        let scanListsDescriptor = FetchDescriptor<ScanList>()
        
        let allTrucks = try modelContext.fetch(trucksDescriptor)
        let allEvents = try modelContext.fetch(eventsDescriptor)
        let allScanLists = try modelContext.fetch(scanListsDescriptor)
        
        print("🔄 [TruckStatusService] Mise à jour de \(allTrucks.count) camions...")
        
        for truck in allTrucks {
            try updateTruckStatus(
                truck: truck,
                events: allEvents,
                scanLists: allScanLists,
                modelContext: modelContext
            )
        }
        
        print("✅ [TruckStatusService] Tous les camions mis à jour")
    }
    
    /// Met à jour le statut d'un camion spécifique par son ID
    static func updateTruckStatusById(
        truckId: String,
        modelContext: ModelContext
    ) throws {
        let trucksDescriptor = FetchDescriptor<Truck>()
        let eventsDescriptor = FetchDescriptor<Event>()
        let scanListsDescriptor = FetchDescriptor<ScanList>()
        
        let allTrucks = try modelContext.fetch(trucksDescriptor)
        let allEvents = try modelContext.fetch(eventsDescriptor)
        let allScanLists = try modelContext.fetch(scanListsDescriptor)
        
        guard let truck = allTrucks.first(where: { $0.truckId == truckId }) else {
            print("⚠️ [TruckStatusService] Camion \(truckId) introuvable")
            return
        }
        
        try updateTruckStatus(
            truck: truck,
            events: allEvents,
            scanLists: allScanLists,
            modelContext: modelContext
        )
    }
    
    /// Appelé quand une ScanList change de statut
    static func handleScanListChange(
        scanList: ScanList,
        modelContext: ModelContext
    ) throws {
        // Récupérer l'événement associé en utilisant la valeur directement
        let eventId = scanList.eventId
        let eventsDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.eventId == eventId
            }
        )
        
        guard let event = try modelContext.fetch(eventsDescriptor).first,
              let truckId = event.assignedTruckId else {
            print("ℹ️ [TruckStatusService] ScanList sans camion assigné")
            return
        }
        
        try updateTruckStatusById(truckId: truckId, modelContext: modelContext)
    }
    
    /// Appelé quand un événement est créé, modifié ou supprimé
    static func handleEventChange(
        event: Event,
        modelContext: ModelContext
    ) throws {
        guard let truckId = event.assignedTruckId else {
            print("ℹ️ [TruckStatusService] Événement sans camion assigné")
            return
        }
        
        try updateTruckStatusById(truckId: truckId, modelContext: modelContext)
    }
    
    /// Appelé quand l'assignation d'un camion change sur un événement
    static func handleTruckAssignmentChange(
        event: Event,
        oldTruckId: String?,
        newTruckId: String?,
        modelContext: ModelContext
    ) throws {
        // Mettre à jour l'ancien camion (maintenant disponible)
        if let oldId = oldTruckId {
            try updateTruckStatusById(truckId: oldId, modelContext: modelContext)
        }
        
        // Mettre à jour le nouveau camion (maintenant occupé)
        if let newId = newTruckId {
            try updateTruckStatusById(truckId: newId, modelContext: modelContext)
        }
    }
}

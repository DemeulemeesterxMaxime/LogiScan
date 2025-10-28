//
//  TruckStatusService.swift
//  LogiScan
//
//  Created by Assistant on 28/10/2025.
//

import Foundation
import SwiftData

/// Service pour gérer automatiquement le statut des camions en fonction des événements
class TruckStatusService {
    
    /// Met à jour le statut d'un camion en fonction des événements auxquels il est assigné
    static func updateTruckStatus(
        truck: Truck,
        events: [Event],
        modelContext: ModelContext
    ) throws {
        let now = Date()
        
        // Trouver tous les événements actifs utilisant ce camion
        let activeEvents = events.filter { event in
            event.assignedTruckId == truck.truckId &&
            event.status != .cancelled &&
            event.status != .completed &&
            isEventActive(event, at: now)
        }
        
        // Déterminer le statut approprié
        if activeEvents.isEmpty {
            // Aucun événement actif : disponible (sauf si en maintenance)
            if truck.status != .maintenance {
                truck.status = .available
            }
        } else {
            // Au moins un événement actif : déterminer le statut selon les dates
            let earliestEvent = activeEvents.min(by: { $0.setupStartTime < $1.setupStartTime })!
            
            if now < earliestEvent.setupStartTime {
                // Avant le montage : chargement
                truck.status = .loading
            } else if now >= earliestEvent.setupStartTime && now < earliestEvent.startDate {
                // Entre montage et début : en route vers le site
                truck.status = .enRoute
            } else if now >= earliestEvent.startDate && now <= earliestEvent.endDate {
                // Pendant l'événement : sur site
                truck.status = .atSite
            } else if now > earliestEvent.endDate {
                // Après l'événement : en retour
                truck.status = .returning
            }
        }
        
        truck.updatedAt = Date()
        try modelContext.save()
        
        print("🚚 [TruckStatusService] Camion \(truck.displayName) → \(truck.status.displayName)")
    }
    
    /// Vérifie si un événement est considéré comme actif (non terminé et dans une période proche)
    private static func isEventActive(_ event: Event, at date: Date) -> Bool {
        // Un événement est actif s'il est dans une fenêtre de 7 jours avant le montage jusqu'à 1 jour après la fin
        let calendar = Calendar.current
        let sevenDaysBefore = calendar.date(byAdding: .day, value: -7, to: event.setupStartTime) ?? event.setupStartTime
        let oneDayAfter = calendar.date(byAdding: .day, value: 1, to: event.endDate) ?? event.endDate
        
        return date >= sevenDaysBefore && date <= oneDayAfter
    }
    
    /// Met à jour tous les camions en fonction de tous les événements
    static func updateAllTruckStatuses(
        modelContext: ModelContext
    ) throws {
        let trucksDescriptor = FetchDescriptor<Truck>()
        let eventsDescriptor = FetchDescriptor<Event>()
        
        let allTrucks = try modelContext.fetch(trucksDescriptor)
        let allEvents = try modelContext.fetch(eventsDescriptor)
        
        print("🔄 [TruckStatusService] Mise à jour de \(allTrucks.count) camions...")
        
        for truck in allTrucks {
            try updateTruckStatus(truck: truck, events: allEvents, modelContext: modelContext)
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
        
        let allTrucks = try modelContext.fetch(trucksDescriptor)
        let allEvents = try modelContext.fetch(eventsDescriptor)
        
        guard let truck = allTrucks.first(where: { $0.truckId == truckId }) else {
            print("⚠️ [TruckStatusService] Camion \(truckId) introuvable")
            return
        }
        
        try updateTruckStatus(truck: truck, events: allEvents, modelContext: modelContext)
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

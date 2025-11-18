//
//  QuoteValidationService.swift
//  LogiScan
//
//  Created by Assistant on 12/11/2025.
//

import Foundation
import SwiftData

/// Service pour gérer la validation d'un devis et toutes ses conséquences
/// (réservations, listes de scan, tâches, changements de statuts)
@MainActor
class QuoteValidationService: ObservableObject {
    
    private let reservationService = ReservationService()
    private let scanListService = ScanListGenerationService()
    
    /// Valide un devis : crée les réservations, gèle les stocks, génère les listes et tâches
    /// - Parameters:
    ///   - event: L'événement dont le devis est validé
    ///   - quoteItems: Les articles du devis
    ///   - generateScanLists: Si true, génère les listes de scan selon les directions sélectionnées
    ///   - generateTasks: Si true, génère les tâches associées aux listes de scan
    ///   - userId: L'ID de l'utilisateur qui valide
    ///   - modelContext: Le contexte SwiftData
    /// - Throws: QuoteValidationError si la validation échoue
    func validateQuote(
        event: Event,
        quoteItems: [QuoteItem],
        generateScanLists: Bool,
        generateTasks: Bool,
        userId: String,
        modelContext: ModelContext
    ) async throws {
        
        print("📝 [QuoteValidation] Validation du devis pour l'événement '\(event.name)'")
        print("   Articles: \(quoteItems.count)")
        print("   Générer listes de scan: \(generateScanLists)")
        print("   Générer tâches: \(generateTasks)")
        
        // 1. Vérifier que le camion est disponible
        try await verifyTruckAvailability(event: event, modelContext: modelContext)
        
        // 2. Créer ou mettre à jour les réservations (pré-gel)
        try await createReservations(
            event: event,
            quoteItems: quoteItems,
            modelContext: modelContext
        )
        
        // 3. Mettre à jour le statut du devis
        event.quoteStatus = .finalized
        event.updatedAt = Date()
        
        // 4. Générer les listes de scan si demandé
        if generateScanLists {
            _ = try scanListService.generateScanLists(
                for: event,
                quoteItems: quoteItems,
                generateTasks: generateTasks,
                userId: userId,
                modelContext: modelContext
            )
        }
        
        // 5. Sauvegarder toutes les modifications
        try modelContext.save()
        
        print("✅ [QuoteValidation] Devis validé avec succès")
        print("   - Réservations: ✅ Pré-gel effectué")
        print("   - Listes de scan: \(generateScanLists ? "✅ Générées" : "❌ Non générées")")
        print("   - Tâches: \(generateTasks ? "✅ Générées" : "❌ Non générées")")
    }
    
    /// Vérifie que le camion assigné est disponible pour la période de l'événement
    private func verifyTruckAvailability(
        event: Event,
        modelContext: ModelContext
    ) async throws {
        
        guard let truckId = event.assignedTruckId else {
            print("⚠️ [QuoteValidation] Aucun camion assigné, validation continue")
            return
        }
        
        print("🚛 [QuoteValidation] Vérification disponibilité camion '\(truckId)'")
        
        // Récupérer le camion
        let truckDescriptor = FetchDescriptor<Truck>(
            predicate: #Predicate { $0.truckId == truckId }
        )
        
        guard let truck = try modelContext.fetch(truckDescriptor).first else {
            throw QuoteValidationError.truckNotFound
        }
        
        // Vérifier les conflits avec d'autres événements
        let currentEventId = event.eventId
        let cancelledStatus = EventStatus.cancelled.rawValue
        let eventsDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate { evt in
                evt.assignedTruckId == truckId &&
                evt.eventId != currentEventId &&
                evt.status.rawValue != cancelledStatus
            }
        )
        
        let otherEvents = try modelContext.fetch(eventsDescriptor)
        
        // Vérifier les chevauchements de dates
        for otherEvent in otherEvents {
            if datesOverlap(
                start1: event.startDate,
                end1: event.endDate,
                start2: otherEvent.startDate,
                end2: otherEvent.endDate
            ) {
                print("❌ [QuoteValidation] Conflit de camion avec l'événement '\(otherEvent.name)'")
                throw QuoteValidationError.truckUnavailable(
                    truckName: truck.name ?? truck.licensePlate,
                    conflictingEvent: otherEvent.name
                )
            }
        }
        
        print("✅ [QuoteValidation] Camion disponible")
    }
    
    /// Crée les réservations d'assets pour tous les articles du devis (pré-gel)
    private func createReservations(
        event: Event,
        quoteItems: [QuoteItem],
        modelContext: ModelContext
    ) async throws {
        
        print("🔒 [QuoteValidation] Création des réservations (pré-gel)")
        
        // Récupérer tous les assets et réservations existantes
        let assetsDescriptor = FetchDescriptor<Asset>()
        let allAssets = try modelContext.fetch(assetsDescriptor)
        
        let reservationsDescriptor = FetchDescriptor<AssetReservation>()
        let existingReservations = try modelContext.fetch(reservationsDescriptor)
        
        // Récupérer tous les StockItems
        let stockItemsDescriptor = FetchDescriptor<StockItem>()
        let allStockItems = try modelContext.fetch(stockItemsDescriptor)
        
        // Pour chaque article du devis
        for quoteItem in quoteItems {
            guard let stockItem = allStockItems.first(where: { $0.sku == quoteItem.sku }) else {
                print("⚠️ [QuoteValidation] StockItem '\(quoteItem.sku)' non trouvé, passage")
                continue
            }
            
            // Si l'article a déjà des assets assignés, vérifier s'ils sont toujours disponibles
            if !quoteItem.assignedAssets.isEmpty {
                print("   🔄 Article '\(quoteItem.name)' a déjà \(quoteItem.assignedAssets.count) assets assignés")
                
                // Ajuster les réservations si la quantité a changé
                let newAssignedAssets = try await reservationService.adjustReservations(
                    for: quoteItem,
                    stockItem: stockItem,
                    newQuantity: quoteItem.quantity,
                    event: event,
                    allAssets: allAssets,
                    allReservations: existingReservations,
                    modelContext: modelContext
                )
                
                quoteItem.assignedAssets = newAssignedAssets
                
            } else {
                // Première réservation pour cet article
                let assignedAssets = try await reservationService.reserveAssets(
                    for: quoteItem,
                    stockItem: stockItem,
                    event: event,
                    allAssets: allAssets,
                    existingReservations: existingReservations,
                    modelContext: modelContext
                )
                
                quoteItem.assignedAssets = assignedAssets
                print("   ✅ \(assignedAssets.count) assets réservés pour '\(quoteItem.name)'")
            }
        }
        
        print("✅ [QuoteValidation] Toutes les réservations créées (pré-gel)")
    }
    
    /// Gèle définitivement les assets après le scan de chargement
    /// Appelée quand la liste "Stock → Camion" est complétée
    func freezeAssetsAfterLoading(
        event: Event,
        scanList: ScanList,
        modelContext: ModelContext
    ) async throws {
        
        print("🔒 [QuoteValidation] Gel définitif des assets après chargement")
        
        guard scanList.scanDirection == .stockToTruck else {
            print("⚠️ [QuoteValidation] Cette liste n'est pas un chargement, gel ignoré")
            return
        }
        
        // Récupérer toutes les réservations de l'événement
        let eventId = event.eventId
        let reservationsDescriptor = FetchDescriptor<AssetReservation>(
            predicate: #Predicate { $0.eventId == eventId }
        )
        
        let reservations = try modelContext.fetch(reservationsDescriptor)
        
        // Passer toutes les réservations de .pending à .confirmed
        for reservation in reservations {
            if reservation.status == .pending {
                reservation.status = .confirmed
                print("   🔒 Asset '\(reservation.assetId)' gelé définitivement")
            }
        }
        
        try modelContext.save()
        print("✅ [QuoteValidation] \(reservations.count) assets gelés définitivement")
    }
    
    /// Libère les assets après le retour au stock
    /// Appelée quand la liste "Camion → Stock" est complétée
    func releaseAssetsAfterReturn(
        event: Event,
        scanList: ScanList,
        modelContext: ModelContext
    ) async throws {
        
        print("🔓 [QuoteValidation] Libération des assets après retour au stock")
        
        guard scanList.scanDirection == .truckToStock else {
            print("⚠️ [QuoteValidation] Cette liste n'est pas un retour stock, libération ignorée")
            return
        }
        
        // Récupérer toutes les réservations de l'événement
        let eventId = event.eventId
        let reservationsDescriptor = FetchDescriptor<AssetReservation>(
            predicate: #Predicate { $0.eventId == eventId }
        )
        
        let reservations = try modelContext.fetch(reservationsDescriptor)
        
        // Marquer toutes les réservations comme terminées
        for reservation in reservations {
            reservation.status = .returned
            print("   🔓 Asset '\(reservation.assetId)' libéré")
        }
        
        // Mettre à jour le statut de l'événement
        event.status = .completed
        event.updatedAt = Date()
        
        try modelContext.save()
        print("✅ [QuoteValidation] \(reservations.count) assets libérés, événement terminé")
    }
    
    // MARK: - Helper Methods
    
    private func datesOverlap(
        start1: Date,
        end1: Date,
        start2: Date,
        end2: Date
    ) -> Bool {
        return start1 < end2 && end1 > start2
    }
}

// MARK: - Quote Validation Error

enum QuoteValidationError: LocalizedError {
    case truckNotFound
    case truckUnavailable(truckName: String, conflictingEvent: String)
    case insufficientStock(sku: String, available: Int, requested: Int)
    case reservationFailed
    
    var errorDescription: String? {
        switch self {
        case .truckNotFound:
            return "Camion non trouvé"
        case .truckUnavailable(let truckName, let conflictingEvent):
            return "Le camion '\(truckName)' n'est pas disponible. Conflit avec l'événement '\(conflictingEvent)'"
        case .insufficientStock(let sku, let available, let requested):
            return "Stock insuffisant pour '\(sku)' : \(available) disponible(s) sur \(requested) demandé(s)"
        case .reservationFailed:
            return "Échec de la réservation des assets"
        }
    }
}

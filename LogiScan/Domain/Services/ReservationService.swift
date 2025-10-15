//
//  ReservationService.swift
//  LogiScan
//
//  Created by Copilot on 14/10/2025.
//

import Foundation
import SwiftData

/// Service de gestion des réservations d'assets
@MainActor
final class ReservationService: ObservableObject {
    
    /// Sélectionne et réserve automatiquement les meilleurs assets pour un item
    /// - Parameters:
    ///   - quoteItem: L'item du devis pour lequel réserver
    ///   - stockItem: L'article de stock correspondant
    ///   - event: L'événement concerné
    ///   - allAssets: Tous les assets disponibles
    ///   - existingReservations: Réservations existantes
    ///   - modelContext: Contexte SwiftData pour persistance
    /// - Returns: Liste des IDs des assets réservés
    func reserveAssets(
        for quoteItem: QuoteItem,
        stockItem: StockItem,
        event: Event,
        allAssets: [Asset],
        existingReservations: [AssetReservation],
        modelContext: ModelContext
    ) async throws -> [String] {
        
        print("🔒 [ReservationService] Réservation d'assets pour \(stockItem.name)")
        print("   Quantité demandée: \(quoteItem.quantity)")
        
        // 1. Filtrer les assets de cet article
        let itemAssets = allAssets.filter { $0.sku == stockItem.sku }
        print("   Assets disponibles (total): \(itemAssets.count)")
        
        // 2. Filtrer les assets disponibles (pas de conflit de date)
        let availableAssets = itemAssets.filter { asset in
            !hasConflictingReservation(
                asset: asset,
                eventDates: (event.startDate, event.endDate),
                reservations: existingReservations,
                excludingEvent: event.eventId
            )
        }
        print("   Assets sans conflit: \(availableAssets.count)")
        
        // 3. Vérifier qu'on a assez d'assets
        guard availableAssets.count >= quoteItem.quantity else {
            print("❌ Stock insuffisant: \(availableAssets.count)/\(quoteItem.quantity)")
            throw ReservationError.insufficientStock(
                available: availableAssets.count,
                requested: quoteItem.quantity
            )
        }
        
        // 4. Sélectionner les meilleurs assets
        let selectedAssets = selectBestAssets(
            from: availableAssets,
            quantity: quoteItem.quantity
        )
        print("   Assets sélectionnés: \(selectedAssets.count)")
        
        // 5. Créer les réservations
        var assignedIds: [String] = []
        for asset in selectedAssets {
            let reservation = AssetReservation(
                reservationId: UUID().uuidString,
                assetId: asset.assetId,
                eventId: event.eventId,
                startDate: event.startDate,
                endDate: event.endDate,
                status: .pending
            )
            modelContext.insert(reservation)
            assignedIds.append(asset.assetId)
            
            print("   🔒 Réservé: \(asset.assetId) (\(asset.status.rawValue))")
        }
        
        // 6. Sauvegarder les réservations
        try modelContext.save()
        print("✅ [ReservationService] \(assignedIds.count) assets réservés avec succès")
        
        return assignedIds
    }
    
    /// Libère toutes les réservations d'un item
    func releaseReservations(
        for quoteItem: QuoteItem,
        event: Event,
        allReservations: [AssetReservation],
        modelContext: ModelContext
    ) async throws {
        
        print("🔓 [ReservationService] Libération des réservations pour \(quoteItem.name)")
        
        let itemReservations = allReservations.filter { reservation in
            reservation.eventId == event.eventId &&
            quoteItem.assignedAssets.contains(reservation.assetId)
        }
        
        print("   Réservations à libérer: \(itemReservations.count)")
        
        for reservation in itemReservations {
            modelContext.delete(reservation)
            print("   🔓 Libéré: \(reservation.assetId)")
        }
        
        try modelContext.save()
        print("✅ [ReservationService] Réservations libérées")
    }
    
    /// Libère un seul asset (quand on diminue la quantité)
    func releaseOneAsset(
        for quoteItem: QuoteItem,
        event: Event,
        allReservations: [AssetReservation],
        modelContext: ModelContext
    ) async throws -> String? {
        
        guard !quoteItem.assignedAssets.isEmpty else {
            print("⚠️ [ReservationService] Aucun asset assigné à libérer")
            return nil
        }
        
        // Prendre le dernier asset assigné
        let assetIdToRelease = quoteItem.assignedAssets.last!
        
        if let reservation = allReservations.first(where: {
            $0.assetId == assetIdToRelease && $0.eventId == event.eventId
        }) {
            modelContext.delete(reservation)
            try modelContext.save()
            print("🔓 [ReservationService] Asset libéré: \(assetIdToRelease)")
            return assetIdToRelease
        }
        
        return nil
    }
    
    /// Ajuste les réservations quand la quantité change
    func adjustReservations(
        for quoteItem: QuoteItem,
        stockItem: StockItem,
        newQuantity: Int,
        event: Event,
        allAssets: [Asset],
        allReservations: [AssetReservation],
        modelContext: ModelContext
    ) async throws -> [String] {
        
        let currentQuantity = quoteItem.assignedAssets.count
        print("🔄 [ReservationService] Ajustement réservations: \(currentQuantity) → \(newQuantity)")
        
        if newQuantity > currentQuantity {
            // Ajouter des réservations
            let additionalQuantity = newQuantity - currentQuantity
            print("   ➕ Ajout de \(additionalQuantity) réservations")
            
            let additionalIds = try await reserveAdditionalAssets(
                quantity: additionalQuantity,
                for: stockItem,
                event: event,
                allAssets: allAssets,
                existingReservations: allReservations,
                excludingAssets: quoteItem.assignedAssets,
                modelContext: modelContext
            )
            
            return quoteItem.assignedAssets + additionalIds
            
        } else if newQuantity < currentQuantity {
            // Libérer des réservations
            let toRemoveCount = currentQuantity - newQuantity
            print("   ➖ Suppression de \(toRemoveCount) réservations")
            
            let assetsToKeep = Array(quoteItem.assignedAssets.prefix(newQuantity))
            let assetsToRelease = Array(quoteItem.assignedAssets.suffix(toRemoveCount))
            
            for assetId in assetsToRelease {
                if let reservation = allReservations.first(where: {
                    $0.assetId == assetId && $0.eventId == event.eventId
                }) {
                    modelContext.delete(reservation)
                    print("   🔓 Libéré: \(assetId)")
                }
            }
            
            try modelContext.save()
            return assetsToKeep
        }
        
        // Pas de changement
        return quoteItem.assignedAssets
    }
    
    // MARK: - Private Methods
    
    /// Sélectionne les meilleurs assets disponibles selon des critères de qualité
    private func selectBestAssets(
        from assets: [Asset],
        quantity: Int
    ) -> [Asset] {
        
        return assets
            .sorted { (asset1: Asset, asset2: Asset) -> Bool in
                // Critère 1: Statut (disponible en priorité)
                if asset1.status != asset2.status {
                    if asset1.status == .available { return true }
                    if asset2.status == .available { return false }
                }
                
                // Critère 2: Pas de maintenance nécessaire
                if asset1.needsMaintenance != asset2.needsMaintenance {
                    return !asset1.needsMaintenance && asset2.needsMaintenance
                }
                
                // Critère 3: Valeur (protéger les assets les plus chers)
                if asset1.value != asset2.value {
                    return asset1.value < asset2.value
                }
                
                return false
            }
            .prefix(quantity)
            .map { $0 }
    }
    
    /// Vérifie si un asset a une réservation conflictuelle
    private func hasConflictingReservation(
        asset: Asset,
        eventDates: (start: Date, end: Date),
        reservations: [AssetReservation],
        excludingEvent: String
    ) -> Bool {
        
        return reservations.contains { reservation in
            // Même asset
            guard reservation.assetId == asset.assetId else { return false }
            
            // Exclure le même événement
            guard reservation.eventId != excludingEvent else { return false }
            
            // Exclure les réservations annulées
            guard reservation.status != .cancelled else { return false }
            
            // Vérifier chevauchement de dates
            let hasOverlap = datesOverlap(
                start1: reservation.startDate,
                end1: reservation.endDate,
                start2: eventDates.start,
                end2: eventDates.end
            )
            
            return hasOverlap
        }
    }
    
    /// Vérifie si deux périodes se chevauchent
    private func datesOverlap(
        start1: Date,
        end1: Date,
        start2: Date,
        end2: Date
    ) -> Bool {
        return start1 < end2 && end1 > start2
    }
    
    /// Réserve des assets additionnels (pour augmentation de quantité)
    private func reserveAdditionalAssets(
        quantity: Int,
        for stockItem: StockItem,
        event: Event,
        allAssets: [Asset],
        existingReservations: [AssetReservation],
        excludingAssets: [String],
        modelContext: ModelContext
    ) async throws -> [String] {
        
        // Filtrer les assets de cet article
        let itemAssets = allAssets.filter { $0.sku == stockItem.sku }
        
        // Exclure les assets déjà assignés
        let availableAssets = itemAssets.filter { asset in
            !excludingAssets.contains(asset.assetId) &&
            !hasConflictingReservation(
                asset: asset,
                eventDates: (event.startDate, event.endDate),
                reservations: existingReservations,
                excludingEvent: event.eventId
            )
        }
        
        guard availableAssets.count >= quantity else {
            throw ReservationError.insufficientStock(
                available: availableAssets.count,
                requested: quantity
            )
        }
        
        let selectedAssets = selectBestAssets(from: availableAssets, quantity: quantity)
        
        var assignedIds: [String] = []
        for asset in selectedAssets {
            let reservation = AssetReservation(
                reservationId: UUID().uuidString,
                assetId: asset.assetId,
                eventId: event.eventId,
                startDate: event.startDate,
                endDate: event.endDate,
                status: .pending
            )
            modelContext.insert(reservation)
            assignedIds.append(asset.assetId)
        }
        
        try modelContext.save()
        return assignedIds
    }
}

// MARK: - Reservation Error

enum ReservationError: LocalizedError {
    case insufficientStock(available: Int, requested: Int)
    case reservationFailed
    case assetNotFound
    case conflictDetected
    
    var errorDescription: String? {
        switch self {
        case .insufficientStock(let available, let requested):
            return "Stock insuffisant : \(available) disponible(s) sur \(requested) demandé(s)"
        case .reservationFailed:
            return "Échec de la réservation"
        case .assetNotFound:
            return "Asset non trouvé"
        case .conflictDetected:
            return "Conflit de réservation détecté"
        }
    }
}

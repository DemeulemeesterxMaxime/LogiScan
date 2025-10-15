//
//  AvailabilityService.swift
//  LogiScan
//
//  Created by Copilot on 14/10/2025.
//

import Foundation
import SwiftData

/// Service de gestion de la disponibilité des articles
@MainActor
final class AvailabilityService: ObservableObject {
    
    /// Vérifie la disponibilité d'un article pour un événement
    /// - Parameters:
    ///   - stockItem: L'article à vérifier
    ///   - event: L'événement pour lequel vérifier la disponibilité
    ///   - requestedQuantity: La quantité demandée
    ///   - allAssets: Tous les assets de l'inventaire
    ///   - allReservations: Toutes les réservations existantes
    /// - Returns: Résultat de disponibilité avec détails
    func checkAvailability(
        for stockItem: StockItem,
        event: Event,
        requestedQuantity: Int,
        allAssets: [Asset],
        allReservations: [AssetReservation]
    ) -> AvailabilityResult {
        
        print("🔍 [AvailabilityService] Vérification disponibilité pour \(stockItem.name)")
        print("   Quantité demandée: \(requestedQuantity)")
        
        // 1. Filtrer les assets de cet article
        let itemAssets = allAssets.filter { $0.sku == stockItem.sku }
        print("   Assets totaux: \(itemAssets.count)")
        
        // 2. Calculer les quantités avec la méthode intelligente
        let quantities = stockItem.calculateQuantities(from: itemAssets)
        print("   Disponibles (calculateQuantities): \(quantities.available)")
        print("   Réservés: \(quantities.reserved)")
        print("   Total: \(itemAssets.count)")
        
        // 3. Vérifier les conflits de date avec les réservations
        let conflicts = findConflictingReservations(
            assets: itemAssets,
            eventDates: (event.startDate, event.endDate),
            reservations: allReservations,
            excludingEvent: event.eventId
        )
        print("   Conflits détectés: \(conflicts.count)")
        
        // 4. Calculer disponibilité réelle
        // Note: calculateQuantities() prend déjà en compte les réservations
        // mais on vérifie explicitement les conflits pour plus de sécurité
        let realAvailable = max(0, quantities.available - conflicts.count)
        print("   Disponibilité réelle: \(realAvailable)")
        
        // 5. Vérifier si la demande peut être satisfaite
        let canFulfill = requestedQuantity <= realAvailable
        print("   Peut satisfaire: \(canFulfill ? "✅" : "❌")")
        
        return AvailabilityResult(
            requestedQuantity: requestedQuantity,
            availableQuantity: realAvailable,
            totalQuantity: itemAssets.count,
            reservedQuantity: quantities.reserved,
            conflicts: conflicts,
            canFulfill: canFulfill
        )
    }
    
    /// Trouve les réservations qui chevauchent les dates de l'événement
    private func findConflictingReservations(
        assets: [Asset],
        eventDates: (start: Date, end: Date),
        reservations: [AssetReservation],
        excludingEvent: String
    ) -> [AssetReservation] {
        
        let assetIds = Set(assets.map { $0.assetId })
        
        return reservations.filter { reservation in
            // Exclure les réservations du même événement
            guard reservation.eventId != excludingEvent else { return false }
            
            // Vérifier que la réservation concerne un de nos assets
            guard assetIds.contains(reservation.assetId) else { return false }
            
            // Exclure les réservations annulées
            guard reservation.status != .cancelled else { return false }
            
            // Vérifier le chevauchement de dates
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
        // Période 1 commence avant la fin de période 2
        // ET période 1 se termine après le début de période 2
        return start1 < end2 && end1 > start2
    }
    
    /// Calcule la disponibilité pour plusieurs articles en une fois
    func checkAvailabilityBatch(
        for stockItems: [StockItem],
        event: Event,
        requestedQuantities: [String: Int], // sku -> quantity
        allAssets: [Asset],
        allReservations: [AssetReservation]
    ) -> [String: AvailabilityResult] {
        
        var results: [String: AvailabilityResult] = [:]
        
        for item in stockItems {
            let quantity = requestedQuantities[item.sku] ?? 0
            let result = checkAvailability(
                for: item,
                event: event,
                requestedQuantity: quantity,
                allAssets: allAssets,
                allReservations: allReservations
            )
            results[item.sku] = result
        }
        
        return results
    }
}

// MARK: - Availability Result

/// Résultat de vérification de disponibilité
struct AvailabilityResult {
    let requestedQuantity: Int
    let availableQuantity: Int
    let totalQuantity: Int
    let reservedQuantity: Int
    let conflicts: [AssetReservation]
    let canFulfill: Bool
    
    /// Message d'avertissement si applicable
    var warning: String? {
        if !canFulfill {
            return "Stock insuffisant : \(availableQuantity)/\(requestedQuantity) disponible"
        }
        if conflicts.count > 0 {
            return "Attention : \(conflicts.count) asset(s) déjà réservé(s)"
        }
        return nil
    }
    
    /// Niveau de criticité
    var severity: AvailabilitySeverity {
        if !canFulfill {
            return .critical
        }
        if availableQuantity < requestedQuantity + 2 {
            return .warning
        }
        return .ok
    }
    
    /// Pourcentage de disponibilité
    var availabilityPercentage: Double {
        guard totalQuantity > 0 else { return 0 }
        return Double(availableQuantity) / Double(totalQuantity)
    }
}

enum AvailabilitySeverity {
    case ok
    case warning
    case critical
}

// MARK: - Extension pour StockItem

extension StockItem {
    /// Vérifie rapidement la disponibilité pour cet item
    @MainActor
    func checkAvailability(
        for event: Event,
        requestedQuantity: Int,
        allAssets: [Asset],
        allReservations: [AssetReservation]
    ) -> AvailabilityResult {
        let service = AvailabilityService()
        return service.checkAvailability(
            for: self,
            event: event,
            requestedQuantity: requestedQuantity,
            allAssets: allAssets,
            allReservations: allReservations
        )
    }
}

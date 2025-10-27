//
//  ScanListService.swift
//  LogiScan
//
//  Created by Assistant on 15/10/2025.
//

import Foundation
import SwiftData

@MainActor
class ScanListService: ObservableObject {
    
    /// Génère les listes de scan selon les directions sélectionnées dans l'événement
    func generateSelectedScanLists(
        from event: Event,
        quoteItems: [QuoteItem],
        modelContext: ModelContext
    ) throws -> [ScanList] {
        print("📋 [ScanListService] Génération des listes de scan pour l'événement: \(event.name)")
        
        // Vérifier que l'événement est finalisé
        guard event.quoteStatus == .finalized else {
            throw ScanListError.eventNotFinalized
        }
        
        // Vérifier qu'il y a des items
        guard !quoteItems.isEmpty else {
            throw ScanListError.noItemsInQuote
        }
        
        // Récupérer les directions sélectionnées
        let selectedDirections: [ScanDirection]
        if !event.selectedScanDirections.isEmpty {
            // Utiliser les directions sélectionnées lors de la création
            selectedDirections = event.selectedScanDirections.compactMap { ScanDirection(rawValue: $0) }
            print("✅ [ScanListService] Utilisation des directions sélectionnées: \(selectedDirections.map { $0.rawValue })")
        } else {
            // Si aucune sélection, générer toutes les listes (comportement par défaut)
            selectedDirections = [.stockToTruck, .truckToEvent, .eventToTruck, .truckToStock]
            print("⚠️ [ScanListService] Aucune sélection trouvée, génération de toutes les listes")
        }
        
        // Supprimer les anciennes listes de scan pour cet événement
        try deleteExistingScanLists(for: event.eventId, modelContext: modelContext)
        
        var createdLists: [ScanList] = []
        
        // Créer une liste pour chaque direction sélectionnée
        for direction in selectedDirections {
            let scanList = try createScanList(
                from: event,
                quoteItems: quoteItems,
                direction: direction,
                modelContext: modelContext
            )
            createdLists.append(scanList)
        }
        
        print("✅ [ScanListService] \(createdLists.count) listes de scan créées")
        
        return createdLists
    }
    
    /// Génère les 4 listes de scan complètes pour un événement finalisé (pour compatibilité)
    func generateAllScanLists(
        from event: Event,
        quoteItems: [QuoteItem],
        modelContext: ModelContext
    ) throws -> [ScanList] {
        print("📋 [ScanListService] Génération des 4 listes de scan pour l'événement: \(event.name)")
        
        // Si des directions sont sélectionnées, les utiliser
        if !event.selectedScanDirections.isEmpty {
            return try generateSelectedScanLists(from: event, quoteItems: quoteItems, modelContext: modelContext)
        }
        
        // Sinon, comportement par défaut : toutes les listes
        // Vérifier que l'événement est finalisé
        guard event.quoteStatus == .finalized else {
            throw ScanListError.eventNotFinalized
        }
        
        // Vérifier qu'il y a des items
        guard !quoteItems.isEmpty else {
            throw ScanListError.noItemsInQuote
        }
        
        // Supprimer les anciennes listes de scan pour cet événement
        try deleteExistingScanLists(for: event.eventId, modelContext: modelContext)
        
        var createdLists: [ScanList] = []
        let directions: [ScanDirection] = [.stockToTruck, .truckToEvent, .eventToTruck, .truckToStock]
        
        // Créer une liste pour chaque direction
        for direction in directions {
            let scanList = try createScanList(
                from: event,
                quoteItems: quoteItems,
                direction: direction,
                modelContext: modelContext
            )
            createdLists.append(scanList)
        }
        
        print("✅ [ScanListService] \(createdLists.count) listes de scan créées pour toutes les directions")
        
        return createdLists
    }
    
    /// Supprime les listes de scan existantes pour un événement
    private func deleteExistingScanLists(for eventId: String, modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<ScanList>(
            predicate: #Predicate<ScanList> { scanList in
                scanList.eventId == eventId
            }
        )
        
        let existingLists = try modelContext.fetch(descriptor)
        
        if !existingLists.isEmpty {
            print("🗑️ [ScanListService] Suppression de \(existingLists.count) anciennes listes")
            for list in existingLists {
                modelContext.delete(list)
            }
            try modelContext.save()
        }
    }
    
    /// Crée une liste de scan pour une direction spécifique
    private func createScanList(
        from event: Event,
        quoteItems: [QuoteItem],
        direction: ScanDirection,
        modelContext: ModelContext
    ) throws -> ScanList {
        print("🔄 [ScanListService] Création liste avec direction: \(direction.rawValue)")
        
        // Créer la ScanList avec la direction
        let scanList = ScanList(
            eventId: event.eventId,
            eventName: event.name,
            scanDirection: direction,
            totalItems: quoteItems.reduce(0) { $0 + $1.quantity },
            scannedItems: 0,
            status: .pending
        )
        
        print("✅ [ScanListService] Liste créée - scanDirection: \(scanList.scanDirection.rawValue), displayName: \(scanList.displayName)")
        
        // Créer les ScanListItems
        for quoteItem in quoteItems {
            let scanListItem = PreparationListItem(
                scanListId: scanList.scanListId,
                sku: quoteItem.sku,
                name: quoteItem.name,
                category: quoteItem.category,
                quantityRequired: quoteItem.quantity,
                quantityScanned: 0,
                scannedAssets: [],
                status: .pending
            )
            scanListItem.scanList = scanList
            scanList.items.append(scanListItem)
            modelContext.insert(scanListItem)
        }
        
        // Sauvegarder
        modelContext.insert(scanList)
        try modelContext.save()
        
        print("✅ [ScanListService] Liste créée: \(direction.displayName) - \(scanList.items.count) items")
        
        return scanList
    }
    
    /// Génère une ScanList à partir d'un Event finalisé (ancienne méthode - deprecated)
    @available(*, deprecated, message: "Utiliser generateAllScanLists à la place")
    func generateScanList(
        from event: Event,
        quoteItems: [QuoteItem],
        modelContext: ModelContext
    ) throws -> ScanList {
        print("📋 [ScanListService] Génération de la ScanList pour l'événement: \(event.name)")
        
        // Vérifier que l'événement est finalisé
        guard event.quoteStatus == .finalized else {
            throw ScanListError.eventNotFinalized
        }
        
        // Vérifier qu'il y a des items
        guard !quoteItems.isEmpty else {
            throw ScanListError.noItemsInQuote
        }
        
        // Créer la ScanList avec une direction par défaut (deprecated)
        let scanList = ScanList(
            eventId: event.eventId,
            eventName: event.name,
            scanDirection: .stockToTruck,  // Direction par défaut pour compatibilité
            totalItems: quoteItems.reduce(0) { $0 + $1.quantity },
            scannedItems: 0,
            status: .pending
        )
        
        // Créer les ScanListItems
        for quoteItem in quoteItems {
            let scanListItem = PreparationListItem(
                scanListId: scanList.scanListId,
                sku: quoteItem.sku,
                name: quoteItem.name,
                category: quoteItem.category,
                quantityRequired: quoteItem.quantity,
                quantityScanned: 0,
                scannedAssets: [],
                status: .pending
            )
            scanListItem.scanList = scanList
            scanList.items.append(scanListItem)
            modelContext.insert(scanListItem)
        }
        
        // Sauvegarder
        modelContext.insert(scanList)
        try modelContext.save()
        
        print("✅ [ScanListService] ScanList créée: \(scanList.items.count) items, \(scanList.totalItems) unités totales")
        
        return scanList
    }
    
    /// Enregistre un scan d'asset
    func recordScan(
        assetId: String,
        sku: String,
        scanList: ScanList,
        allAssets: [Asset],
        modelContext: ModelContext
    ) throws {
        print("📱 [ScanListService] Scan de l'asset: \(assetId)")
        
        // Vérifier que l'asset existe
        guard let asset = allAssets.first(where: { $0.assetId == assetId }) else {
            throw ScanListError.assetNotFound
        }
        
        // Vérifier que le SKU correspond
        guard asset.sku == sku else {
            throw ScanListError.skuMismatch(expected: sku, found: asset.sku)
        }
        
        // Trouver le ScanListItem correspondant
        guard let scanListItem = scanList.items.first(where: { $0.sku == sku }) else {
            throw ScanListError.itemNotInList
        }
        
        // Vérifier que l'asset n'est pas déjà scanné
        if scanListItem.scannedAssets.contains(assetId) {
            throw ScanListError.assetAlreadyScanned
        }
        
        // Vérifier qu'on ne dépasse pas la quantité requise
        if scanListItem.quantityScanned >= scanListItem.quantityRequired {
            throw ScanListError.quantityExceeded
        }
        
        // Ajouter le scan
        scanListItem.addScannedAsset(assetId)
        
        // Mettre à jour la ScanList
        scanList.scannedItems = scanList.items.reduce(0) { $0 + $1.quantityScanned }
        scanList.updatedAt = Date()
        
        // Vérifier si la liste est complète
        if scanList.isComplete {
            scanList.status = .completed
            scanList.completedAt = Date()
            print("🎉 [ScanListService] Liste de scan complétée!")
        } else if scanList.status == .pending {
            scanList.status = .inProgress
        }
        
        // Sauvegarder
        try modelContext.save()
        
        print("✅ [ScanListService] Scan enregistré: \(scanListItem.name) (\(scanListItem.quantityScanned)/\(scanListItem.quantityRequired))")
    }
    
    /// Annule un scan d'asset
    func undoScan(
        assetId: String,
        sku: String,
        scanList: ScanList,
        modelContext: ModelContext
    ) throws {
        print("↩️ [ScanListService] Annulation du scan: \(assetId)")
        
        // Trouver le ScanListItem correspondant
        guard let scanListItem = scanList.items.first(where: { $0.sku == sku }) else {
            throw ScanListError.itemNotInList
        }
        
        // Vérifier que l'asset est bien scanné
        guard scanListItem.scannedAssets.contains(assetId) else {
            throw ScanListError.assetNotScanned
        }
        
        // Retirer le scan
        scanListItem.removeScannedAsset(assetId)
        
        // Mettre à jour la ScanList
        scanList.scannedItems = scanList.items.reduce(0) { $0 + $1.quantityScanned }
        scanList.updatedAt = Date()
        
        // Mettre à jour le statut
        if scanList.scannedItems == 0 {
            scanList.status = .pending
        } else if scanList.status == .completed {
            scanList.status = .inProgress
        }
        
        // Sauvegarder
        try modelContext.save()
        
        print("✅ [ScanListService] Scan annulé: \(scanListItem.name) (\(scanListItem.quantityScanned)/\(scanListItem.quantityRequired))")
    }
    
    /// Réinitialise une ScanList
    func resetScanList(
        _ scanList: ScanList,
        modelContext: ModelContext
    ) throws {
        print("🔄 [ScanListService] Réinitialisation de la ScanList")
        
        // Réinitialiser tous les items
        for item in scanList.items {
            item.scannedAssets = []
            item.quantityScanned = 0
            item.status = .pending
            item.lastScannedAt = nil
        }
        
        // Réinitialiser la liste
        scanList.scannedItems = 0
        scanList.status = .pending
        scanList.updatedAt = Date()
        scanList.completedAt = nil
        
        // Sauvegarder
        try modelContext.save()
        
        print("✅ [ScanListService] ScanList réinitialisée")
    }
    
    /// Récupère la ScanList d'un événement
    func getScanList(
        for eventId: String,
        from allScanLists: [ScanList]
    ) -> ScanList? {
        return allScanLists.first { $0.eventId == eventId }
    }
    
    /// Supprime une ScanList
    func deleteScanList(
        _ scanList: ScanList,
        modelContext: ModelContext
    ) throws {
        print("🗑️ [ScanListService] Suppression de la ScanList")
        
        // SwiftData supprimera automatiquement les items grâce à deleteRule: .cascade
        modelContext.delete(scanList)
        
        try modelContext.save()
        
        print("✅ [ScanListService] ScanList supprimée")
    }
}

enum ScanListError: LocalizedError {
    case eventNotFinalized
    case noItemsInQuote
    case assetNotFound
    case skuMismatch(expected: String, found: String)
    case itemNotInList
    case assetAlreadyScanned
    case assetNotScanned
    case quantityExceeded
    
    var errorDescription: String? {
        switch self {
        case .eventNotFinalized:
            return "L'événement n'est pas finalisé. Veuillez d'abord finaliser le devis."
        case .noItemsInQuote:
            return "Le devis ne contient aucun article."
        case .assetNotFound:
            return "❌ Asset introuvable\n\nVeuillez vérifier le QR code scanné."
        case .skuMismatch(let expected, let found):
            return """
⚠️ Mauvais article scanné

Attendu : \(expected)
Scanné : \(found)

💡 Scannez le bon article
"""
        case .itemNotInList:
            return """
❌ Article hors liste

Cet article n'est pas dans la liste de préparation actuelle.

💡 Vérifiez la liste active
"""
        case .assetAlreadyScanned:
            return "✅ Cet asset a déjà été scanné"
        case .assetNotScanned:
            return "❌ Cet asset n'a pas été scanné"
        case .quantityExceeded:
            return "✅ Quantité déjà atteinte pour cet article"
        }
    }
}

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
    private let firebaseService = FirebaseService()
    
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
        
        // 🆕 Synchroniser avec Firebase
        Task {
            do {
                try await syncScanListsToFirebase(createdLists, forEvent: event.eventId)
            } catch {
                print("⚠️ [ScanListService] Erreur sync Firebase (non bloquant): \(error)")
            }
        }
        
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
        
        // 🆕 Synchroniser avec Firebase
        Task {
            do {
                try await syncScanListsToFirebase(createdLists, forEvent: event.eventId)
            } catch {
                print("⚠️ [ScanListService] Erreur sync Firebase (non bloquant): \(error)")
            }
        }
        
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
        print("   - SKU: \(sku)")
        print("   - Liste: \(scanList.displayName)")
        print("   - Progression avant: \(scanList.scannedItems)/\(scanList.totalItems)")
        
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
        
        print("   - Item trouvé: \(scanListItem.name)")
        print("   - Quantité item avant: \(scanListItem.quantityScanned)/\(scanListItem.quantityRequired)")
        print("   - Statut item avant: \(scanListItem.status.displayName)")
        
        // Vérifier que l'asset n'est pas déjà scanné
        if scanListItem.scannedAssets.contains(assetId) {
            throw ScanListError.assetAlreadyScanned(assetName: asset.name)
        }
        
        // Vérifier qu'on ne dépasse pas la quantité requise
        if scanListItem.quantityScanned >= scanListItem.quantityRequired {
            throw ScanListError.quantityExceeded
        }
        
        // 🔧 Ajouter le scan (updateStatus() est appelé automatiquement dans addScannedAsset)
        scanListItem.addScannedAsset(assetId)
        
        print("   - Quantité item après: \(scanListItem.quantityScanned)/\(scanListItem.quantityRequired)")
        print("   - Statut item après: \(scanListItem.status.displayName)")
        print("   - Item complet: \(scanListItem.isComplete)")
        
        // 🆕 Mettre à jour le statut de l'asset en fonction de la direction du scan
        updateAssetStatus(asset: asset, scanDirection: scanList.scanDirection)
        
        // 🔧 Recalculer le total scanné de la liste
        let oldScannedItems = scanList.scannedItems
        scanList.scannedItems = scanList.items.reduce(0) { $0 + $1.quantityScanned }
        scanList.updatedAt = Date()
        
        print("   - Progression après calcul: \(scanList.scannedItems)/\(scanList.totalItems)")
        print("   - Variation: +\(scanList.scannedItems - oldScannedItems)")
        
        // 🔧 Vérifier si la liste est complète et mettre à jour son statut
        let oldStatus = scanList.status
        
        if scanList.isComplete {
            scanList.status = .completed
            scanList.completedAt = Date()
            print("🎉 [ScanListService] Liste de scan COMPLÉTÉE!")
            print("   - Statut: \(oldStatus.displayName) → \(scanList.status.displayName)")
        } else if scanList.status == .pending && scanList.scannedItems > 0 {
            scanList.status = .inProgress
            print("▶️ [ScanListService] Liste de scan EN COURS")
            print("   - Statut: \(oldStatus.displayName) → \(scanList.status.displayName)")
        }
        
        print("   - Statut final liste: \(scanList.status.displayName)")
        print("   - isComplete: \(scanList.isComplete)")
        
        // 🔧 Sauvegarder avec notification explicite des changements
        try modelContext.save()
        
        // 🆕 Synchroniser avec Firebase après chaque scan
        Task {
            do {
                try await syncScanListToFirebase(scanList)
            } catch {
                print("⚠️ [ScanListService] Erreur sync Firebase: \(error.localizedDescription)")
                // Ne pas bloquer le scan si la sync échoue
            }
        }
        
        print("✅ [ScanListService] Scan enregistré avec succès")
        print("📦 [ScanListService] Statut asset mis à jour: \(asset.status.displayName)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    /// Met à jour le statut d'un asset en fonction de la direction du scan
    private func updateAssetStatus(asset: Asset, scanDirection: ScanDirection) {
        let oldStatus = asset.status
        
        switch scanDirection {
        case .stockToTruck:
            // Stock → Camion : article en transport vers l'événement
            asset.status = .inTransitToEvent
            print("🚚 Asset \(asset.assetId) → Transport vers événement")
            
        case .truckToEvent:
            // Camion → Événement : article en utilisation
            asset.status = .inUse
            print("🎪 Asset \(asset.assetId) → En utilisation")
            
        case .eventToTruck:
            // Événement → Camion : article en transport vers le stock
            asset.status = .inTransitToStock
            print("🔙 Asset \(asset.assetId) → Transport vers stock")
            
        case .truckToStock:
            // Camion → Stock : article disponible
            asset.status = .available
            print("✅ Asset \(asset.assetId) → Disponible")
        }
        
        // 🔥 Synchroniser le statut avec Firebase
        if oldStatus != asset.status {
            Task {
                do {
                    try await firebaseService.updateAssetStatus(
                        assetId: asset.assetId,
                        stockSku: asset.sku,
                        newStatus: asset.status.rawValue,
                        location: asset.currentLocationId
                    )
                    print("✅ [ScanListService] Statut de l'asset synchronisé avec Firebase")
                } catch {
                    print("⚠️ [ScanListService] Erreur sync statut asset Firebase: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Annule un scan d'asset
    func undoScan(
        assetId: String,
        sku: String,
        scanList: ScanList,
        modelContext: ModelContext
    ) throws {
        print("↩️ [ScanListService] Annulation du scan: \(assetId)")
        print("   - SKU: \(sku)")
        print("   - Progression avant: \(scanList.scannedItems)/\(scanList.totalItems)")
        print("   - Statut avant: \(scanList.status.displayName)")
        
        // Trouver le ScanListItem correspondant
        guard let scanListItem = scanList.items.first(where: { $0.sku == sku }) else {
            throw ScanListError.itemNotInList
        }
        
        print("   - Item: \(scanListItem.name)")
        print("   - Quantité item avant: \(scanListItem.quantityScanned)/\(scanListItem.quantityRequired)")
        
        // Vérifier que l'asset est bien scanné
        guard scanListItem.scannedAssets.contains(assetId) else {
            throw ScanListError.assetNotScanned
        }
        
        // 🔧 Retirer le scan (updateStatus() est appelé automatiquement dans removeScannedAsset)
        scanListItem.removeScannedAsset(assetId)
        
        print("   - Quantité item après: \(scanListItem.quantityScanned)/\(scanListItem.quantityRequired)")
        print("   - Statut item après: \(scanListItem.status.displayName)")
        
        // 🔧 Recalculer le total scanné de la liste
        scanList.scannedItems = scanList.items.reduce(0) { $0 + $1.quantityScanned }
        scanList.updatedAt = Date()
        
        // 🔧 Mettre à jour le statut de la liste
        if scanList.scannedItems == 0 {
            scanList.status = .pending
            scanList.completedAt = nil
            print("⏸️ [ScanListService] Liste remise en attente")
        } else if scanList.status == .completed {
            // Si la liste était complète et qu'on annule un scan, elle repasse en cours
            scanList.status = .inProgress
            scanList.completedAt = nil
            print("▶️ [ScanListService] Liste remise en cours")
        }
        
        print("   - Progression après: \(scanList.scannedItems)/\(scanList.totalItems)")
        print("   - Statut après: \(scanList.status.displayName)")
        
        // Sauvegarder
        try modelContext.save()
        
        print("✅ [ScanListService] Scan annulé avec succès")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    // MARK: - Validation manuelle (sans scan)
    
    /// ✅ Incrémente manuellement la quantité d'un item (validation manuelle sans scan)
    func manualIncrement(
        sku: String,
        scanList: ScanList,
        modelContext: ModelContext
    ) throws {
        print("➕ [ScanListService] Incrémentation manuelle pour SKU: \(sku)")
        
        // Trouver le ScanListItem correspondant
        guard let scanListItem = scanList.items.first(where: { $0.sku == sku }) else {
            throw ScanListError.itemNotInList
        }
        
        print("   - Item: \(scanListItem.name)")
        print("   - Quantité avant: \(scanListItem.quantityScanned)/\(scanListItem.quantityRequired)")
        
        // Vérifier qu'on ne dépasse pas la quantité requise
        guard scanListItem.quantityScanned < scanListItem.quantityRequired else {
            throw ScanListError.quantityExceeded
        }
        
        // Incrémenter la quantité (en ajoutant un ID fictif pour représenter la validation manuelle)
        let manualId = "MANUAL-\(UUID().uuidString.prefix(8))"
        scanListItem.addScannedAsset(manualId)
        
        print("   - Quantité après: \(scanListItem.quantityScanned)/\(scanListItem.quantityRequired)")
        print("   - Statut item: \(scanListItem.status.displayName)")
        
        // Recalculer le total de la liste
        let oldScannedItems = scanList.scannedItems
        scanList.scannedItems = scanList.items.reduce(0) { $0 + $1.quantityScanned }
        scanList.updatedAt = Date()
        
        print("   - Progression liste: \(scanList.scannedItems)/\(scanList.totalItems) (+\(scanList.scannedItems - oldScannedItems))")
        
        // Mettre à jour le statut de la liste
        if scanList.isComplete {
            scanList.status = .completed
            scanList.completedAt = Date()
            print("🎉 Liste complétée!")
        } else if scanList.status == .pending && scanList.scannedItems > 0 {
            scanList.status = .inProgress
            print("▶️ Liste en cours")
        }
        
        // Sauvegarder
        try modelContext.save()
        
        // Synchroniser avec Firebase
        Task {
            do {
                try await syncScanListToFirebase(scanList)
            } catch {
                print("⚠️ [ScanListService] Erreur sync Firebase: \(error.localizedDescription)")
            }
        }
        
        print("✅ [ScanListService] Incrémentation manuelle réussie")
    }
    
    /// ✅ Décrémente manuellement la quantité d'un item
    func manualDecrement(
        sku: String,
        scanList: ScanList,
        modelContext: ModelContext
    ) throws {
        print("➖ [ScanListService] Décrémentation manuelle pour SKU: \(sku)")
        
        // Trouver le ScanListItem correspondant
        guard let scanListItem = scanList.items.first(where: { $0.sku == sku }) else {
            throw ScanListError.itemNotInList
        }
        
        print("   - Item: \(scanListItem.name)")
        print("   - Quantité avant: \(scanListItem.quantityScanned)/\(scanListItem.quantityRequired)")
        
        // Vérifier qu'il y a quelque chose à décrémenter
        guard scanListItem.quantityScanned > 0 else {
            print("⚠️ Aucune quantité à décrémenter")
            return
        }
        
        // Retirer le dernier asset scanné (priorité aux validations manuelles)
        if let lastAsset = scanListItem.scannedAssets.last {
            scanListItem.removeScannedAsset(lastAsset)
        }
        
        print("   - Quantité après: \(scanListItem.quantityScanned)/\(scanListItem.quantityRequired)")
        print("   - Statut item: \(scanListItem.status.displayName)")
        
        // Recalculer le total de la liste
        scanList.scannedItems = scanList.items.reduce(0) { $0 + $1.quantityScanned }
        scanList.updatedAt = Date()
        
        // Mettre à jour le statut de la liste
        if scanList.scannedItems == 0 {
            scanList.status = .pending
            scanList.completedAt = nil
            print("⏸️ Liste remise en attente")
        } else if scanList.status == .completed {
            scanList.status = .inProgress
            scanList.completedAt = nil
            print("▶️ Liste remise en cours")
        }
        
        print("   - Progression liste: \(scanList.scannedItems)/\(scanList.totalItems)")
        
        // Sauvegarder
        try modelContext.save()
        
        // Synchroniser avec Firebase
        Task {
            do {
                try await syncScanListToFirebase(scanList)
            } catch {
                print("⚠️ [ScanListService] Erreur sync Firebase: \(error.localizedDescription)")
            }
        }
        
        print("✅ [ScanListService] Décrémentation manuelle réussie")
    }
    
    /// Recalcule et met à jour le statut d'une ScanList en fonction de ses items
    func refreshScanListStatus(
        _ scanList: ScanList,
        modelContext: ModelContext
    ) throws {
        print("🔄 [ScanListService] Rafraîchissement du statut de la ScanList")
        
        // 🐛 FIX: Si les items sont vides mais totalItems > 0, c'est une erreur de sync
        if scanList.items.isEmpty && scanList.totalItems > 0 {
            print("⚠️ [ScanListService] Incohérence détectée : totalItems = \(scanList.totalItems) mais items est vide!")
            print("   → Impossible de recalculer le statut sans les items. Marquage comme 'En attente'.")
            
            // Réinitialiser les compteurs
            scanList.scannedItems = 0
            scanList.totalItems = 0  // Forcer à 0 pour éviter l'affichage erroné
            scanList.status = .pending
            scanList.updatedAt = Date()
            
            try modelContext.save()
            print("📊 [ScanListService] Statut: En attente - Liste vide (sync incomplète)")
            return
        }
        
        // Recalculer le total scanné
        let totalScanned = scanList.items.reduce(0) { $0 + $1.quantityScanned }
        scanList.scannedItems = totalScanned
        
        let oldStatus = scanList.status
        
        // Mettre à jour le statut basé sur la progression
        if scanList.isComplete {
            // Liste complète
            if scanList.status != .completed {
                scanList.status = .completed
                scanList.completedAt = Date()
                print("✅ [ScanListService] Liste marquée comme complétée!")
            }
        } else if totalScanned > 0 {
            // Progression partielle
            if scanList.status == .pending {
                scanList.status = .inProgress
                print("▶️ [ScanListService] Liste marquée comme en cours")
            }
        } else {
            // Aucune progression
            if scanList.status != .pending && scanList.status != .cancelled {
                scanList.status = .pending
                print("⏸️ [ScanListService] Liste marquée comme en attente")
            }
        }
        
        scanList.updatedAt = Date()
        
        // Sauvegarder
        try modelContext.save()
        
        print("📊 [ScanListService] Statut: \(scanList.status.displayName) - Progression: \(scanList.scannedItems)/\(scanList.totalItems)")
        
        // 🆕 Mettre à jour le statut du camion si le statut a changé
        if oldStatus != scanList.status {
            do {
                try TruckStatusService.handleScanListChange(
                    scanList: scanList,
                    modelContext: modelContext
                )
            } catch {
                print("⚠️ [ScanListService] Erreur mise à jour statut camion: \(error)")
                // Non bloquant
            }
        }
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

// MARK: - Firebase Synchronization

extension ScanListService {
    /// Synchronise une seule ScanList avec Firebase (utilisé après chaque scan)
    private func syncScanListToFirebase(_ scanList: ScanList) async throws {
        print("☁️ [ScanListService] Synchronisation ScanList \(scanList.scanListId) vers Firebase...")
        
        let firestoreScanList = scanList.toFirestoreScanList()
        try await firebaseService.updateScanList(firestoreScanList, forEvent: scanList.eventId)
        
        print("✅ [ScanListService] ScanList synchronisée avec Firebase (status: \(scanList.status.displayName))")
    }
    
    /// Synchronise les listes de scan avec Firebase
    private func syncScanListsToFirebase(_ scanLists: [ScanList], forEvent eventId: String) async throws {
        print("☁️ [ScanListService] Synchronisation de \(scanLists.count) ScanLists vers Firebase...")
        
        // Supprimer les anciennes listes dans Firebase
        try await firebaseService.deleteAllScanLists(forEvent: eventId)
        
        // Créer les nouvelles listes
        for scanList in scanLists {
            let firestoreScanList = scanList.toFirestoreScanList()
            try await firebaseService.createScanList(firestoreScanList, forEvent: eventId)
        }
        
        print("✅ [ScanListService] \(scanLists.count) ScanLists synchronisées avec Firebase")
    }
    
    /// Récupère les listes de scan depuis Firebase et les synchronise localement
    /// ⚠️ IMPORTANT: Cette fonction doit régénérer les items depuis les QuoteItems de l'Event
    func fetchScanListsFromFirebase(
        forEvent event: Event,
        quoteItems: [QuoteItem],
        modelContext: ModelContext
    ) async throws -> [ScanList] {
        print("📥 [ScanListService] Récupération des ScanLists depuis Firebase...")
        
        let firestoreScanLists = try await firebaseService.fetchScanLists(forEvent: event.eventId)
        
        // Supprimer les listes locales existantes
        try deleteExistingScanLists(for: event.eventId, modelContext: modelContext)
        
        // Créer les listes locales depuis Firebase AVEC leurs items depuis les QuoteItems
        var localScanLists: [ScanList] = []
        for firestoreScanList in firestoreScanLists {
            if let scanList = firestoreScanList.toScanList() {
                // ✅ SAUVEGARDER les valeurs depuis Firebase AVANT de régénérer les items
                let firebaseScannedItems = scanList.scannedItems
                let firebaseStatus = scanList.status
                let firebaseCompletedAt = scanList.completedAt
                
                print("🔄 [ScanListService] Restauration depuis Firebase: \(scanList.displayName)")
                print("   - Statut Firebase: \(firebaseStatus.displayName)")
                print("   - Progression Firebase: \(firebaseScannedItems)/\(scanList.totalItems)")
                
                modelContext.insert(scanList)
                
                // 🔥 Régénérer les PreparationListItems depuis les QuoteItems (structure seulement)
                for quoteItem in quoteItems {
                    let scanListItem = PreparationListItem(
                        scanListId: scanList.scanListId,
                        sku: quoteItem.sku,
                        name: quoteItem.name,
                        category: quoteItem.category,
                        quantityRequired: quoteItem.quantity,
                        quantityScanned: 0,  // Sera restauré depuis Firebase
                        scannedAssets: [],
                        status: .pending
                    )
                    scanListItem.scanList = scanList
                    scanList.items.append(scanListItem)
                    modelContext.insert(scanListItem)
                }
                
                // ✅ RESTAURER les valeurs depuis Firebase au lieu de tout réinitialiser
                scanList.scannedItems = firebaseScannedItems
                scanList.status = firebaseStatus
                scanList.completedAt = firebaseCompletedAt
                
                print("✅ [ScanListService] \(scanList.items.count) items créés avec statut restauré")
                print("   - Statut final: \(scanList.status.displayName)")
                print("   - Progression finale: \(scanList.scannedItems)/\(scanList.totalItems)")
                
                localScanLists.append(scanList)
            }
        }
        
        try modelContext.save()
        
        print("✅ [ScanListService] \(localScanLists.count) ScanLists synchronisées depuis Firebase")
        return localScanLists
    }
    
    /// Met à jour une ScanList locale et la synchronise avec Firebase
    func updateScanListWithSync(_ scanList: ScanList, forEvent eventId: String, modelContext: ModelContext) async throws {
        // Sauvegarder localement
        scanList.updatedAt = Date()
        try modelContext.save()
        
        // Synchroniser avec Firebase
        let firestoreScanList = scanList.toFirestoreScanList()
        try await firebaseService.updateScanList(firestoreScanList, forEvent: eventId)
        
        print("✅ [ScanListService] ScanList mise à jour et synchronisée: \(scanList.displayName)")
    }
}


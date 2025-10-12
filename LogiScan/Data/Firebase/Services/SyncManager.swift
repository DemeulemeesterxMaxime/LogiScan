//
//  SyncManager.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import Foundation
import SwiftData

/// Service de synchronisation bidirectionnelle entre SwiftData (local) et Firestore (cloud)
@MainActor
class SyncManager: ObservableObject {
    private let firebaseService: FirebaseService

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [String] = []

    init() {
        self.firebaseService = FirebaseService()
    }

    // MARK: - Stock Items Synchronization

    /// Synchroniser un StockItem vers Firebase après sauvegarde locale
    func syncStockItemToFirebase(_ stockItem: StockItem) async {
        do {
            // Utiliser l'extension existante pour convertir
            let firestoreItem = stockItem.toFirestoreStockItem()
            try await firebaseService.createStockItem(firestoreItem)

            print("✅ [SyncManager] Article synchronisé : \(stockItem.sku)")
            lastSyncDate = Date()

            // Supprimer l'erreur si elle existait
            syncErrors.removeAll { $0.contains(stockItem.sku) }

        } catch {
            let errorMsg =
                "❌ Erreur sync Firebase pour \(stockItem.sku): \(error.localizedDescription)"
            print(errorMsg)
            syncErrors.append(errorMsg)

            // Ne pas bloquer l'utilisateur - les données sont quand même en local
            // On retentera la sync plus tard
        }
    }

    /// Mettre à jour un StockItem existant dans Firebase
    func updateStockItemInFirebase(_ stockItem: StockItem) async {
        do {
            let firestoreItem = stockItem.toFirestoreStockItem()
            try await firebaseService.updateStockItem(firestoreItem)

            print("✅ [SyncManager] Article mis à jour dans Firebase : \(stockItem.sku)")
            lastSyncDate = Date()

            syncErrors.removeAll { $0.contains(stockItem.sku) }

        } catch {
            let errorMsg =
                "❌ Erreur mise à jour Firebase pour \(stockItem.sku): \(error.localizedDescription)"
            print(errorMsg)
            syncErrors.append(errorMsg)
        }
    }

    /// Supprimer un StockItem de Firebase
    func deleteStockItemFromFirebase(sku: String) async {
        do {
            try await firebaseService.deleteStockItem(sku: sku)

            print("✅ [SyncManager] Article supprimé de Firebase : \(sku)")
            lastSyncDate = Date()

            syncErrors.removeAll { $0.contains(sku) }

        } catch {
            let errorMsg =
                "❌ Erreur suppression Firebase pour \(sku): \(error.localizedDescription)"
            print(errorMsg)
            syncErrors.append(errorMsg)
        }
    }

    // MARK: - Assets Synchronization

    /// Synchroniser un Asset vers Firebase après sauvegarde locale
    func syncAssetToFirebase(_ asset: Asset) async {
        do {
            let firestoreAsset = asset.toFirestoreAsset()
            try await firebaseService.createAsset(firestoreAsset, forStock: asset.sku)

            print("✅ [SyncManager] Asset synchronisé : \(asset.assetId)")
            lastSyncDate = Date()

            syncErrors.removeAll { $0.contains(asset.assetId) }

        } catch {
            let errorMsg =
                "❌ Erreur sync Firebase pour asset \(asset.assetId): \(error.localizedDescription)"
            print(errorMsg)
            syncErrors.append(errorMsg)
        }
    }

    /// Mettre à jour un Asset existant dans Firebase
    func updateAssetInFirebase(_ asset: Asset) async {
        do {
            let firestoreAsset = asset.toFirestoreAsset()
            // Utiliser createAsset avec merge pour la mise à jour
            try await firebaseService.createAsset(firestoreAsset, forStock: asset.sku)

            print("✅ [SyncManager] Asset mis à jour dans Firebase : \(asset.assetId)")
            lastSyncDate = Date()

            syncErrors.removeAll { $0.contains(asset.assetId) }

        } catch {
            let errorMsg =
                "❌ Erreur mise à jour Firebase pour asset \(asset.assetId): \(error.localizedDescription)"
            print(errorMsg)
            syncErrors.append(errorMsg)
        }
    }

    /// Supprimer un Asset de Firebase
    func deleteAssetFromFirebase(assetId: String, stockSku: String) async {
        do {
            try await firebaseService.deleteAsset(assetId: assetId, stockSku: stockSku)

            print("✅ [SyncManager] Asset supprimé de Firebase : \(assetId)")
            lastSyncDate = Date()

            syncErrors.removeAll { $0.contains(assetId) }

        } catch {
            let errorMsg =
                "❌ Erreur suppression Firebase pour asset \(assetId): \(error.localizedDescription)"
            print(errorMsg)
            syncErrors.append(errorMsg)
        }
    }

    // MARK: - Synchronisation Complète (Download depuis Firebase)

    /// Récupérer tous les items depuis Firebase et mettre à jour SwiftData
    func syncFromFirebase(modelContext: ModelContext) async {
        guard !isSyncing else {
            print("⚠️ [SyncManager] Synchronisation déjà en cours")
            return
        }

        print("🔄 [SyncManager] Début de la synchronisation depuis Firebase...")
        isSyncing = true
        defer { isSyncing = false }

        // Synchroniser en parallèle les différentes collections
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.syncStockItemsFromFirebase(modelContext: modelContext) }
            group.addTask { await self.syncEventsFromFirebase(modelContext: modelContext) }
            group.addTask { await self.syncTrucksFromFirebase(modelContext: modelContext) }
        }
        
        lastSyncDate = Date()
        print("✅ [SyncManager] Synchronisation complète terminée")
    }
    
    // MARK: - Sync StockItems
    
    private func syncStockItemsFromFirebase(modelContext: ModelContext) async {

        do {
            let firestoreItems = try await firebaseService.fetchStockItems()
            print("📥 [SyncManager] \(firestoreItems.count) articles récupérés depuis Firebase")

            // Créer un dictionnaire des items locaux par SKU
            let fetchDescriptor = FetchDescriptor<StockItem>()
            let localItems = try modelContext.fetch(fetchDescriptor)
            let localItemsDict = Dictionary(uniqueKeysWithValues: localItems.map { ($0.sku, $0) })

            var itemsCreated = 0
            var itemsUpdated = 0
            var itemsDeleted = 0

            // Créer un Set des SKU Firebase pour comparaison rapide
            let firebaseSKUs = Set(firestoreItems.map { $0.sku })

            // Synchroniser chaque item Firebase
            for firestoreItem in firestoreItems {
                if let existingItem = localItemsDict[firestoreItem.sku] {
                    // Mettre à jour l'item existant si Firebase est plus récent
                    if updateLocalStockItem(existingItem, from: firestoreItem) {
                        itemsUpdated += 1
                    }
                } else {
                    // Créer un nouvel item local
                    let newItem = firestoreItem.toStockItem()
                    modelContext.insert(newItem)
                    itemsCreated += 1
                }
            }

            // 🔥 NOUVEAU : Supprimer les items locaux qui n'existent plus dans Firebase
            for localItem in localItems {
                if !firebaseSKUs.contains(localItem.sku) {
                    print(
                        "🗑️ [SyncManager] Suppression de l'article local orphelin : \(localItem.sku)"
                    )
                    modelContext.delete(localItem)
                    itemsDeleted += 1
                }
            }

            try modelContext.save()

            print(
                "✅ [SyncManager] StockItems synchronisés : \(itemsCreated) créés, \(itemsUpdated) mis à jour, \(itemsDeleted) supprimés"
            )

            // 🔥 NOUVEAU : Synchroniser les Assets individuels pour chaque StockItem
            await syncAllAssetsFromFirebase(modelContext: modelContext, stockItems: firestoreItems)

            lastSyncDate = Date()

        } catch {
            let errorMsg = "❌ Erreur synchronisation depuis Firebase: \(error.localizedDescription)"
            print(errorMsg)
            syncErrors.append(errorMsg)
        }
    }
    
    /// Synchroniser tous les Assets individuels depuis Firebase
    private func syncAllAssetsFromFirebase(modelContext: ModelContext, stockItems: [FirestoreStockItem]) async {
        print("🔄 [SyncManager] Synchronisation des Assets individuels...")
        
        var totalAssetsCreated = 0
        var totalAssetsUpdated = 0
        var totalAssetsDeleted = 0
        
        // Récupérer tous les assets locaux une seule fois
        let fetchDescriptor = FetchDescriptor<Asset>()
        let allLocalAssets = (try? modelContext.fetch(fetchDescriptor)) ?? []
        let localAssetsDict = Dictionary(grouping: allLocalAssets, by: { $0.sku })
        
        for stockItem in stockItems {
            do {
                // Récupérer les assets depuis Firebase pour ce StockItem
                let firestoreAssets = try await firebaseService.fetchAssets(forStock: stockItem.sku)
                
                // Assets locaux pour ce SKU
                let localAssets = localAssetsDict[stockItem.sku] ?? []
                let localAssetsById = Dictionary(uniqueKeysWithValues: localAssets.map { ($0.assetId, $0) })
                
                // Set des assetIds Firebase
                let firebaseAssetIds = Set(firestoreAssets.map { $0.assetId })
                
                // Synchroniser chaque asset Firebase
                for firestoreAsset in firestoreAssets {
                    if let existingAsset = localAssetsById[firestoreAsset.assetId] {
                        // Mettre à jour si Firebase est plus récent
                        if updateLocalAsset(existingAsset, from: firestoreAsset) {
                            totalAssetsUpdated += 1
                        }
                    } else {
                        // Créer un nouvel asset local
                        let newAsset = firestoreAsset.toAsset()
                        modelContext.insert(newAsset)
                        totalAssetsCreated += 1
                    }
                }
                
                // Supprimer les assets locaux qui n'existent plus dans Firebase
                for localAsset in localAssets {
                    if !firebaseAssetIds.contains(localAsset.assetId) {
                        print("🗑️ [SyncManager] Suppression asset orphelin : \(localAsset.assetId)")
                        modelContext.delete(localAsset)
                        totalAssetsDeleted += 1
                    }
                }
                
            } catch {
                print("❌ [SyncManager] Erreur sync assets pour \(stockItem.sku): \(error)")
            }
        }
        
        // Sauvegarder tous les changements d'assets
        do {
            try modelContext.save()
            print("✅ [SyncManager] Assets synchronisés : \(totalAssetsCreated) créés, \(totalAssetsUpdated) mis à jour, \(totalAssetsDeleted) supprimés")
        } catch {
            print("❌ [SyncManager] Erreur sauvegarde assets : \(error)")
        }
    }
    
    /// Mettre à jour un Asset local depuis Firebase
    /// Retourne true si l'asset a été mis à jour
    private func updateLocalAsset(_ asset: Asset, from firestoreAsset: FirestoreAsset) -> Bool {
        // Ne mettre à jour que si la version Firebase est plus récente
        guard let firestoreUpdatedAt = firestoreAsset.updatedAt,
              firestoreUpdatedAt > asset.updatedAt
        else {
            return false
        }
        
        // Mettre à jour les propriétés
        asset.status = AssetStatus(rawValue: firestoreAsset.status) ?? .available
        asset.currentLocationId = firestoreAsset.currentLocationId
        asset.comments = firestoreAsset.comments
        asset.tags = firestoreAsset.tags
        asset.serialNumber = firestoreAsset.serialNumber
        
        if let lastMaintenance = firestoreAsset.lastMaintenanceDate {
            asset.lastMaintenanceDate = lastMaintenance
        }
        if let nextMaintenance = firestoreAsset.nextMaintenanceDate {
            asset.nextMaintenanceDate = nextMaintenance
        }
        
        asset.updatedAt = firestoreUpdatedAt
        
        print("🔄 [SyncManager] Asset local mis à jour : \(asset.assetId)")
        return true
    }

    /// Synchronisation rapide (uniquement si pas de sync récente)
    func syncFromFirebaseIfNeeded(modelContext: ModelContext, forceRefresh: Bool = false) async {
        // Ne sync que si dernière sync > 5 minutes ou forceRefresh
        if !forceRefresh, let lastSync = lastSyncDate, Date().timeIntervalSince(lastSync) < 300 {
            print(
                "⚠️ [SyncManager] Sync récente, skip (dernière sync il y a \(Int(Date().timeIntervalSince(lastSync)))s)"
            )
            return
        }

        await syncFromFirebase(modelContext: modelContext)
    }

    // MARK: - Retry Failed Syncs

    /// Retenter les synchronisations échouées
    func retryFailedSyncs(modelContext: ModelContext) async {
        guard !syncErrors.isEmpty else { return }

        print("🔄 [SyncManager] Tentative de re-synchronisation de \(syncErrors.count) erreurs...")

        // Extraire les SKUs des erreurs
        let failedSKUs = syncErrors.compactMap { error -> String? in
            guard let range = error.range(of: "pour (.+?):", options: .regularExpression) else {
                return nil
            }
            return String(error[range].dropFirst(5).dropLast(1))
        }

        // Récupérer les items correspondants
        for sku in failedSKUs {
            let predicate = #Predicate<StockItem> { $0.sku == sku }
            let fetchDescriptor = FetchDescriptor(predicate: predicate)

            if let items = try? modelContext.fetch(fetchDescriptor),
                let item = items.first
            {
                await syncStockItemToFirebase(item)
            }
        }
    }

    // MARK: - Recalcul des quantités
    
    /// Recalculer les quantités d'un StockItem basées sur les assets réels
    func recalculateStockItemQuantities(stockItem: StockItem, assets: [Asset], modelContext: ModelContext) async {
        let filteredAssets = assets.filter { $0.sku == stockItem.sku }
        
        // Recalculer les quantités basées sur le statut réel des assets
        let totalCount = filteredAssets.count
        let maintenanceCount = filteredAssets.filter { $0.status == .maintenance }.count
        
        // Mettre à jour le StockItem si les valeurs ont changé
        if stockItem.totalQuantity != totalCount || stockItem.maintenanceQuantity != maintenanceCount {
            stockItem.totalQuantity = totalCount
            stockItem.maintenanceQuantity = maintenanceCount
            stockItem.updatedAt = Date()
            
            // Sauvegarder localement
            try? modelContext.save()
            
            // Synchroniser avec Firebase
            await updateStockItemInFirebase(stockItem)
            
            print("✅ [SyncManager] Quantités recalculées pour \(stockItem.sku): \(totalCount) total, \(maintenanceCount) en maintenance")
        }
    }
    
    // MARK: - Helper Methods

    /// Mettre à jour un StockItem local depuis Firebase
    /// Retourne true si l'item a été mis à jour
    private func updateLocalStockItem(_ item: StockItem, from firestoreItem: FirestoreStockItem)
        -> Bool
    {
        // Ne mettre à jour que si la version Firebase est plus récente
        guard let firestoreUpdatedAt = firestoreItem.updatedAt,
            firestoreUpdatedAt > item.updatedAt
        else {
            return false
        }

        item.name = firestoreItem.name
        item.category = firestoreItem.category
        item.itemDescription = firestoreItem.itemDescription
        item.totalQuantity = firestoreItem.quantity
        item.unitWeight = firestoreItem.itemWeight
        item.unitVolume = firestoreItem.itemVolume
        item.unitValue = firestoreItem.unitPrice
        item.tags = firestoreItem.tags
        item.updatedAt = firestoreUpdatedAt

        print("🔄 [SyncManager] Article local mis à jour depuis Firebase : \(item.sku)")
        return true
    }
    
    // MARK: - Sync Events
    
    private func syncEventsFromFirebase(modelContext: ModelContext) async {
        do {
            let firestoreEvents = try await firebaseService.fetchEvents()
            print("📥 [SyncManager] \(firestoreEvents.count) événements récupérés depuis Firebase")
            
            // Créer un dictionnaire des events locaux par eventId
            let fetchDescriptor = FetchDescriptor<Event>()
            let localEvents = try modelContext.fetch(fetchDescriptor)
            let localEventsDict = Dictionary(uniqueKeysWithValues: localEvents.map { ($0.eventId, $0) })
            
            var eventsCreated = 0
            var eventsUpdated = 0
            var eventsDeleted = 0
            
            // Set des eventIds Firebase
            let firebaseEventIds = Set(firestoreEvents.map { $0["eventId"] as? String ?? "" })
            
            // Synchroniser chaque événement Firebase
            for firestoreEvent in firestoreEvents {
                guard let eventId = firestoreEvent["eventId"] as? String else { continue }
                
                if let existingEvent = localEventsDict[eventId] {
                    // Mettre à jour si Firebase est plus récent
                    if updateLocalEvent(existingEvent, from: firestoreEvent) {
                        eventsUpdated += 1
                    }
                } else {
                    // Créer un nouvel événement local
                    if let newEvent = createEventFromFirestore(firestoreEvent) {
                        modelContext.insert(newEvent)
                        eventsCreated += 1
                    }
                }
            }
            
            // Supprimer les events locaux qui n'existent plus dans Firebase
            for localEvent in localEvents {
                if !firebaseEventIds.contains(localEvent.eventId) {
                    print("🗑️ [SyncManager] Suppression de l'événement local orphelin : \(localEvent.name)")
                    modelContext.delete(localEvent)
                    eventsDeleted += 1
                }
            }
            
            try modelContext.save()
            print("✅ [SyncManager] Events synchronisés : \(eventsCreated) créés, \(eventsUpdated) mis à jour, \(eventsDeleted) supprimés")
            
        } catch {
            print("❌ [SyncManager] Erreur sync events: \(error.localizedDescription)")
            syncErrors.append("Erreur sync événements: \(error.localizedDescription)")
        }
    }
    
    private func createEventFromFirestore(_ data: [String: Any]) -> Event? {
        guard let eventId = data["eventId"] as? String,
              let name = data["name"] as? String else {
            return nil
        }
        
        let event = Event(
            eventId: eventId,
            name: name,
            clientName: data["clientName"] as? String ?? "",
            clientPhone: data["clientPhone"] as? String ?? "",
            clientEmail: data["clientEmail"] as? String ?? "",
            clientAddress: data["clientAddress"] as? String ?? "",
            eventAddress: data["eventAddress"] as? String ?? "",
            setupStartTime: (data["setupStartTime"] as? Date) ?? Date(),
            startDate: (data["startDate"] as? Date) ?? Date(),
            endDate: (data["endDate"] as? Date) ?? Date(),
            status: EventStatus(rawValue: data["status"] as? String ?? "PLANIFICATION") ?? .planning,
            notes: data["notes"] as? String ?? "",
            assignedTruckId: data["assignedTruckId"] as? String
        )
        
        return event
    }
    
    private func updateLocalEvent(_ event: Event, from data: [String: Any]) -> Bool {
        guard let updatedAt = data["updatedAt"] as? Date,
              updatedAt > event.updatedAt else {
            return false
        }
        
        event.name = data["name"] as? String ?? event.name
        event.clientName = data["clientName"] as? String ?? ""
        event.clientPhone = data["clientPhone"] as? String ?? ""
        event.clientEmail = data["clientEmail"] as? String ?? ""
        event.clientAddress = data["clientAddress"] as? String ?? ""
        event.eventAddress = data["eventAddress"] as? String ?? ""
        event.notes = data["notes"] as? String ?? ""
        
        if let setupStartTime = data["setupStartTime"] as? Date {
            event.setupStartTime = setupStartTime
        }
        if let startDate = data["startDate"] as? Date {
            event.startDate = startDate
        }
        if let endDate = data["endDate"] as? Date {
            event.endDate = endDate
        }
        if let statusStr = data["status"] as? String,
           let status = EventStatus(rawValue: statusStr) {
            event.status = status
        }
        
        event.assignedTruckId = data["assignedTruckId"] as? String
        event.updatedAt = updatedAt
        
        print("🔄 [SyncManager] Événement local mis à jour : \(event.name)")
        return true
    }
    
    // MARK: - Sync Trucks
    
    private func syncTrucksFromFirebase(modelContext: ModelContext) async {
        do {
            let firestoreTrucks = try await firebaseService.fetchTrucks()
            print("📥 [SyncManager] \(firestoreTrucks.count) camions récupérés depuis Firebase")
            
            // Créer un dictionnaire des trucks locaux par truckId
            let fetchDescriptor = FetchDescriptor<Truck>()
            let localTrucks = try modelContext.fetch(fetchDescriptor)
            let localTrucksDict = Dictionary(uniqueKeysWithValues: localTrucks.map { ($0.truckId, $0) })
            
            var trucksCreated = 0
            var trucksUpdated = 0
            var trucksDeleted = 0
            
            // Set des truckIds Firebase
            let firebaseTruckIds = Set(firestoreTrucks.map { $0["truckId"] as? String ?? "" })
            
            // Synchroniser chaque camion Firebase
            for firestoreTruck in firestoreTrucks {
                guard let truckId = firestoreTruck["truckId"] as? String else { continue }
                
                if let existingTruck = localTrucksDict[truckId] {
                    // Mettre à jour si Firebase est plus récent
                    if updateLocalTruck(existingTruck, from: firestoreTruck) {
                        trucksUpdated += 1
                    }
                } else {
                    // Créer un nouveau camion local
                    if let newTruck = createTruckFromFirestore(firestoreTruck) {
                        modelContext.insert(newTruck)
                        trucksCreated += 1
                    }
                }
            }
            
            // Supprimer les trucks locaux qui n'existent plus dans Firebase
            for localTruck in localTrucks {
                if !firebaseTruckIds.contains(localTruck.truckId) {
                    print("🗑️ [SyncManager] Suppression du camion local orphelin : \(localTruck.licensePlate)")
                    modelContext.delete(localTruck)
                    trucksDeleted += 1
                }
            }
            
            try modelContext.save()
            print("✅ [SyncManager] Trucks synchronisés : \(trucksCreated) créés, \(trucksUpdated) mis à jour, \(trucksDeleted) supprimés")
            
        } catch {
            print("❌ [SyncManager] Erreur sync trucks: \(error.localizedDescription)")
            syncErrors.append("Erreur sync camions: \(error.localizedDescription)")
        }
    }
    
    private func createTruckFromFirestore(_ data: [String: Any]) -> Truck? {
        guard let truckId = data["truckId"] as? String,
              let licensePlate = data["licensePlate"] as? String else {
            return nil
        }
        
        let truck = Truck(
            truckId: truckId,
            licensePlate: licensePlate,
            maxVolume: data["maxVolume"] as? Double ?? 0.0,
            maxWeight: data["maxWeight"] as? Double ?? 0.0,
            status: TruckStatus(rawValue: data["status"] as? String ?? "DISPONIBLE") ?? .available,
            currentDriverId: data["currentDriverId"] as? String,
            currentLocationId: data["currentLocationId"] as? String
        )
        
        // Gérer le nom optionnel
        if let name = data["name"] as? String {
            truck.name = name
        }
        
        return truck
    }
    
    private func updateLocalTruck(_ truck: Truck, from data: [String: Any]) -> Bool {
        guard let updatedAt = data["updatedAt"] as? Date,
              updatedAt > truck.updatedAt else {
            return false
        }
        
        truck.licensePlate = data["licensePlate"] as? String ?? truck.licensePlate
        truck.name = data["name"] as? String
        truck.maxVolume = data["maxVolume"] as? Double ?? truck.maxVolume
        truck.maxWeight = data["maxWeight"] as? Double ?? truck.maxWeight
        
        if let statusStr = data["status"] as? String,
           let status = TruckStatus(rawValue: statusStr) {
            truck.status = status
        }
        
        truck.currentDriverId = data["currentDriverId"] as? String
        truck.currentLocationId = data["currentLocationId"] as? String
        truck.updatedAt = updatedAt
        
        print("🔄 [SyncManager] Camion local mis à jour : \(truck.displayName)")
        return true
    }
}

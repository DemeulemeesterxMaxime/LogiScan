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
            let errorMsg = "❌ Erreur sync Firebase pour \(stockItem.sku): \(error.localizedDescription)"
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
            let errorMsg = "❌ Erreur mise à jour Firebase pour \(stockItem.sku): \(error.localizedDescription)"
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
            let errorMsg = "❌ Erreur suppression Firebase pour \(sku): \(error.localizedDescription)"
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
                    print("🗑️ [SyncManager] Suppression de l'article local orphelin : \(localItem.sku)")
                    modelContext.delete(localItem)
                    itemsDeleted += 1
                }
            }
            
            try modelContext.save()
            lastSyncDate = Date()
            
            print("✅ [SyncManager] Synchronisation terminée : \(itemsCreated) créés, \(itemsUpdated) mis à jour, \(itemsDeleted) supprimés")
            
        } catch {
            let errorMsg = "❌ Erreur synchronisation depuis Firebase: \(error.localizedDescription)"
            print(errorMsg)
            syncErrors.append(errorMsg)
        }
    }
    
    /// Synchronisation rapide (uniquement si pas de sync récente)
    func syncFromFirebaseIfNeeded(modelContext: ModelContext, forceRefresh: Bool = false) async {
        // Ne sync que si dernière sync > 5 minutes ou forceRefresh
        if !forceRefresh, let lastSync = lastSyncDate, Date().timeIntervalSince(lastSync) < 300 {
            print("⚠️ [SyncManager] Sync récente, skip (dernière sync il y a \(Int(Date().timeIntervalSince(lastSync)))s)")
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
               let item = items.first {
                await syncStockItemToFirebase(item)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Mettre à jour un StockItem local depuis Firebase
    /// Retourne true si l'item a été mis à jour
    private func updateLocalStockItem(_ item: StockItem, from firestoreItem: FirestoreStockItem) -> Bool {
        // Ne mettre à jour que si la version Firebase est plus récente
        guard let firestoreUpdatedAt = firestoreItem.updatedAt,
              firestoreUpdatedAt > item.updatedAt else {
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
}


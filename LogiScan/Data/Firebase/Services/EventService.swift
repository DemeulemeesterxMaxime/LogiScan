//
//  EventService.swift
//  LogiScan
//
//  Created by Demeulemeester on 14/10/2025.
//

import Foundation
import FirebaseFirestore
import SwiftData

/// Service dédié à la gestion des événements et devis
@MainActor
final class EventService: ObservableObject {
    private let db = Firestore.firestore()
    private let firebaseService = FirebaseService()
    
    // MARK: - Sauvegarde complète d'un événement avec ses items
    
    /// Sauvegarde un événement et tous ses quote items dans Firebase
    /// - Parameters:
    ///   - event: L'événement à sauvegarder
    ///   - quoteItems: Les items du devis
    ///   - modelContext: Le contexte SwiftData pour la sauvegarde locale
    func saveEventWithQuoteItems(
        event: Event,
        quoteItems: [QuoteItem],
        modelContext: ModelContext
    ) async throws {
        print("💾 [EventService] Sauvegarde de l'événement: \(event.name)")
        
        // 1. Sauvegarder localement d'abord
        try await saveLocally(event: event, quoteItems: quoteItems, modelContext: modelContext)
        
        // 2. Synchroniser avec Firebase
        try await syncToFirebase(event: event, quoteItems: quoteItems)
        
        print("✅ [EventService] Événement sauvegardé avec succès")
    }
    
    // MARK: - Sauvegarde locale
    
    private func saveLocally(
        event: Event,
        quoteItems: [QuoteItem],
        modelContext: ModelContext
    ) async throws {
        print("💾 [EventService] Sauvegarde locale...")
        
        // IMPORTANT: Créer des copies des données AVANT toute manipulation
        // pour éviter les conflits avec les objets SwiftData existants
        let itemsData: [(id: String, eventId: String, sku: String, name: String, category: String, quantity: Int, unitPrice: Double, customPrice: Double, assignedAssets: [String])] = quoteItems.map { item in
            (
                id: item.quoteItemId,
                eventId: item.eventId,
                sku: item.sku,
                name: item.name,
                category: item.category,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                customPrice: item.customPrice,
                assignedAssets: item.assignedAssets
            )
        }
        
        // Récupérer tous les items existants pour cet événement
        let eventId = event.eventId
        let descriptor = FetchDescriptor<QuoteItem>(
            predicate: #Predicate<QuoteItem> { item in
                item.eventId == eventId
            }
        )
        let existingItems = try modelContext.fetch(descriptor)
        
        // Supprimer les anciens items
        for oldItem in existingItems {
            modelContext.delete(oldItem)
        }
        print("🗑️ [EventService] \(existingItems.count) anciens items supprimés")
        
        // Insérer les nouveaux items à partir des copies sûres
        for itemData in itemsData {
            let newItem = QuoteItem(
                quoteItemId: itemData.id,
                eventId: itemData.eventId,
                sku: itemData.sku,
                name: itemData.name,
                category: itemData.category,
                quantity: itemData.quantity,
                unitPrice: itemData.unitPrice
            )
            newItem.customPrice = itemData.customPrice
            newItem.assignedAssets = itemData.assignedAssets
            modelContext.insert(newItem)
        }
        print("➕ [EventService] \(itemsData.count) nouveaux items insérés")
        
        // Mettre à jour la date de modification de l'événement
        event.updatedAt = Date()
        
        // Sauvegarder
        try modelContext.save()
        print("✅ [EventService] Sauvegarde locale réussie")
    }
    
    // MARK: - Synchronisation Firebase
    
    private func syncToFirebase(
        event: Event,
        quoteItems: [QuoteItem]
    ) async throws {
        print("☁️ [EventService] Synchronisation Firebase...")
        
        do {
            // 1. Synchroniser l'événement
            print("📤 [EventService] Envoi de l'événement...")
            let firestoreEvent = event.toFirestoreEvent()
            try await firebaseService.updateEvent(firestoreEvent)
            print("✅ [EventService] Événement synchronisé")
            
            // 2. Supprimer les anciens items Firebase
            print("🔍 [EventService] Vérification des items existants...")
            let oldItems = try await firebaseService.fetchQuoteItems(forEvent: event.eventId)
            
            if !oldItems.isEmpty {
                print("🗑️ [EventService] Suppression de \(oldItems.count) anciens items...")
                for oldItem in oldItems {
                    try await firebaseService.deleteQuoteItem(
                        quoteItemId: oldItem.quoteItemId,
                        forEvent: event.eventId
                    )
                }
                print("✅ [EventService] Anciens items supprimés")
            }
            
            // 3. Créer les nouveaux items
            print("📤 [EventService] Création de \(quoteItems.count) items...")
            for (index, item) in quoteItems.enumerated() {
                let firestoreItem = item.toFirestoreQuoteItem()
                try await firebaseService.createQuoteItem(firestoreItem, forEvent: event.eventId)
                print("  ✓ Item \(index + 1)/\(quoteItems.count): \(item.name)")
            }
            print("✅ [EventService] Items synchronisés")
            
        } catch {
            print("❌ [EventService] Erreur Firebase: \(error.localizedDescription)")
            throw EventServiceError.firebaseSyncFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Chargement
    
    /// Charge un événement avec ses quote items depuis Firebase
    func loadEventWithQuoteItems(eventId: String) async throws -> (Event, [QuoteItem]) {
        print("📥 [EventService] Chargement de l'événement: \(eventId)")
        
        // Récupérer l'événement
        // TODO: Implémenter fetchEvent dans FirebaseService si nécessaire
        
        // Récupérer les items
        let firestoreItems = try await firebaseService.fetchQuoteItems(forEvent: eventId)
        let quoteItems = firestoreItems.map { $0.toQuoteItem() }
        
        print("✅ [EventService] Événement chargé avec \(quoteItems.count) items")
        
        // Note: Pour le moment, on retourne juste les items
        // L'événement doit être chargé depuis SwiftData
        fatalError("À implémenter complètement")
    }
    
    // MARK: - Suppression
    
    /// Supprime un événement et tous ses items de Firebase
    func deleteEvent(eventId: String) async throws {
        print("🗑️ [EventService] Suppression de l'événement: \(eventId)")
        
        // Supprimer les items d'abord
        let items = try await firebaseService.fetchQuoteItems(forEvent: eventId)
        for item in items {
            try await firebaseService.deleteQuoteItem(
                quoteItemId: item.quoteItemId,
                forEvent: eventId
            )
        }
        
        // Supprimer l'événement
        // TODO: Implémenter deleteEvent dans FirebaseService si nécessaire
        
        print("✅ [EventService] Événement supprimé")
    }
}

// MARK: - Erreurs

enum EventServiceError: LocalizedError {
    case firebaseSyncFailed(String)
    case localSaveFailed(String)
    case notFound(String)
    
    var errorDescription: String? {
        switch self {
        case .firebaseSyncFailed(let message):
            return "Erreur de synchronisation Firebase: \(message)"
        case .localSaveFailed(let message):
            return "Erreur de sauvegarde locale: \(message)"
        case .notFound(let id):
            return "Événement non trouvé: \(id)"
        }
    }
}

//
//  QuoteStatusSyncService.swift
//  LogiScan
//
//  Created by Assistant on 27/10/2025.
//

import Foundation
import SwiftData

@MainActor
class QuoteStatusSyncService: ObservableObject {
    private let versionService = QuoteVersionService()
    
    /// Synchronise le statut d'un événement basé sur l'existence de versions
    func syncEventQuoteStatus(event: Event, modelContext: ModelContext) async {
        do {
            // Vérifier si des versions existent dans Firestore
            let hasVersions = try await versionService.hasFinalizedVersion(for: event.eventId)
            
            // Si des versions existent mais que le statut local est "draft"
            // alors synchroniser le statut
            if hasVersions && event.quoteStatus == .draft {
                print("🔄 [QuoteStatusSync] Synchronisation statut pour: \(event.name)")
                event.quoteStatus = .finalized
                event.updatedAt = Date()
                
                try modelContext.save()
                print("✅ [QuoteStatusSync] Statut synchronisé: finalized")
            } else if !hasVersions && event.quoteStatus != .draft {
                // Si aucune version n'existe mais que le statut est finalisé
                // (cas rare, mais possible si les données Firestore ont été supprimées)
                print("⚠️ [QuoteStatusSync] Incohérence détectée: pas de version mais statut = \(event.quoteStatus.rawValue)")
                // On ne change pas automatiquement le statut pour éviter les pertes de données
                // L'utilisateur devra refinaliser le devis
            }
        } catch {
            print("❌ [QuoteStatusSync] Erreur: \(error.localizedDescription)")
        }
    }
    
    /// Synchronise tous les événements au démarrage de l'app
    func syncAllEvents(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Event>()
        
        do {
            let events = try modelContext.fetch(descriptor)
            print("🔄 [QuoteStatusSync] Synchronisation de \(events.count) événements...")
            
            for event in events {
                await syncEventQuoteStatus(event: event, modelContext: modelContext)
            }
            
            print("✅ [QuoteStatusSync] Synchronisation terminée")
        } catch {
            print("❌ [QuoteStatusSync] Erreur fetch events: \(error.localizedDescription)")
        }
    }
}

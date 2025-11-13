//
//  InventorySessionService.swift
//  LogiScan
//
//  Created by Assistant on 13/11/2025.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Service pour gérer les sessions d'inventaire
@MainActor
class InventorySessionService: ObservableObject {
    private let db = Firestore.firestore()
    
    /// Crée une nouvelle session d'inventaire
    func createSession(
        createdBy: String,
        notes: String? = nil,
        modelContext: ModelContext
    ) -> InventorySession {
        let session = InventorySession(createdBy: createdBy, notes: notes)
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            print("✅ [InventorySession] Session créée: \(session.sessionId)")
        } catch {
            print("❌ [InventorySession] Erreur création: \(error)")
        }
        
        return session
    }
    
    /// Ajoute un asset à la session et sauvegarde
    func addAssetToSession(
        session: InventorySession,
        assetId: String,
        modelContext: ModelContext
    ) async throws {
        session.addAsset(assetId)
        
        // Sauvegarder localement
        try modelContext.save()
        print("✅ [InventorySession] Asset ajouté: \(assetId) (\(session.totalCount) total)")
        
        // Sauvegarder dans Firebase (asynchrone)
        try await syncSessionToFirebase(session)
    }
    
    /// Complète une session et la sauvegarde
    func completeSession(
        session: InventorySession,
        modelContext: ModelContext
    ) async throws {
        session.complete()
        
        // Sauvegarder localement
        try modelContext.save()
        print("✅ [InventorySession] Session complétée: \(session.sessionId)")
        
        // Sauvegarder dans Firebase
        try await syncSessionToFirebase(session)
    }
    
    /// Récupère toutes les sessions
    func fetchSessions(modelContext: ModelContext) throws -> [InventorySession] {
        let descriptor = FetchDescriptor<InventorySession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Récupère la session active (non complétée la plus récente)
    func fetchActiveSession(modelContext: ModelContext) throws -> InventorySession? {
        let descriptor = FetchDescriptor<InventorySession>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let sessions = try modelContext.fetch(descriptor)
        return sessions.first
    }
    
    /// Synchronise une session vers Firebase
    private func syncSessionToFirebase(_ session: InventorySession) async throws {
        let data: [String: Any] = [
            "sessionId": session.sessionId,
            "createdAt": Timestamp(date: session.createdAt),
            "completedAt": session.completedAt != nil ? Timestamp(date: session.completedAt!) : NSNull(),
            "createdBy": session.createdBy,
            "notes": session.notes ?? "",
            "scannedAssetIds": session.scannedAssetIds,
            "totalCount": session.totalCount,
            "isCompleted": session.isCompleted,
            "updatedAt": Timestamp(date: Date())
        ]
        
        try await db.collection("inventorySessions")
            .document(session.sessionId)
            .setData(data, merge: true)
        
        print("☁️ [InventorySession] Synchronisé vers Firebase: \(session.sessionId)")
    }
    
    /// Exporte une session en CSV
    func exportToCSV(session: InventorySession, assets: [Asset]) -> String {
        var csv = "Asset ID,SKU,Nom,Catégorie,Statut,Scanned At\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for assetId in session.scannedAssetIds {
            if let asset = assets.first(where: { $0.assetId == assetId }) {
                let line = "\"\(asset.assetId)\",\"\(asset.sku)\",\"\(asset.name)\",\"\(asset.category)\",\"\(asset.status.rawValue)\",\"\(dateFormatter.string(from: session.createdAt))\"\n"
                csv += line
            }
        }
        
        return csv
    }
}

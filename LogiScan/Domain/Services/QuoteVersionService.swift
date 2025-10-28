//
//  QuoteVersionService.swift
//  LogiScan
//
//  Created by Assistant on 27/10/2025.
//

import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseStorage

@MainActor
class QuoteVersionService: ObservableObject {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - Créer une nouvelle version
    
    /// Crée une nouvelle version du devis et upload le PDF
    func createVersion(
        event: Event,
        quoteItems: [QuoteItem],
        pdfData: Data,
        createdBy: String,
        createdByName: String,
        modelContext: ModelContext
    ) async throws -> QuoteVersion {
        
        print("📄 [QuoteVersionService] Création d'une nouvelle version pour l'événement: \(event.name)")
        
        // 1. Récupérer le numéro de la prochaine version
        let nextVersionNumber = try await getNextVersionNumber(for: event.eventId)
        
        // 2. Créer le chemin de stockage
        let storagePath = "quotes/\(event.eventId)/versions/v\(nextVersionNumber).pdf"
        
        // 3. Upload du PDF vers Firebase Storage
        let pdfUrl = try await uploadPDF(data: pdfData, to: storagePath)
        
        print("✅ [QuoteVersionService] PDF uploadé: \(pdfUrl)")
        
        // 4. Créer l'objet QuoteVersion
        let version = QuoteVersion(
            eventId: event.eventId,
            versionNumber: nextVersionNumber,
            createdBy: createdBy,
            createdByName: createdByName,
            pdfStoragePath: storagePath,
            pdfUrl: pdfUrl,
            totalAmount: event.totalAmount,
            finalAmount: event.finalAmount,
            discountPercent: event.discountPercent,
            deliveryFee: event.deliveryFee,
            assemblyFee: event.assemblyFee,
            disassemblyFee: event.disassemblyFee,
            tvaRate: event.tvaRate,
            status: "finalized"
        )
        
        // 5. Sauvegarder dans SwiftData
        modelContext.insert(version)
        try modelContext.save()
        
        // 6. Sauvegarder dans Firestore avec le snapshot des items
        try await saveVersionToFirestore(version: version, quoteItems: quoteItems)
        
        print("✅ [QuoteVersionService] Version \(nextVersionNumber) créée avec succès")
        
        return version
    }
    
    // MARK: - Récupération des versions
    
    /// Récupère toutes les versions d'un événement
    func fetchVersions(for eventId: String) async throws -> [FirestoreQuoteVersion] {
        let snapshot = try await db.collection("events")
            .document(eventId)
            .collection("quoteVersions")
            .order(by: "versionNumber", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestoreQuoteVersion.self)
        }
    }
    
    /// Récupère la dernière version d'un événement
    func fetchLatestVersion(for eventId: String) async throws -> FirestoreQuoteVersion? {
        let snapshot = try await db.collection("events")
            .document(eventId)
            .collection("quoteVersions")
            .order(by: "versionNumber", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else { return nil }
        return try? doc.data(as: FirestoreQuoteVersion.self)
    }
    
    /// Vérifie si un événement a au moins une version finalisée
    func hasFinalizedVersion(for eventId: String) async throws -> Bool {
        let versions = try await fetchVersions(for: eventId)
        return !versions.isEmpty
    }
    
    // MARK: - Gestion du PDF
    
    /// Upload un PDF vers Firebase Storage
    private func uploadPDF(data: Data, to path: String) async throws -> String {
        let storageRef = storage.reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"
        
        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        
        // Récupérer l'URL de téléchargement
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    /// Télécharge un PDF depuis Firebase Storage
    func downloadPDF(from storagePath: String) async throws -> Data {
        let storageRef = storage.reference().child(storagePath)
        let data = try await storageRef.data(maxSize: 10 * 1024 * 1024) // 10MB max
        return data
    }
    
    /// Télécharge un PDF depuis une URL
    func downloadPDFFromURL(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "QuoteVersionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL invalide"])
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    // MARK: - Helpers
    
    /// Récupère le prochain numéro de version
    private func getNextVersionNumber(for eventId: String) async throws -> Int {
        let versions = try await fetchVersions(for: eventId)
        
        if versions.isEmpty {
            return 1
        }
        
        let maxVersion = versions.map { $0.versionNumber }.max() ?? 0
        return maxVersion + 1
    }
    
    /// Sauvegarde une version dans Firestore
    private func saveVersionToFirestore(version: QuoteVersion, quoteItems: [QuoteItem]) async throws {
        let firestoreVersion = version.toFirestore(quoteItems: quoteItems)
        
        try db.collection("events")
            .document(version.eventId)
            .collection("quoteVersions")
            .document(version.versionId)
            .setData(from: firestoreVersion)
        
        print("✅ [QuoteVersionService] Version sauvegardée dans Firestore")
    }
    
    // MARK: - Suppression
    
    /// Supprime une version (PDF + Firestore)
    func deleteVersion(_ version: QuoteVersion) async throws {
        // 1. Supprimer le PDF du Storage
        let storageRef = storage.reference().child(version.pdfStoragePath)
        try await storageRef.delete()
        
        // 2. Supprimer de Firestore
        try await db.collection("events")
            .document(version.eventId)
            .collection("quoteVersions")
            .document(version.versionId)
            .delete()
        
        print("✅ [QuoteVersionService] Version \(version.versionNumber) supprimée")
    }
}

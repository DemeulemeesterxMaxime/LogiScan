//
//  FirebaseService.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import Combine
import FirebaseFirestore
import Foundation

/// Service principal pour interagir avec Firestore
@MainActor
class FirebaseService: ObservableObject {
    private let db = Firestore.firestore()
    private var organizationId: String = "default-org"  // TODO: À récupérer depuis le profil utilisateur

    // MARK: - Collections References

    private var stockItemsRef: CollectionReference {
        db.collection("organizations/\(organizationId)/stockItems")
    }

    private func assetsRef(stockSku: String) -> CollectionReference {
        stockItemsRef.document(stockSku).collection("assets")
    }

    private var movementsRef: CollectionReference {
        db.collection("organizations/\(organizationId)/movements")
    }

    private var locationsRef: CollectionReference {
        db.collection("organizations/\(organizationId)/locations")
    }

    private var trucksRef: CollectionReference {
        db.collection("organizations/\(organizationId)/trucks")
    }

    // MARK: - Stock Items

    /// Récupérer tous les StockItems
    func fetchStockItems() async throws -> [FirestoreStockItem] {
        let snapshot =
            try await stockItemsRef
            .order(by: "name")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestoreStockItem.self)
        }
    }

    /// Écouter les changements en temps réel
    func observeStockItems() -> AsyncStream<[FirestoreStockItem]> {
        AsyncStream { continuation in
            let listener =
                stockItemsRef
                .order(by: "name")
                .addSnapshotListener { snapshot, error in
                    guard let snapshot = snapshot else {
                        if let error = error {
                            print("❌ Erreur observeStockItems: \(error)")
                        }
                        continuation.finish()
                        return
                    }

                    let items = snapshot.documents.compactMap { doc in
                        try? doc.data(as: FirestoreStockItem.self)
                    }
                    continuation.yield(items)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    /// Créer un nouveau StockItem
    func createStockItem(_ item: FirestoreStockItem) async throws {
        try stockItemsRef.document(item.sku).setData(from: item)
        print("✅ StockItem créé : \(item.sku)")
    }

    /// Mettre à jour un StockItem
    func updateStockItem(_ item: FirestoreStockItem) async throws {
        try stockItemsRef.document(item.sku).setData(from: item, merge: true)
        print("✅ StockItem mis à jour : \(item.sku)")
    }

    /// Supprimer un StockItem
    func deleteStockItem(sku: String) async throws {
        try await stockItemsRef.document(sku).delete()
        print("✅ StockItem supprimé : \(sku)")
    }

    /// Rechercher des StockItems par catégorie
    func fetchStockItems(byCategory category: String) async throws -> [FirestoreStockItem] {
        let snapshot =
            try await stockItemsRef
            .whereField("category", isEqualTo: category)
            .order(by: "name")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestoreStockItem.self)
        }
    }

    // MARK: - Assets (Références sérialisées)

    /// Récupérer tous les assets d'un StockItem
    func fetchAssets(forStock sku: String) async throws -> [FirestoreAsset] {
        let snapshot = try await assetsRef(stockSku: sku)
            .order(by: "assetId")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestoreAsset.self)
        }
    }

    /// Écouter les assets en temps réel
    func observeAssets(forStock sku: String) -> AsyncStream<[FirestoreAsset]> {
        AsyncStream { continuation in
            let listener = assetsRef(stockSku: sku)
                .order(by: "assetId")
                .addSnapshotListener { snapshot, error in
                    guard let snapshot = snapshot else {
                        if let error = error {
                            print("❌ Erreur observeAssets: \(error)")
                        }
                        continuation.finish()
                        return
                    }

                    let assets = snapshot.documents.compactMap { doc in
                        try? doc.data(as: FirestoreAsset.self)
                    }
                    continuation.yield(assets)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    /// Créer un nouvel Asset
    func createAsset(_ asset: FirestoreAsset, forStock sku: String) async throws {
        try assetsRef(stockSku: sku).document(asset.assetId).setData(from: asset)
        print("✅ Asset créé : \(asset.assetId)")
    }

    /// Mettre à jour le statut d'un Asset (après scan QR)
    func updateAssetStatus(assetId: String, stockSku: String, newStatus: String, location: String?)
        async throws
    {
        try await assetsRef(stockSku: stockSku).document(assetId).updateData([
            "status": newStatus,
            "currentLocationId": location ?? "",
            "lastScannedAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
        ])
        print("✅ Asset statut mis à jour : \(assetId) -> \(newStatus)")
    }

    /// Supprimer un Asset
    func deleteAsset(assetId: String, stockSku: String) async throws {
        try await assetsRef(stockSku: stockSku).document(assetId).delete()
        print("✅ Asset supprimé : \(assetId)")
    }

    // MARK: - Movements (Historique)

    /// Enregistrer un mouvement après scan
    func recordMovement(movement: FirestoreMovement) async throws {
        try movementsRef.addDocument(from: movement)
        print("✅ Mouvement enregistré : \(movement.sku)")
    }

    /// Récupérer l'historique des mouvements
    func fetchMovements(limit: Int = 50) async throws -> [FirestoreMovement] {
        let snapshot =
            try await movementsRef
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestoreMovement.self)
        }
    }

    /// Écouter les mouvements en temps réel
    func observeMovements(limit: Int = 50) -> AsyncStream<[FirestoreMovement]> {
        AsyncStream { continuation in
            let listener =
                movementsRef
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
                .addSnapshotListener { snapshot, error in
                    guard let snapshot = snapshot else {
                        if let error = error {
                            print("❌ Erreur observeMovements: \(error)")
                        }
                        continuation.finish()
                        return
                    }

                    let movements = snapshot.documents.compactMap { doc in
                        try? doc.data(as: FirestoreMovement.self)
                    }
                    continuation.yield(movements)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    // MARK: - Locations

    /// Récupérer toutes les locations
    func fetchLocations() async throws -> [FirestoreLocation] {
        let snapshot =
            try await locationsRef
            .order(by: "name")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestoreLocation.self)
        }
    }

    /// Créer une nouvelle location
    func createLocation(_ location: FirestoreLocation) async throws {
        try locationsRef.document(location.locationId).setData(from: location)
        print("✅ Location créée : \(location.name)")
    }

    // MARK: - Recherche

    /// Rechercher un asset par QR scan
    func findAssetByQRPayload(_ payload: String) async throws -> FirestoreAsset? {
        // Parser le JSON du QR
        guard let data = payload.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let assetId = json["assetId"] as? String,
            let sku = json["stockSku"] as? String
        else {
            print("❌ QR payload invalide")
            return nil
        }

        let doc = try await assetsRef(stockSku: sku).document(assetId).getDocument()
        return try? doc.data(as: FirestoreAsset.self)
    }

    /// Rechercher un stock item par QR scan
    func findStockItemByQRPayload(_ payload: String) async throws -> FirestoreStockItem? {
        // Parser le JSON du QR
        guard let data = payload.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sku = json["sku"] as? String
        else {
            print("❌ QR payload invalide")
            return nil
        }

        let doc = try await stockItemsRef.document(sku).getDocument()
        return try? doc.data(as: FirestoreStockItem.self)
    }

    // MARK: - Batch Operations

    /// Créer plusieurs assets en une seule transaction
    func createAssetsBatch(_ assets: [FirestoreAsset], forStock sku: String) async throws {
        let batch = db.batch()

        for asset in assets {
            let docRef = assetsRef(stockSku: sku).document(asset.assetId)
            try batch.setData(from: asset, forDocument: docRef)
        }

        try await batch.commit()
        print("✅ Batch de \(assets.count) assets créés")
    }
}

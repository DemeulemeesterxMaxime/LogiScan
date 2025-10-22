//
//  FirebaseService.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import Combine
import FirebaseFirestore
import FirebaseAuth
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
        db.collection("trucks")
    }

    private var eventsRef: CollectionReference {
        db.collection("events")
    }
    
    private func quoteItemsRef(eventId: String) -> CollectionReference {
        eventsRef.document(eventId).collection("quoteItems")
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
        var updateData: [String: Any] = [
            "status": newStatus,
            "lastScannedAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
        ]

        // Ajouter currentLocationId seulement si location n'est pas nil
        if let location = location {
            updateData["currentLocationId"] = location
        }

        try await assetsRef(stockSku: stockSku).document(assetId).updateData(updateData)
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

    // MARK: - Trucks

    /// Sauvegarder un camion
    func saveTruck(_ truck: Truck) async {
        do {
            let data: [String: Any] = [
                "truckId": truck.truckId,
                "licensePlate": truck.licensePlate,
                "name": truck.name as Any,
                "maxVolume": truck.maxVolume,
                "maxWeight": truck.maxWeight,
                "status": truck.status.rawValue,
                "currentDriverId": truck.currentDriverId as Any,
                "createdAt": Timestamp(date: truck.createdAt),
                "updatedAt": Timestamp(date: truck.updatedAt),
            ]
            try await trucksRef.document(truck.truckId).setData(data)
            print("✅ Camion sauvegardé dans Firebase: \(truck.displayName)")
        } catch {
            print("❌ Erreur sauvegarde camion Firebase: \(error)")
        }
    }

    /// Mettre à jour un camion
    func updateTruck(_ truck: Truck) async {
        do {
            let data: [String: Any] = [
                "licensePlate": truck.licensePlate,
                "name": truck.name as Any,
                "maxVolume": truck.maxVolume,
                "maxWeight": truck.maxWeight,
                "status": truck.status.rawValue,
                "currentDriverId": truck.currentDriverId as Any,
                "updatedAt": Timestamp(date: truck.updatedAt),
            ]
            try await trucksRef.document(truck.truckId).setData(data, merge: true)
            print("✅ Camion mis à jour dans Firebase: \(truck.displayName)")
        } catch {
            print("❌ Erreur mise à jour camion Firebase: \(error)")
        }
    }
    
    /// Supprimer un camion
    func deleteTruck(_ truckId: String) async {
        do {
            try await trucksRef.document(truckId).delete()
            print("✅ Camion supprimé de Firebase: \(truckId)")
        } catch {
            print("❌ Erreur suppression camion Firebase: \(error)")
        }
    }

    // MARK: - Events

    /// Sauvegarder un événement
    func saveEvent(_ event: Event) async {
        do {
            let data: [String: Any] = [
                "eventId": event.eventId,
                "name": event.name,
                "clientName": event.clientName,
                "clientPhone": event.clientPhone,
                "clientEmail": event.clientEmail,
                "clientAddress": event.clientAddress,
                "eventAddress": event.eventAddress,
                "setupStartTime": Timestamp(date: event.setupStartTime),
                "startDate": Timestamp(date: event.startDate),
                "endDate": Timestamp(date: event.endDate),
                "status": event.status.rawValue,
                "assignedTruckId": event.assignedTruckId as Any,
                "notes": event.notes,
                "createdAt": Timestamp(date: event.createdAt),
                "updatedAt": Timestamp(date: event.updatedAt),
            ]
            try await eventsRef.document(event.eventId).setData(data)
            print("✅ Événement sauvegardé dans Firebase: \(event.name)")
        } catch {
            print("❌ Erreur sauvegarde événement Firebase: \(error)")
        }
    }

    /// Mettre à jour un événement
    func updateEvent(_ event: Event) async {
        do {
            let data: [String: Any] = [
                "name": event.name,
                "clientName": event.clientName,
                "clientPhone": event.clientPhone,
                "clientEmail": event.clientEmail,
                "clientAddress": event.clientAddress,
                "eventAddress": event.eventAddress,
                "setupStartTime": Timestamp(date: event.setupStartTime),
                "startDate": Timestamp(date: event.startDate),
                "endDate": Timestamp(date: event.endDate),
                "status": event.status.rawValue,
                "assignedTruckId": event.assignedTruckId as Any,
                "notes": event.notes,
                "updatedAt": Timestamp(date: event.updatedAt),
            ]
            try await eventsRef.document(event.eventId).setData(data, merge: true)
            print("✅ Événement mis à jour dans Firebase: \(event.name)")
        } catch {
            print("❌ Erreur mise à jour événement Firebase: \(error)")
        }
    }
    
    /// Supprimer un événement
    func deleteEvent(_ eventId: String) async {
        do {
            try await eventsRef.document(eventId).delete()
            print("✅ Événement supprimé de Firebase: \(eventId)")
        } catch {
            print("❌ Erreur suppression événement Firebase: \(error)")
        }
    }
    
    /// Récupérer tous les événements
    func fetchEvents() async throws -> [[String: Any]] {
        print("🔥 DEBUG Firebase: Début fetchEvents...")
        print("   User ID: \(Auth.auth().currentUser?.uid ?? "NON AUTHENTIFIÉ")")
        
        let snapshot = try await eventsRef.getDocuments()
        print("   📥 Snapshot reçu: \(snapshot.documents.count) documents")
        
        let results = snapshot.documents.map { doc in
            print("      - Document ID: \(doc.documentID)")
            var data = doc.data()
            // Convertir les Timestamp en Date
            if let setupTimestamp = data["setupStartTime"] as? Timestamp {
                data["setupStartTime"] = setupTimestamp.dateValue()
            }
            if let startTimestamp = data["startDate"] as? Timestamp {
                data["startDate"] = startTimestamp.dateValue()
            }
            if let endTimestamp = data["endDate"] as? Timestamp {
                data["endDate"] = endTimestamp.dateValue()
            }
            if let createdTimestamp = data["createdAt"] as? Timestamp {
                data["createdAt"] = createdTimestamp.dateValue()
            }
            if let updatedTimestamp = data["updatedAt"] as? Timestamp {
                data["updatedAt"] = updatedTimestamp.dateValue()
            }
            return data
        }
        
        print("   ✅ Retour de \(results.count) événements")
        return results
    }
    
    /// Récupérer tous les camions
    func fetchTrucks() async throws -> [[String: Any]] {
        let snapshot = try await trucksRef.getDocuments()
        return snapshot.documents.map { doc in
            var data = doc.data()
            // Convertir les Timestamp en Date
            if let createdTimestamp = data["createdAt"] as? Timestamp {
                data["createdAt"] = createdTimestamp.dateValue()
            }
            if let updatedTimestamp = data["updatedAt"] as? Timestamp {
                data["updatedAt"] = updatedTimestamp.dateValue()
            }
            return data
        }
    }
    
    // MARK: - Events CRUD
    
    /// Créer un nouvel événement
    func createEvent(_ event: FirestoreEvent) async throws {
        let data: [String: Any] = [
            "eventId": event.eventId,
            "name": event.name,
            "clientName": event.clientName,
            "clientPhone": event.clientPhone,
            "clientEmail": event.clientEmail,
            "clientAddress": event.clientAddress,
            "eventAddress": event.eventAddress,
            "setupStartTime": Timestamp(date: event.setupStartTime),
            "startDate": Timestamp(date: event.startDate),
            "endDate": Timestamp(date: event.endDate),
            "status": event.status,
            "notes": event.notes,
            "assignedTruckId": event.assignedTruckId as Any,
            "totalAmount": event.totalAmount,
            "discountPercent": event.discountPercent,
            "finalAmount": event.finalAmount,
            "quoteStatus": event.quoteStatus,
            "paymentStatus": event.paymentStatus,
            "deliveryFee": event.deliveryFee,
            "assemblyFee": event.assemblyFee,
            "disassemblyFee": event.disassemblyFee,
            "tvaRate": event.tvaRate,
            "createdAt": Timestamp(date: event.createdAt),
            "updatedAt": Timestamp(date: event.updatedAt)
        ]
        
        try await eventsRef.document(event.eventId).setData(data)
        print("✅ Événement créé dans Firebase: \(event.eventId)")
    }
    
    /// Mettre à jour un événement existant
    func updateEvent(_ event: FirestoreEvent) async throws {
        let data: [String: Any] = [
            "name": event.name,
            "clientName": event.clientName,
            "clientPhone": event.clientPhone,
            "clientEmail": event.clientEmail,
            "clientAddress": event.clientAddress,
            "eventAddress": event.eventAddress,
            "setupStartTime": Timestamp(date: event.setupStartTime),
            "startDate": Timestamp(date: event.startDate),
            "endDate": Timestamp(date: event.endDate),
            "status": event.status,
            "notes": event.notes,
            "assignedTruckId": event.assignedTruckId as Any,
            "totalAmount": event.totalAmount,
            "discountPercent": event.discountPercent,
            "finalAmount": event.finalAmount,
            "quoteStatus": event.quoteStatus,
            "paymentStatus": event.paymentStatus,
            "deliveryFee": event.deliveryFee,
            "assemblyFee": event.assemblyFee,
            "disassemblyFee": event.disassemblyFee,
            "tvaRate": event.tvaRate,
            "updatedAt": Timestamp(date: Date())
        ]
        
        try await eventsRef.document(event.eventId).updateData(data)
        print("✅ Événement mis à jour dans Firebase: \(event.eventId)")
    }
    
    /// Supprimer un événement
    func deleteEvent(eventId: String) async throws {
        // Supprimer d'abord tous les quote items
        let quoteItemsSnapshot = try await quoteItemsRef(eventId: eventId).getDocuments()
        for doc in quoteItemsSnapshot.documents {
            try await doc.reference.delete()
        }
        
        // Puis supprimer l'événement
        try await eventsRef.document(eventId).delete()
        print("✅ Événement supprimé de Firebase: \(eventId)")
    }
    
    // MARK: - QuoteItems CRUD
    
    /// Créer un nouvel item de devis
    func createQuoteItem(_ quoteItem: FirestoreQuoteItem, forEvent eventId: String) async throws {
        let data: [String: Any] = [
            "quoteItemId": quoteItem.quoteItemId,
            "eventId": quoteItem.eventId,
            "sku": quoteItem.sku,
            "name": quoteItem.name,
            "category": quoteItem.category,
            "quantity": quoteItem.quantity,
            "unitPrice": quoteItem.unitPrice,
            "customPrice": quoteItem.customPrice,
            "totalPrice": quoteItem.totalPrice,
            "assignedAssets": quoteItem.assignedAssets,
            "createdAt": Timestamp(date: quoteItem.createdAt),
            "updatedAt": Timestamp(date: quoteItem.updatedAt)
        ]
        
        try await quoteItemsRef(eventId: eventId).document(quoteItem.quoteItemId).setData(data)
        print("✅ QuoteItem créé dans Firebase: \(quoteItem.quoteItemId)")
    }
    
    /// Mettre à jour un item de devis
    func updateQuoteItem(_ quoteItem: FirestoreQuoteItem, forEvent eventId: String) async throws {
        let data: [String: Any] = [
            "quantity": quoteItem.quantity,
            "customPrice": quoteItem.customPrice,
            "totalPrice": quoteItem.totalPrice,
            "assignedAssets": quoteItem.assignedAssets,
            "updatedAt": Timestamp(date: Date())
        ]
        
        try await quoteItemsRef(eventId: eventId).document(quoteItem.quoteItemId).updateData(data)
        print("✅ QuoteItem mis à jour dans Firebase: \(quoteItem.quoteItemId)")
    }
    
    /// Supprimer un item de devis
    func deleteQuoteItem(quoteItemId: String, forEvent eventId: String) async throws {
        try await quoteItemsRef(eventId: eventId).document(quoteItemId).delete()
        print("✅ QuoteItem supprimé de Firebase: \(quoteItemId)")
    }
    
    /// Récupérer tous les items d'un devis
    func fetchQuoteItems(forEvent eventId: String) async throws -> [FirestoreQuoteItem] {
        let snapshot = try await quoteItemsRef(eventId: eventId).getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            
            return FirestoreQuoteItem(
                quoteItemId: data["quoteItemId"] as? String ?? "",
                eventId: data["eventId"] as? String ?? "",
                sku: data["sku"] as? String ?? "",
                name: data["name"] as? String ?? "",
                category: data["category"] as? String ?? "",
                quantity: data["quantity"] as? Int ?? 0,
                unitPrice: data["unitPrice"] as? Double ?? 0.0,
                customPrice: data["customPrice"] as? Double ?? 0.0,
                totalPrice: data["totalPrice"] as? Double ?? 0.0,
                assignedAssets: data["assignedAssets"] as? [String] ?? [],
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }
    
    // MARK: - Users Management
    
    /// Créer un utilisateur entreprise (admin)
    func createCompanyUser(
        userId: String,
        email: String,
        displayName: String,
        company: Company
    ) async throws {
        let user = User(
            userId: userId,
            email: email,
            displayName: displayName,
            accountType: .company,
            companyId: company.companyId,
            role: .admin
        )
        
        let firestoreUser = user.toFirestoreUser()
        
        try db.collection("users")
            .document(userId)
            .setData(from: firestoreUser)
        
        print("✅ [FirebaseService] Utilisateur entreprise créé: \(displayName)")
    }
    
    /// Créer un utilisateur employé
    func createEmployeeUser(
        userId: String,
        email: String,
        displayName: String,
        companyId: String,
        role: User.UserRole
    ) async throws {
        let user = User(
            userId: userId,
            email: email,
            displayName: displayName,
            accountType: .employee,
            companyId: companyId,
            role: role
        )
        
        let firestoreUser = user.toFirestoreUser()
        
        try db.collection("users")
            .document(userId)
            .setData(from: firestoreUser)
        
        print("✅ [FirebaseService] Utilisateur employé créé: \(displayName)")
    }
    
    /// Récupérer un utilisateur par ID
    func fetchUser(userId: String) async throws -> User {
        let document = try await db.collection("users")
            .document(userId)
            .getDocument()
        
        guard let firestoreUser = try? document.data(as: FirestoreUser.self) else {
            throw FirebaseServiceError.userNotFound
        }
        
        return firestoreUser.toSwiftData()
    }
    
    /// Mettre à jour un utilisateur
    func updateUser(_ user: User) async throws {
        let firestoreUser = user.toFirestoreUser()
        
        try db.collection("users")
            .document(user.userId)
            .setData(from: firestoreUser, merge: true)
        
        print("✅ [FirebaseService] Utilisateur mis à jour: \(user.displayName)")
    }
    
    /// Récupérer les membres d'une entreprise
    func fetchCompanyMembers(companyId: String) async throws -> [User] {
        let snapshot = try await db.collection("users")
            .whereField("companyId", isEqualTo: companyId)
            .getDocuments()
        
        let users = snapshot.documents.compactMap { document -> User? in
            guard let firestoreUser = try? document.data(as: FirestoreUser.self) else {
                return nil
            }
            return firestoreUser.toSwiftData()
        }
        
        print("✅ [FirebaseService] \(users.count) membres récupérés")
        return users
    }
    
    /// Changer le rôle d'un utilisateur
    func updateUserRole(userId: String, newRole: User.UserRole) async throws {
        try await db.collection("users")
            .document(userId)
            .updateData([
                "role": newRole.rawValue,
                "updatedAt": Timestamp(date: Date())
            ])
        
        print("✅ [FirebaseService] Rôle mis à jour pour: \(userId)")
    }
    
    /// Transférer le rôle admin (transaction atomique)
    func transferAdminRole(
        fromUserId: String,
        toUserId: String,
        companyId: String
    ) async throws {
        _ = try await db.runTransaction { transaction, errorPointer in
            // Rétrograder l'ancien admin en manager
            let oldAdminRef = self.db.collection("users").document(fromUserId)
            transaction.updateData([
                "role": User.UserRole.manager.rawValue,
                "updatedAt": Timestamp(date: Date())
            ], forDocument: oldAdminRef)
            
            // Promouvoir le nouveau admin
            let newAdminRef = self.db.collection("users").document(toUserId)
            transaction.updateData([
                "role": User.UserRole.admin.rawValue,
                "updatedAt": Timestamp(date: Date())
            ], forDocument: newAdminRef)
            
            // Mettre à jour le ownerId de l'entreprise
            let companyRef = self.db.collection("companies").document(companyId)
            transaction.updateData([
                "ownerId": toUserId
            ], forDocument: companyRef)
            
            return nil
        }
        
        print("✅ [FirebaseService] Rôle admin transféré de \(fromUserId) à \(toUserId)")
    }
    
    /// Retirer un membre de l'entreprise
    func removeUserFromCompany(userId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .updateData([
                "companyId": FieldValue.delete(),
                "role": FieldValue.delete(),
                "joinedAt": FieldValue.delete(),
                "updatedAt": Timestamp(date: Date())
            ])
        
        print("✅ [FirebaseService] Utilisateur retiré de l'entreprise: \(userId)")
    }
    
    // MARK: - Errors Extension
    
    enum FirebaseServiceError: Error, LocalizedError {
        case userNotFound
        case companyNotFound
        
        var errorDescription: String? {
            switch self {
            case .userNotFound:
                return "Utilisateur introuvable"
            case .companyNotFound:
                return "Entreprise introuvable"
            }
        }
    }
}

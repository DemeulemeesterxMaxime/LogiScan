//
//  InvitationService.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import FirebaseFirestore
import Foundation

final class InvitationService {
    private let db = Firestore.firestore()
    
    // MARK: - Code Generation
    
    /// Générer un nouveau code d'invitation
    func generateInvitationCode(
        companyId: String,
        companyName: String,
        customCode: String? = nil,  // Code personnalisé optionnel
        customName: String? = nil,  // Nom personnalisé optionnel
        role: User.UserRole,
        createdBy: String,
        validityDays: Int = 7,
        maxUses: Int = 10
    ) async throws -> InvitationCode {
        // Vérifier que le code personnalisé n'existe pas déjà
        if let customCode = customCode {
            let normalizedCode = customCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            
            // Vérifier l'unicité
            let existingCodes = try await db.collection("invitationCodes")
                .whereField("code", isEqualTo: normalizedCode)
                .limit(to: 1)
                .getDocuments()
            
            if !existingCodes.documents.isEmpty {
                throw InvitationError.codeAlreadyExists
            }
        }
        
        let code = InvitationCode(
            companyId: companyId,
            companyName: companyName,
            customCode: customCode,
            customName: customName,
            role: role,
            createdBy: createdBy,
            validityDays: validityDays,
            maxUses: maxUses
        )
        
        let firestoreCode = code.toFirestoreInvitationCode()
        
        try await db.collection("invitationCodes")
            .document(code.codeId)
            .setData(from: firestoreCode)
        
        if let customName = customName {
            print("✅ [InvitationService] Code généré: \(code.code) (\(customName))")
        } else {
            print("✅ [InvitationService] Code généré: \(code.code)")
        }
        
        if customCode != nil {
            print("   🎨 Code personnalisé utilisé")
        } else {
            print("   🤖 Code généré automatiquement")
        }
        
        return code
    }
    
    // MARK: - Code Validation
    
    /// Valider un code d'invitation
    func validateCode(_ codeString: String) async throws -> InvitationCode {
        // Normaliser le code (trim + uppercase)
        let normalizedCode = codeString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        print("🔍 [InvitationService] Validation du code: '\(normalizedCode)'")
        print("   📝 Code original: '\(codeString)'")
        
        let snapshot = try await db.collection("invitationCodes")
            .whereField("code", isEqualTo: normalizedCode)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()
        
        print("📊 [InvitationService] Résultats trouvés: \(snapshot.documents.count)")
        
        guard let document = snapshot.documents.first else {
            // Debug: Lister tous les codes actifs disponibles
            print("⚠️ [InvitationService] Code non trouvé! Listing des codes actifs...")
            
            let allCodes = try await db.collection("invitationCodes")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            print("📋 Codes actifs disponibles (\(allCodes.documents.count) au total):")
            for doc in allCodes.documents {
                if let code = doc.data()["code"] as? String,
                   let companyName = doc.data()["companyName"] as? String,
                   let role = doc.data()["role"] as? String {
                    print("   ✅ \(code) - \(companyName) - Rôle: \(role)")
                }
            }
            
            throw InvitationError.invalidCode
        }
        
        guard let firestoreCode = try? document.data(as: FirestoreInvitationCode.self) else {
            print("❌ [InvitationService] Erreur parsing du document")
            throw InvitationError.invalidCode
        }
        
        let code = firestoreCode.toSwiftData()
        
        print("✅ [InvitationService] Code valide trouvé:")
        print("   🏢 Entreprise: \(code.companyName)")
        print("   👤 Rôle: \(code.role.rawValue)")
        print("   📅 Expire le: \(code.expiresAt.formatted())")
        print("   📊 Utilisations: \(code.usedCount)/\(code.maxUses)")
        print("   🆔 Code ID: \(code.codeId)")
        
        // Vérifier la validité
        guard code.isValid else {
            if code.expiresAt < Date() {
                print("❌ Code expiré!")
                throw InvitationError.expiredCode
            } else if code.usedCount >= code.maxUses {
                print("❌ Nombre max d'utilisations atteint!")
                throw InvitationError.maxUsesReached
            } else {
                print("❌ Code inactif!")
                throw InvitationError.inactiveCode
            }
        }
        
        return code
    }
    
    /// Utiliser un code d'invitation (incrémenter usedCount + archiver si maxUses atteint)
    func useInvitationCode(codeId: String) async throws {
        print("🔄 [InvitationService] Début utilisation code: \(codeId)")
        
        let ref = db.collection("invitationCodes").document(codeId)
        
        // Récupérer l'état actuel avant l'update
        let snapshot = try await ref.getDocument()
        let currentUsedCount = snapshot.data()?["usedCount"] as? Int ?? 0
        let maxUses = snapshot.data()?["maxUses"] as? Int ?? 1
        
        print("   📊 UsedCount actuel: \(currentUsedCount)")
        print("   📊 MaxUses: \(maxUses)")
        
        // Incrémenter le compteur
        try await ref.updateData([
            "usedCount": FieldValue.increment(Int64(1))
        ])
        
        // Vérifier que l'update a bien fonctionné
        let updatedSnapshot = try await ref.getDocument()
        if let newUsedCount = updatedSnapshot.data()?["usedCount"] as? Int {
            print("✅ [InvitationService] Code utilisé: \(codeId)")
            print("   📊 Nouveau usedCount: \(newUsedCount)")
            
            // Si maxUses atteint, archiver automatiquement le code
            if newUsedCount >= maxUses {
                print("📦 [InvitationService] MaxUses atteint (\(newUsedCount)/\(maxUses)), archivage automatique...")
                try await archiveCode(codeId: codeId)
            }
        } else {
            print("⚠️ [InvitationService] Impossible de vérifier le nouveau usedCount")
        }
    }
    
    // MARK: - Code Management
    
    /// Récupérer tous les codes d'une entreprise
    func fetchInvitationCodes(companyId: String, includeArchived: Bool = false) async throws -> [InvitationCode] {
        var query = db.collection("invitationCodes")
            .whereField("companyId", isEqualTo: companyId)
        
        // Exclure les codes archivés par défaut
        if !includeArchived {
            query = query.whereField("isArchived", isEqualTo: false)
        }
        
        let snapshot = try await query.getDocuments()
        
        var codes = snapshot.documents.compactMap { document -> InvitationCode? in
            guard let firestoreCode = try? document.data(as: FirestoreInvitationCode.self) else {
                return nil
            }
            return firestoreCode.toSwiftData()
        }
        
        // Trier en mémoire au lieu de dans Firestore
        codes.sort { $0.createdAt > $1.createdAt }
        
        print("✅ [InvitationService] \(codes.count) codes récupérés (includeArchived: \(includeArchived))")
        return codes
    }
    
    /// Récupérer uniquement les codes archivés
    func fetchArchivedCodes(companyId: String) async throws -> [InvitationCode] {
        let snapshot = try await db.collection("invitationCodes")
            .whereField("companyId", isEqualTo: companyId)
            .whereField("isArchived", isEqualTo: true)
            .getDocuments()
        
        var codes = snapshot.documents.compactMap { document -> InvitationCode? in
            guard let firestoreCode = try? document.data(as: FirestoreInvitationCode.self) else {
                return nil
            }
            return firestoreCode.toSwiftData()
        }
        
        codes.sort { $0.createdAt > $1.createdAt }
        
        print("✅ [InvitationService] \(codes.count) codes archivés récupérés")
        return codes
    }
    
    /// Archiver un code (quand maxUses atteint ou manuellement)
    func archiveCode(codeId: String) async throws {
        try await db.collection("invitationCodes")
            .document(codeId)
            .updateData([
                "isArchived": true,
                "isActive": false  // Désactiver aussi pour sécurité
            ])
        
        print("📦 [InvitationService] Code archivé: \(codeId)")
    }
    
    /// Restaurer un code archivé
    func unarchiveCode(codeId: String) async throws {
        // Vérifier d'abord si le code n'est pas épuisé ou expiré
        let document = try await db.collection("invitationCodes")
            .document(codeId)
            .getDocument()
        
        guard let firestoreCode = try? document.data(as: FirestoreInvitationCode.self) else {
            throw InvitationError.invalidCode
        }
        
        let code = firestoreCode.toSwiftData()
        
        // Ne pas restaurer si maxUses atteint
        guard code.usedCount < code.maxUses else {
            throw InvitationError.maxUsesReached
        }
        
        // Ne pas restaurer si expiré
        guard code.expiresAt > Date() else {
            throw InvitationError.expiredCode
        }
        
        try await db.collection("invitationCodes")
            .document(codeId)
            .updateData([
                "isArchived": false,
                "isActive": true
            ])
        
        print("♻️ [InvitationService] Code restauré: \(codeId)")
    }
    
    /// Modifier le nom personnalisé d'un code
    func updateCodeName(codeId: String, newName: String?) async throws {
        var updateData: [String: Any] = [:]
        
        if let newName = newName, !newName.isEmpty {
            updateData["customName"] = newName
        } else {
            updateData["customName"] = FieldValue.delete()
        }
        
        try await db.collection("invitationCodes")
            .document(codeId)
            .updateData(updateData)
        
        if let newName = newName {
            print("✏️ [InvitationService] Nom du code modifié: \(codeId) → '\(newName)'")
        } else {
            print("✏️ [InvitationService] Nom personnalisé supprimé: \(codeId)")
        }
    }
    
    /// Désactiver un code
    func deactivateCode(codeId: String) async throws {
        try await db.collection("invitationCodes")
            .document(codeId)
            .updateData(["isActive": false])
        
        print("✅ [InvitationService] Code désactivé: \(codeId)")
    }
    
    /// Activer un code
    func activateCode(codeId: String) async throws {
        try await db.collection("invitationCodes")
            .document(codeId)
            .updateData(["isActive": true])
        
        print("✅ [InvitationService] Code activé: \(codeId)")
    }
    
    /// Supprimer un code
    func deleteCode(codeId: String) async throws {
        try await db.collection("invitationCodes")
            .document(codeId)
            .delete()
        
        print("✅ [InvitationService] Code supprimé: \(codeId)")
    }
    
    // MARK: - Diagnostics
    
    /// Récupérer l'état actuel d'un code (pour debug)
    func checkCodeStatus(codeId: String) async throws -> InvitationCode {
        let document = try await db.collection("invitationCodes")
            .document(codeId)
            .getDocument()
        
        guard let firestoreCode = try? document.data(as: FirestoreInvitationCode.self) else {
            throw InvitationError.invalidCode
        }
        
        let code = firestoreCode.toSwiftData()
        
        print("📊 [InvitationService] État du code \(codeId):")
        print("   Code: \(code.code)")
        print("   UsedCount: \(code.usedCount)")
        print("   MaxUses: \(code.maxUses)")
        print("   IsActive: \(code.isActive)")
        print("   IsValid: \(code.isValid)")
        
        return code
    }
    
    // MARK: - Errors
    
    enum InvitationError: Error, LocalizedError {
        case invalidCode
        case expiredCode
        case maxUsesReached
        case inactiveCode
        case codeAlreadyExists  // Nouveau
        
        var errorDescription: String? {
            switch self {
            case .invalidCode:
                return "Code d'invitation invalide"
            case .expiredCode:
                return "Ce code d'invitation a expiré"
            case .maxUsesReached:
                return "Ce code a atteint son nombre maximum d'utilisations"
            case .inactiveCode:
                return "Ce code d'invitation n'est plus actif"
            case .codeAlreadyExists:
                return "Ce code existe déjà, veuillez en choisir un autre"
            }
        }
    }
}

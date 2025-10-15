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
        role: User.UserRole,
        createdBy: String,
        validityDays: Int = 7,
        maxUses: Int = 10
    ) async throws -> InvitationCode {
        let code = InvitationCode(
            companyId: companyId,
            companyName: companyName,
            role: role,
            createdBy: createdBy,
            validityDays: validityDays,
            maxUses: maxUses
        )
        
        let firestoreCode = code.toFirestoreInvitationCode()
        
        try await db.collection("invitationCodes")
            .document(code.codeId)
            .setData(from: firestoreCode)
        
        print("✅ [InvitationService] Code généré: \(code.code)")
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
    
    /// Utiliser un code d'invitation (incrémenter usedCount)
    func useInvitationCode(codeId: String) async throws {
        let ref = db.collection("invitationCodes").document(codeId)
        
        try await ref.updateData([
            "usedCount": FieldValue.increment(Int64(1))
        ])
        
        print("✅ [InvitationService] Code utilisé: \(codeId)")
    }
    
    // MARK: - Code Management
    
    /// Récupérer tous les codes d'une entreprise
    func fetchInvitationCodes(companyId: String) async throws -> [InvitationCode] {
        let snapshot = try await db.collection("invitationCodes")
            .whereField("companyId", isEqualTo: companyId)
            .getDocuments()
        
        var codes = snapshot.documents.compactMap { document -> InvitationCode? in
            guard let firestoreCode = try? document.data(as: FirestoreInvitationCode.self) else {
                return nil
            }
            return firestoreCode.toSwiftData()
        }
        
        // Trier en mémoire au lieu de dans Firestore
        codes.sort { $0.createdAt > $1.createdAt }
        
        print("✅ [InvitationService] \(codes.count) codes récupérés")
        return codes
    }
    
    /// Désactiver un code
    func deactivateCode(codeId: String) async throws {
        try await db.collection("invitationCodes")
            .document(codeId)
            .updateData(["isActive": false])
        
        print("✅ [InvitationService] Code désactivé: \(codeId)")
    }
    
    /// Supprimer un code
    func deleteCode(codeId: String) async throws {
        try await db.collection("invitationCodes")
            .document(codeId)
            .delete()
        
        print("✅ [InvitationService] Code supprimé: \(codeId)")
    }
    
    // MARK: - Errors
    
    enum InvitationError: Error, LocalizedError {
        case invalidCode
        case expiredCode
        case maxUsesReached
        case inactiveCode
        
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
            }
        }
    }
}

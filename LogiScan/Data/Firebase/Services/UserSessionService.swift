//
//  UserSessionService.swift
//  LogiScan
//
//  Created by Demeulemeester on 15/10/2025.
//

import FirebaseAuth
import Foundation

@MainActor
class UserSessionService: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    
    private let firebaseService = FirebaseService()
    
    /// Charger les données utilisateur depuis Firestore
    func loadUserSession() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ [UserSession] Pas d'utilisateur connecté Firebase")
            return
        }
        
        isLoading = true
        error = nil
        print("🔄 [UserSession] Chargement session pour userId: \(userId)")
        
        do {
            let user = try await firebaseService.fetchUser(userId: userId)
            print("✅ [UserSession] Utilisateur chargé:")
            print("   👤 Nom: \(user.displayName)")
            print("   📧 Email: \(user.email)")
            if let companyId = user.companyId {
                print("   🏢 Company: \(companyId)")
            }
            if let role = user.role {
                print("   👑 Role: \(role.rawValue)")
                print("   🔑 Permissions: \(role.permissions.count) permissions")
                
                // Détail des permissions
                for permission in role.permissions {
                    print("      - \(permission.rawValue)")
                }
            } else {
                print("   ⚠️ Pas de rôle attribué")
            }
            
            currentUser = user
            PermissionService.shared.setCurrentUser(user)
            
        } catch {
            print("❌ [UserSession] Erreur chargement: \(error.localizedDescription)")
            self.error = "Impossible de charger votre profil: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Effacer la session
    func clearSession() {
        currentUser = nil
        PermissionService.shared.clearCurrentUser()
        error = nil
        print("🧹 [UserSession] Session effacée")
    }
    
    /// Rafraîchir la session (par exemple après une modification de profil)
    func refreshSession() async {
        guard currentUser != nil else { return }
        await loadUserSession()
    }
}

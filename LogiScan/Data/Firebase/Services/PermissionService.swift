//
//  PermissionService.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import Foundation
import SwiftUI

@Observable
final class PermissionService {
    static let shared = PermissionService()
    
    private(set) var currentUser: User?
    
    private init() {}
    
    // MARK: - User Management
    
    /// Définir l'utilisateur courant
    func setCurrentUser(_ user: User) {
        self.currentUser = user
        print("✅ [PermissionService] Utilisateur défini: \(user.displayName) (\(user.role?.displayName ?? "Aucun rôle"))")
    }
    
    /// Effacer l'utilisateur courant (logout)
    func clearCurrentUser() {
        self.currentUser = nil
        print("✅ [PermissionService] Utilisateur effacé")
    }
    
    // MARK: - Permission Checks
    
    /// Vérifier si l'utilisateur a une permission spécifique
    func checkPermission(_ permission: User.Permission) -> Bool {
        guard let user = currentUser else {
            print("⚠️ [PermissionService] Aucun utilisateur connecté")
            return false
        }
        
        let hasPermission = user.hasPermission(permission)
        
        if !hasPermission {
            print("❌ [PermissionService] Permission refusée: \(permission.rawValue) pour \(user.displayName)")
        }
        
        return hasPermission
    }
    
    /// Vérifier si l'utilisateur a toutes les permissions dans la liste
    func checkAllPermissions(_ permissions: [User.Permission]) -> Bool {
        return permissions.allSatisfy { checkPermission($0) }
    }
    
    /// Vérifier si l'utilisateur a au moins une des permissions dans la liste
    func checkAnyPermission(_ permissions: [User.Permission]) -> Bool {
        return permissions.contains { checkPermission($0) }
    }
    
    /// Lancer une erreur si l'utilisateur n'a pas la permission
    func requirePermission(_ permission: User.Permission) throws {
        guard checkPermission(permission) else {
            throw PermissionError.accessDenied(permission)
        }
    }
    
    /// Vérifier si l'utilisateur est admin
    func isAdmin() -> Bool {
        return currentUser?.role == .admin
    }
    
    /// Vérifier si l'utilisateur est manager ou admin
    func isManagerOrAbove() -> Bool {
        guard let role = currentUser?.role else { return false }
        return role == .admin || role == .manager
    }
    
    // MARK: - Errors
    
    enum PermissionError: Error, LocalizedError {
        case accessDenied(User.Permission)
        case noUserLoggedIn
        
        var errorDescription: String? {
            switch self {
            case .accessDenied(let permission):
                return "Accès refusé : Vous n'avez pas la permission \"\(permission.displayName)\""
            case .noUserLoggedIn:
                return "Aucun utilisateur connecté"
            }
        }
    }
}

//
//  PermissionModifier.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import SwiftUI

/// Modifier pour afficher/cacher une vue selon les permissions
struct RequiresPermission: ViewModifier {
    let permission: User.Permission
    @State private var permissionService = PermissionService.shared
    
    func body(content: Content) -> some View {
        Group {
            if permissionService.checkPermission(permission) {
                content
            } else {
                EmptyView()
            }
        }
    }
}

/// Modifier pour afficher/cacher selon plusieurs permissions (toutes requises)
struct RequiresAllPermissions: ViewModifier {
    let permissions: [User.Permission]
    @State private var permissionService = PermissionService.shared
    
    func body(content: Content) -> some View {
        Group {
            if permissionService.checkAllPermissions(permissions) {
                content
            } else {
                EmptyView()
            }
        }
    }
}

/// Modifier pour afficher/cacher selon plusieurs permissions (au moins une requise)
struct RequiresAnyPermission: ViewModifier {
    let permissions: [User.Permission]
    @State private var permissionService = PermissionService.shared
    
    func body(content: Content) -> some View {
        Group {
            if permissionService.checkAnyPermission(permissions) {
                content
            } else {
                EmptyView()
            }
        }
    }
}

/// Modifier pour n'afficher que pour les admins
struct RequiresAdmin: ViewModifier {
    @State private var permissionService = PermissionService.shared
    
    func body(content: Content) -> some View {
        Group {
            if permissionService.isAdmin() {
                content
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Afficher la vue seulement si l'utilisateur a la permission
    func requiresPermission(_ permission: User.Permission) -> some View {
        self.modifier(RequiresPermission(permission: permission))
    }
    
    /// Afficher la vue seulement si l'utilisateur a toutes les permissions
    func requiresAllPermissions(_ permissions: [User.Permission]) -> some View {
        self.modifier(RequiresAllPermissions(permissions: permissions))
    }
    
    /// Afficher la vue seulement si l'utilisateur a au moins une des permissions
    func requiresAnyPermission(_ permissions: [User.Permission]) -> some View {
        self.modifier(RequiresAnyPermission(permissions: permissions))
    }
    
    /// Afficher la vue seulement pour les admins
    func requiresAdmin() -> some View {
        self.modifier(RequiresAdmin())
    }
}

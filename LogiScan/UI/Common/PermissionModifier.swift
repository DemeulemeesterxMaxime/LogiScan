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
    @State private var hasPermission = false
    
    func body(content: Content) -> some View {
        Group {
            if hasPermission {
                content
            } else {
                EmptyView()
            }
        }
        .onAppear {
            hasPermission = PermissionService.shared.checkPermission(permission)
        }
        .onChange(of: PermissionService.shared.currentUser) { _, _ in
            hasPermission = PermissionService.shared.checkPermission(permission)
        }
    }
}

/// Modifier pour afficher/cacher selon plusieurs permissions (toutes requises)
struct RequiresAllPermissions: ViewModifier {
    let permissions: [User.Permission]
    @State private var hasPermissions = false
    
    func body(content: Content) -> some View {
        Group {
            if hasPermissions {
                content
            } else {
                EmptyView()
            }
        }
        .onAppear {
            hasPermissions = PermissionService.shared.checkAllPermissions(permissions)
        }
        .onChange(of: PermissionService.shared.currentUser) { _, _ in
            hasPermissions = PermissionService.shared.checkAllPermissions(permissions)
        }
    }
}

/// Modifier pour afficher/cacher selon plusieurs permissions (au moins une requise)
struct RequiresAnyPermission: ViewModifier {
    let permissions: [User.Permission]
    @State private var hasPermission = false
    
    func body(content: Content) -> some View {
        Group {
            if hasPermission {
                content
            } else {
                EmptyView()
            }
        }
        .onAppear {
            hasPermission = PermissionService.shared.checkAnyPermission(permissions)
        }
        .onChange(of: PermissionService.shared.currentUser) { _, _ in
            hasPermission = PermissionService.shared.checkAnyPermission(permissions)
        }
    }
}

/// Modifier pour n'afficher que pour les admins
struct RequiresAdmin: ViewModifier {
    @State private var isAdmin = false
    
    func body(content: Content) -> some View {
        Group {
            if isAdmin {
                content
            } else {
                EmptyView()
            }
        }
        .onAppear {
            isAdmin = PermissionService.shared.isAdmin()
        }
        .onChange(of: PermissionService.shared.currentUser) { _, _ in
            isAdmin = PermissionService.shared.isAdmin()
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

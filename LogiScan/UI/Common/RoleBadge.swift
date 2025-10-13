//
//  RoleBadge.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import SwiftUI

/// Badge coloré pour afficher le rôle d'un utilisateur
struct RoleBadge: View {
    let role: User.UserRole
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var font: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }
        
        var iconSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .body
            }
        }
        
        var padding: (horizontal: CGFloat, vertical: CGFloat) {
            switch self {
            case .small: return (6, 2)
            case .medium: return (8, 4)
            case .large: return (12, 6)
            }
        }
    }
    
    init(role: User.UserRole, size: BadgeSize = .medium) {
        self.role = role
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: role.icon)
                .font(size.iconSize)
            Text(role.displayName)
                .font(size.font)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, size.padding.horizontal)
        .padding(.vertical, size.padding.vertical)
        .background(
            Capsule()
                .fill(badgeColor)
        )
    }
    
    private var badgeColor: Color {
        switch role {
        case .admin:
            return .red
        case .manager:
            return .blue
        case .standardEmployee:
            return .green
        case .limitedEmployee:
            return .gray
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Small Size")
            .font(.headline)
        HStack {
            RoleBadge(role: .admin, size: .small)
            RoleBadge(role: .manager, size: .small)
            RoleBadge(role: .standardEmployee, size: .small)
            RoleBadge(role: .limitedEmployee, size: .small)
        }
        
        Divider()
        
        Text("Medium Size")
            .font(.headline)
        HStack {
            RoleBadge(role: .admin, size: .medium)
            RoleBadge(role: .manager, size: .medium)
            RoleBadge(role: .standardEmployee, size: .medium)
            RoleBadge(role: .limitedEmployee, size: .medium)
        }
        
        Divider()
        
        Text("Large Size")
            .font(.headline)
        VStack(alignment: .leading, spacing: 12) {
            RoleBadge(role: .admin, size: .large)
            RoleBadge(role: .manager, size: .large)
            RoleBadge(role: .standardEmployee, size: .large)
            RoleBadge(role: .limitedEmployee, size: .large)
        }
    }
    .padding()
}

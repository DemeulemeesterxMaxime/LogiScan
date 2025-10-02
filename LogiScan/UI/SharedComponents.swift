//
//  SharedComponents.swift
//  LogiScan
//
//  Created by Demeulemeester on 02/10/2025.
//

import SwiftUI

/// Composant de filtre réutilisable sous forme de chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

/// Badge pour afficher le type de propriété (Notre matériel / Location)
struct OwnershipBadge: View {
    let ownershipType: OwnershipType
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
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: ownershipType.icon)
                .font(size.iconSize)
            Text(ownershipType.displayName)
                .font(size.font)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, size.padding.horizontal)
        .padding(.vertical, size.padding.vertical)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
    }
    
    private var color: Color {
        switch ownershipType {
        case .owned: return .blue
        case .rented: return .orange
        }
    }
    
    private var backgroundColor: Color {
        switch ownershipType {
        case .owned: return Color.blue.opacity(0.15)
        case .rented: return Color.orange.opacity(0.15)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            FilterChip(title: "Tous", isSelected: true, action: {})
            FilterChip(title: "Audio", isSelected: false, action: {})
            FilterChip(title: "Vidéo", isSelected: false, action: {})
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Ownership Badges - Small")
                .font(.headline)
            HStack {
                OwnershipBadge(ownershipType: .owned, size: .small)
                OwnershipBadge(ownershipType: .rented, size: .small)
            }
            
            Text("Ownership Badges - Medium")
                .font(.headline)
            HStack {
                OwnershipBadge(ownershipType: .owned, size: .medium)
                OwnershipBadge(ownershipType: .rented, size: .medium)
            }
            
            Text("Ownership Badges - Large")
                .font(.headline)
            HStack {
                OwnershipBadge(ownershipType: .owned, size: .large)
                OwnershipBadge(ownershipType: .rented, size: .large)
            }
        }
    }
    .padding()
}

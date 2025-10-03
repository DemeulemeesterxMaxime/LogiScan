//
//  SharedComponents.swift
//  LogiScan
//
//  Created by Demeulemeester on 02/10/2025.
//

import SwiftUI
import UIKit

// MARK: - Share Sheet

/// Wrapper pour UIActivityViewController permettant de partager du contenu
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Filter Chip

/// Composant de filtre réutilisable sous forme de chip
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Ownership Badge

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

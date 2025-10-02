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

#Preview {
    HStack {
        FilterChip(title: "Tous", isSelected: true, action: {})
        FilterChip(title: "Audio", isSelected: false, action: {})
        FilterChip(title: "Vidéo", isSelected: false, action: {})
    }
    .padding()
}

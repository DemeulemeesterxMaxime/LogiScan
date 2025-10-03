//
//  StockListView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftData
import SwiftUI

struct StockListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stockItems: [StockItem]
    @State private var searchText = ""
    @State private var selectedCategory = "Tous"
    @State private var selectedTag: String? = nil
    @State private var selectedOwnership: OwnershipType? = nil
    @State private var showingAddItem = false

    private let categories = ["Tous", "Éclairage", "Son", "Structures", "Mobilier", "Divers"]

    var allTags: [String] {
        let tags = stockItems.flatMap { $0.tags }
        return Array(Set(tags)).sorted()
    }

    var filteredItems: [StockItem] {
        var items = stockItems

        // Filtrer par ownership (propriété/location)
        if let ownership = selectedOwnership {
            items = items.filter { $0.ownershipType == ownership }
        }

        // Filtrer par catégorie
        if selectedCategory != "Tous" {
            items = items.filter { $0.category == selectedCategory }
        }

        // Filtrer par tag
        if let tag = selectedTag {
            items = items.filteredByTag(tag)
        }

        // Filtrer par recherche (incluant les tags)
        return items.filteredBySearch(searchText)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filtres ownership (Propriété/Location)
                ownershipFiltersSection

                // Filtres par catégorie
                categoryFiltersSection

                // Filtres par tags
                if !allTags.isEmpty {
                    tagFiltersSection
                }

                // Liste des items
                List(filteredItems) { item in
                    NavigationLink(destination: StockItemDetailView(stockItem: item)) {
                        StockItemRow(item: item)
                    }
                }
                .searchable(text: $searchText, prompt: "Rechercher un article ou tag...")
                .listStyle(.plain)
            }
            .navigationTitle("Stock")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            StockItemFormView()
        }
    }

    // MARK: - Filtre Ownership
    private var ownershipFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "Tous",
                    isSelected: selectedOwnership == nil,
                    action: { selectedOwnership = nil }
                )

                ForEach(OwnershipType.allCases, id: \.self) { type in
                    HStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.caption)
                        Text(type.displayName)
                    }
                    .font(.subheadline)
                    .fontWeight(selectedOwnership == type ? .semibold : .regular)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                selectedOwnership == type
                                    ? ownershipColor(type) : Color(.systemGray5))
                    )
                    .foregroundColor(selectedOwnership == type ? .white : .primary)
                    .onTapGesture {
                        selectedOwnership = type
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGray6))
    }

    private func ownershipColor(_ type: OwnershipType) -> Color {
        switch type {
        case .owned: return .blue
        case .rented: return .orange
        }
    }

    private var categoryFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    FilterChip(
                        title: category,
                        isSelected: selectedCategory == category,
                        action: {
                            selectedCategory = category
                            selectedTag = nil  // Reset tag filter when changing category
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private var tagFiltersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Filtrer par étiquettes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading)

                Spacer()

                if selectedTag != nil {
                    Button("Effacer") {
                        selectedTag = nil
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.trailing)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allTags, id: \.self) { tag in
                        Button(action: {
                            selectedTag = selectedTag == tag ? nil : tag
                        }) {
                            Text(tag)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            selectedTag == tag ? Color.green : Color(.systemGray5))
                                )
                                .foregroundColor(selectedTag == tag ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct StockItemRow: View {
    let item: StockItem

    var body: some View {
        HStack(spacing: 12) {
            // Icône catégorie + Ownership badge
            VStack(spacing: 4) {
                Image(systemName: categoryIcon(item.category))
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.blue.opacity(0.1)))

                // Badge Ownership
                HStack(spacing: 2) {
                    Image(systemName: item.ownershipType.icon)
                        .font(.caption2)
                    Text(item.ownershipType == .owned ? "Prop." : "Loc.")
                        .font(.caption2)
                }
                .foregroundColor(item.ownershipType == .owned ? .blue : .orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(
                            item.ownershipType == .owned
                                ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()
                }

                Text("SKU: \(item.sku)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Tags
                if !item.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(item.tags.prefix(3)), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .clipShape(Capsule())
                            }

                            if item.tags.count > 3 {
                                Text("+\(item.tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Prix
                Text(String(format: "%.2f € / unité", item.effectivePrice))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.availableQuantity)/\(item.totalQuantity)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(item.availableQuantity > 0 ? .green : .red)

                Text("disponible")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if item.maintenanceQuantity > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "wrench.fill")
                            .font(.caption2)
                        Text("\(item.maintenanceQuantity)")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "Éclairage": return "lightbulb.fill"
        case "Son": return "speaker.wave.3.fill"
        case "Structures": return "square.grid.3x3.fill"
        case "Mobilier": return "table.furniture.fill"
        default: return "cube.box.fill"
        }
    }
}

#Preview {
    StockListView()
        .modelContainer(
            for: [StockItem.self, Asset.self, Movement.self, Event.self, Truck.self], inMemory: true
        )
}

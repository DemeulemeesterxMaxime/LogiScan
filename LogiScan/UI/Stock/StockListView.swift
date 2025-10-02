//
//  StockListView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftUI
import SwiftData

struct StockListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stockItems: [StockItem]
    @State private var searchText = ""
    @State private var selectedCategory = "Tous"
    @State private var selectedTag: String? = nil
    @State private var showingTagFilter = false
    
    private let categories = ["Tous", "Éclairage", "Son", "Structures", "Mobilier", "Divers"]
    
    var allTags: [String] {
        let tags = stockItems.flatMap { $0.tags }
        return Array(Set(tags)).sorted()
    }
    
    var filteredItems: [StockItem] {
        var items = stockItems
        
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
            VStack {
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
                    Button(action: addSampleData) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            if stockItems.isEmpty {
                addSampleData()
            }
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
                            selectedTag = nil // Reset tag filter when changing category
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
                                        .fill(selectedTag == tag ? Color.green : Color(.systemGray5))
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
    
    private func addSampleData() {
        let sampleItems = [
            StockItem(
                sku: "LED-SPOT-50W",
                name: "Projecteur LED 50W",
                category: "Éclairage",
                totalQuantity: 25,
                unitWeight: 2.5,
                unitVolume: 0.01,
                unitValue: 150.0,
                tags: ["LED", "50W", "Extérieur", "Spot"]
            ),
            StockItem(
                sku: "SPEAKER-15IN",
                name: "Enceinte 15 pouces",
                category: "Son",
                totalQuantity: 12,
                unitWeight: 18.0,
                unitVolume: 0.08,
                unitValue: 800.0,
                tags: ["Passif", "15\"", "Main", "Grave"]
            ),
            StockItem(
                sku: "TRUSS-3M",
                name: "Structure alu 3m",
                category: "Structures",
                totalQuantity: 30,
                unitWeight: 12.0,
                unitVolume: 0.15,
                unitValue: 120.0,
                tags: ["Alu", "3m", "Traverse", "Standard"]
            ),
            StockItem(
                sku: "PAR-LED-RGB",
                name: "PAR LED RGB 36x3W",
                category: "Éclairage",
                totalQuantity: 40,
                unitWeight: 3.2,
                unitVolume: 0.008,
                unitValue: 180.0,
                tags: ["LED", "RGB", "PAR", "36x3W", "Wash"]
            ),
            StockItem(
                sku: "TABLE-RONDE-180",
                name: "Table ronde 180cm",
                category: "Mobilier",
                totalQuantity: 20,
                unitWeight: 25.0,
                unitVolume: 0.5,
                unitValue: 45.0,
                tags: ["Ronde", "180cm", "8 personnes", "Pliante"]
            )
        ]
        
        for item in sampleItems {
            modelContext.insert(item)
        }
        
        try? modelContext.save()
    }
}

struct StockItemRow: View {
    let item: StockItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("SKU: \(item.sku)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(item.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    
                    if !item.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(item.tags.prefix(3)), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
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
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.availableQuantity)/\(item.totalQuantity)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(item.availableQuantity > 0 ? .primary : .red)
                
                Text("disponible")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if item.maintenanceQuantity > 0 {
                    Text("\(item.maintenanceQuantity) en maintenance")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: StockItem.self, Asset.self, Movement.self, Event.self, Truck.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    return StockListView()
        .modelContainer(container)
}

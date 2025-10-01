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
    
    private let categories = ["Tous", "Éclairage", "Son", "Structures", "Mobilier", "Divers"]
    
    var filteredItems: [StockItem] {
        var items = stockItems
        
        if selectedCategory != "Tous" {
            items = items.filter { $0.category == selectedCategory }
        }
        
        return items.filteredBySearch(searchText)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Filtres
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            FilterChip(
                                title: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Liste des items
                List(filteredItems) { item in
                    StockItemRow(item: item)
                }
                .searchable(text: $searchText, prompt: "Rechercher un article...")
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
    
    private func addSampleData() {
        let sampleItems = [
            StockItem(
                sku: "LED-SPOT-50W",
                name: "Projecteur LED 50W",
                category: "Éclairage",
                totalQuantity: 25,
                unitWeight: 2.5,
                unitVolume: 0.01,
                unitValue: 150.0
            ),
            StockItem(
                sku: "SPEAKER-15IN",
                name: "Enceinte 15 pouces",
                category: "Son",
                totalQuantity: 12,
                unitWeight: 18.0,
                unitVolume: 0.08,
                unitValue: 800.0
            ),
            StockItem(
                sku: "TRUSS-3M",
                name: "Structure alu 3m",
                category: "Structures",
                totalQuantity: 30,
                unitWeight: 12.0,
                unitVolume: 0.15,
                unitValue: 120.0
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
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("SKU: \(item.sku)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(item.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
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

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: StockItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    return StockListView()
        .modelContainer(container)
}

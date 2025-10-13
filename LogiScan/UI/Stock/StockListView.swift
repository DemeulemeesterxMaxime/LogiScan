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
    @Query private var allAssets: [Asset]
    @StateObject private var syncManager = SyncManager()
    
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var showingAddItem = false
    @State private var showingQuickActions = false
    @State private var selectedItemsForPrint: Set<String> = []
    
    // Filtres
    @State private var selectedOwnership: OwnershipType? = nil
    @State private var selectedCategories: Set<String> = []
    @State private var selectedTags: Set<String> = []

    
    // Catégories et tags disponibles (calculés dynamiquement)
    var availableCategories: [String] {
        let cats = Set(stockItems.map { $0.category })
        return Array(cats).sorted()
    }

    var availableTags: [String] {
        let tags = stockItems.flatMap { $0.tags }
        let uniqueTags = Set(tags)
        return Array(uniqueTags).sorted()
    }
    
    var availableOwnershipTypes: [OwnershipType] {
        let types = Set(stockItems.map { $0.ownershipType })
        return Array(types).sorted { $0.rawValue < $1.rawValue }
    }

    var filteredItems: [StockItem] {
        var items = stockItems

        // Filtrer par ownership
        if let ownership = selectedOwnership {
            items = items.filter { $0.ownershipType == ownership }
        }

        // Filtrer par catégories
        if !selectedCategories.isEmpty {
            items = items.filter { selectedCategories.contains($0.category) }
        }

        // Filtrer par tags
        if !selectedTags.isEmpty {
            items = items.filter { item in
                !Set(item.tags).isDisjoint(with: selectedTags)
            }
        }

        // Filtrer par recherche
        if !searchText.isEmpty {
            items = items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.sku.localizedCaseInsensitiveContains(searchText) ||
                item.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return items
    }
    
    var activeFiltersCount: Int {
        var count = 0
        if selectedOwnership != nil { count += 1 }
        if !selectedCategories.isEmpty { count += selectedCategories.count }
        if !selectedTags.isEmpty { count += selectedTags.count }
        return count
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Barre de recherche + bouton filtres
                searchBar
                
                // Badge des filtres actifs
                if activeFiltersCount > 0 {
                    activeFiltersBadge
                }

                // Liste ou empty state
                if filteredItems.isEmpty && stockItems.isEmpty {
                    emptyState
                } else if filteredItems.isEmpty {
                    noResultsState
                } else {
                    stockList
                }
            }
            .navigationTitle("Stock")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await syncManager.syncFromFirebase(modelContext: modelContext)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddItem = true }) {
                            Label("Nouvel article", systemImage: "plus.circle.fill")
                        }
                        .requiresPermission(.writeStock)
                        
                        Button(action: { showingQuickActions = true }) {
                            Label("Actions rapides", systemImage: "bolt.fill")
                        }
                        .requiresPermission(.writeStock)
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                Task {
                    await syncManager.syncFromFirebaseIfNeeded(modelContext: modelContext, forceRefresh: true)
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            StockItemFormView()
        }
        .sheet(isPresented: $showingFilters) {
            filtersSheet
        }
        .sheet(isPresented: $showingQuickActions) {
            quickActionsSheet
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            // Champ de recherche
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Rechercher un article...", text: $searchText)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Bouton filtres
            Button(action: { showingFilters = true }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: activeFiltersCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(activeFiltersCount > 0 ? .blue : .secondary)
                    
                    if activeFiltersCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Text("\(activeFiltersCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                            .offset(x: 6, y: -6)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Active Filters Badge
    
    private var activeFiltersBadge: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let ownership = selectedOwnership {
                    FilterBadge(text: ownership.displayName, icon: ownership.icon) {
                        selectedOwnership = nil
                    }
                }
                
                ForEach(Array(selectedCategories), id: \.self) { category in
                    FilterBadge(text: category, icon: categoryIcon(category)) {
                        selectedCategories.remove(category)
                    }
                }
                
                ForEach(Array(selectedTags), id: \.self) { tag in
                    FilterBadge(text: tag, icon: "tag.fill") {
                        selectedTags.remove(tag)
                    }
                }
                
                if activeFiltersCount > 0 {
                    Button(action: clearAllFilters) {
                        Text("Tout effacer")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }
    
    private func clearAllFilters() {
        selectedOwnership = nil
        selectedCategories.removeAll()
        selectedTags.removeAll()
    }
    
    // MARK: - Stock List
    
    private var stockList: some View {
        List {
            ForEach(filteredItems) { item in
                NavigationLink(destination: StockItemDetailView(stockItem: item)) {
                    StockItemRow(item: item, allAssets: allAssets)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteStockItem(item)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await syncManager.syncFromFirebase(modelContext: modelContext)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "cube.box")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Aucun article en stock")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Commencez par ajouter votre premier article")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingAddItem = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Configurer un nouvel article")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Section actions rapides même sans articles
            quickActionsPreview
        }
        .padding()
    }
    
    private var noResultsState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Aucun résultat")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Essayez de modifier vos filtres ou votre recherche")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: clearAllFilters) {
                Text("Réinitialiser les filtres")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Quick Actions Preview
    
    private var quickActionsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions rapides")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button(action: { showingQuickActions = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.title2)
                            Text("Imprimer les QR codes")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Text("Générez et imprimez des QR codes pour vos articles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Filters Sheet
    
    private var filtersSheet: some View {
        NavigationView {
            List {
                // Section Propriété/Location
                if !availableOwnershipTypes.isEmpty {
                    Section {
                        ForEach(availableOwnershipTypes, id: \.self) { type in
                            Button(action: {
                                if selectedOwnership == type {
                                    selectedOwnership = nil
                                } else {
                                    selectedOwnership = type
                                }
                            }) {
                                HStack {
                                    Image(systemName: type.icon)
                                        .foregroundColor(selectedOwnership == type ? .blue : .secondary)
                                    
                                    Text(type.displayName)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedOwnership == type {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Type de matériel")
                    }
                }
                
                // Section Catégories
                if !availableCategories.isEmpty {
                    Section {
                        ForEach(availableCategories, id: \.self) { category in
                            Button(action: {
                                if selectedCategories.contains(category) {
                                    selectedCategories.remove(category)
                                } else {
                                    selectedCategories.insert(category)
                                }
                            }) {
                                HStack {
                                    Image(systemName: categoryIcon(category))
                                        .foregroundColor(selectedCategories.contains(category) ? .blue : .secondary)
                                    
                                    Text(category)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedCategories.contains(category) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Catégories")
                    }
                }
                
                // Section Tags
                if !availableTags.isEmpty {
                    Section {
                        ForEach(availableTags, id: \.self) { tag in
                            Button(action: {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "tag.fill")
                                        .foregroundColor(selectedTags.contains(tag) ? .green : .secondary)
                                    
                                    Text(tag)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(countItemsWithTag(tag))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                    
                                    if selectedTags.contains(tag) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Étiquettes")
                    } footer: {
                        Text("Seules les étiquettes utilisées sont affichées")
                    }
                }
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Réinitialiser") {
                        clearAllFilters()
                    }
                    .disabled(activeFiltersCount == 0)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") {
                        showingFilters = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func countItemsWithTag(_ tag: String) -> Int {
        stockItems.filter { $0.tags.contains(tag) }.count
    }
    
    // MARK: - Quick Actions Sheet
    
    private var quickActionsSheet: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: BulkQRCodePrintView(stockItems: stockItems, allAssets: allAssets)) {
                        HStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Imprimer des QR codes")
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text("Sélectionnez les articles et références à imprimer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink(destination: Text("Export CSV - À venir")) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.green)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Exporter en CSV")
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text("Exportez votre inventaire dans un fichier")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await syncManager.syncFromFirebase(modelContext: modelContext)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Synchroniser maintenant")
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                if let lastSync = syncManager.lastSyncDate {
                                    Text("Dernière synchro: \(lastSync, format: .relative(presentation: .named))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Jamais synchronisé")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if syncManager.isSyncing {
                                ProgressView()
                            }
                        }
                    }
                } header: {
                    Text("Actions disponibles")
                }
            }
            .navigationTitle("Actions rapides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        showingQuickActions = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions
    
    private func deleteStockItem(_ item: StockItem) {
        let skuToDelete = item.sku
        modelContext.delete(item)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Erreur sauvegarde : \(error)")
        }
        
        Task {
            await syncManager.deleteStockItemFromFirebase(sku: skuToDelete)
        }
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

// MARK: - Filter Badge Component

struct FilterBadge: View {
    let text: String
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue)
        .cornerRadius(16)
    }
}

// MARK: - Stock Item Row

struct StockItemRow: View {
    let item: StockItem
    let allAssets: [Asset]
    
    private var quantities: (available: Int, reserved: Int, inUse: Int, damaged: Int, maintenance: Int, lost: Int) {
        item.calculateQuantities(from: allAssets)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icône catégorie
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
                        .fill(item.ownershipType == .owned ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

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
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Quantité disponible
                Text("\(quantities.available)/\(item.totalQuantity)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(quantities.available > 0 ? .green : .red)

                Text("disponible")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Autres statuts
                HStack(spacing: 8) {
                    if quantities.maintenance > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "wrench.fill")
                                .font(.caption2)
                            Text("\(quantities.maintenance)")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }
                    
                    if quantities.reserved > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption2)
                            Text("\(quantities.reserved)")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if quantities.damaged > 0 || quantities.lost > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("\(quantities.damaged + quantities.lost)")
                                .font(.caption2)
                        }
                        .foregroundColor(.red)
                    }
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

// MARK: - Bulk QR Code Print View

struct BulkQRCodePrintView: View {
    let stockItems: [StockItem]
    let allAssets: [Asset]
    
    @State private var selectedItems: Set<String> = []
    @State private var selectedAssets: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                Text("Sélectionnez les articles et leurs références individuelles dont vous souhaitez imprimer les QR codes")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            ForEach(stockItems) { item in
                Section {
                    // Toggle article entier
                    Button(action: {
                        if selectedItems.contains(item.sku) {
                            selectedItems.remove(item.sku)
                        } else {
                            selectedItems.insert(item.sku)
                        }
                    }) {
                        HStack {
                            Image(systemName: selectedItems.contains(item.sku) ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedItems.contains(item.sku) ? .blue : .secondary)
                            
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text("Article principal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Assets individuels
                    let itemAssets = allAssets.filter { $0.sku == item.sku }
                    if !itemAssets.isEmpty {
                        ForEach(itemAssets) { asset in
                            Button(action: {
                                if selectedAssets.contains(asset.assetId) {
                                    selectedAssets.remove(asset.assetId)
                                } else {
                                    selectedAssets.insert(asset.assetId)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedAssets.contains(asset.assetId) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedAssets.contains(asset.assetId) ? .green : .secondary)
                                    
                                    VStack(alignment: .leading) {
                                        Text(asset.assetId)
                                            .foregroundColor(.primary)
                                        Text(asset.status.displayName)
                                            .font(.caption)
                                            .foregroundColor(asset.status.swiftUIColor)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text(item.name)
                }
            }
        }
        .navigationTitle("Impression QR codes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Annuler") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Imprimer (\(selectedItems.count + selectedAssets.count))") {
                    printSelectedQRCodes()
                }
                .disabled(selectedItems.isEmpty && selectedAssets.isEmpty)
                .fontWeight(.semibold)
            }
        }
    }
    
    private func printSelectedQRCodes() {
        // TODO: Implémenter l'impression des QR codes
        print("Impression de \(selectedItems.count) articles et \(selectedAssets.count) assets")
        dismiss()
    }
}

#Preview {
    StockListView()
        .modelContainer(for: [StockItem.self, Asset.self], inMemory: true)
}

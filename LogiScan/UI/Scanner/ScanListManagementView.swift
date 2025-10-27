//
//  ScanListManagementView.swift
//  LogiScan
//
//  Created by Copilot on 16/10/2025.
//

import SwiftUI
import SwiftData

/// Vue pour gérer manuellement une liste de scan (cocher/décocher des articles)
struct ScanListManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let scanList: ScanList
    
    @State private var searchText = ""
    @State private var showOnlyPending = false
    
    private var filteredItems: [PreparationListItem] {
        let items = scanList.items
        
        var filtered = items
        
        // Filtre par recherche
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.sku.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filtre par statut
        if showOnlyPending {
            filtered = filtered.filter { $0.quantityScanned < $0.quantityRequired }
        }
        
        return filtered.sorted { $0.name < $1.name }
    }
    
    private var progressPercentage: Double {
        guard scanList.totalItems > 0 else { return 0 }
        return Double(scanList.scannedItems) / Double(scanList.totalItems)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // En-tête avec progression
                headerView
                
                Divider()
                
                // Barre de recherche et filtres
                searchAndFiltersView
                
                Divider()
                
                // Liste des articles
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems) { item in
                                ScanListItemManagementRow(
                                    item: item,
                                    onToggle: { quantity in
                                        toggleItem(item, newQuantity: quantity)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Gestion de la liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Titre et statut
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scanList.eventName)
                        .font(.headline)
                    
                    Text(scanList.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Badge de progression
                VStack(spacing: 4) {
                    Text("\(scanList.scannedItems)/\(scanList.totalItems)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(scanList.isComplete ? .green : .orange)
                    
                    Text(scanList.isComplete ? "Complet" : "En cours")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Barre de progression
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fond
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    // Progression
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: scanList.isComplete ? [.green, .mint] : [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Search and Filters View
    
    private var searchAndFiltersView: some View {
        VStack(spacing: 12) {
            // Barre de recherche
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Rechercher un article...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Filtre
            Toggle(isOn: $showOnlyPending) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.blue)
                    Text("Afficher uniquement les articles non scannés")
                        .font(.subheadline)
                }
            }
            .toggleStyle(.switch)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "checkmark.circle.fill" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(searchText.isEmpty ? .green : .secondary)
            
            Text(searchText.isEmpty ? "Tous les articles sont scannés !" : "Aucun résultat")
                .font(.headline)
            
            if !searchText.isEmpty {
                Text("Essayez un autre terme de recherche")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Toggle Item
    
    private func toggleItem(_ item: PreparationListItem, newQuantity: Int) {
        withAnimation {
            let oldQuantity = item.quantityScanned
            item.quantityScanned = newQuantity
            
            // Recalculer le total scanné de la liste
            let difference = newQuantity - oldQuantity
            scanList.scannedItems += difference
            
            // Sauvegarder
            try? modelContext.save()
        }
    }
}

// MARK: - Scan List Item Management Row

struct ScanListItemManagementRow: View {
    let item: PreparationListItem
    let onToggle: (Int) -> Void
    
    @State private var showQuantityPicker = false
    
    private var isComplete: Bool {
        item.quantityScanned >= item.quantityRequired
    }
    
    private var progressPercentage: Double {
        guard item.quantityRequired > 0 else { return 0 }
        return Double(item.quantityScanned) / Double(item.quantityRequired)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Checkbox
                Button {
                    if isComplete {
                        // Décocher tout
                        onToggle(0)
                    } else {
                        // Afficher le picker si quantité > 1, sinon cocher directement
                        if item.quantityRequired > 1 {
                            showQuantityPicker = true
                        } else {
                            onToggle(item.quantityRequired)
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(isComplete ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        
                        if isComplete {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        } else if item.quantityScanned > 0 {
                            Text("\(item.quantityScanned)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Info article
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isComplete ? .secondary : .primary)
                    
                    HStack(spacing: 8) {
                        Text("SKU: \(item.sku)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Text("\(item.quantityScanned)/\(item.quantityRequired)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(isComplete ? .green : .orange)
                    }
                }
                
                Spacer()
                
                // Bouton d'action
                Button {
                    showQuantityPicker = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isComplete ? Color.green.opacity(0.05) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isComplete ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            // Barre de progression si quantité > 1
            if item.quantityRequired > 1 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.1))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isComplete ? Color.green : Color.orange)
                            .frame(width: geometry.size.width * progressPercentage)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
        .confirmationDialog(
            "Quantité scannée",
            isPresented: $showQuantityPicker,
            titleVisibility: .visible
        ) {
            ForEach(0...item.quantityRequired, id: \.self) { quantity in
                Button("\(quantity) / \(item.quantityRequired)") {
                    onToggle(quantity)
                }
            }
            
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("\(item.name)\nChoisissez le nombre d'articles scannés")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ScanList.self, PreparationListItem.self, configurations: config)
    
    let scanList = ScanList(
        eventId: "test",
        eventName: "Festival Test",
        scanDirection: .stockToTruck,
        totalItems: 100,
        scannedItems: 60,
        status: .inProgress
    )
    
    ScanListManagementView(scanList: scanList)
        .modelContainer(container)
}

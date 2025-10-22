//
//  EventScanListView.swift
//  LogiScan
//
//  Created by Assistant on 15/10/2025.
//

import SwiftUI
import SwiftData

struct EventScanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allAssets: [Asset]
    @StateObject private var scanListService = ScanListService()
    
    let scanList: ScanList
    
    @State private var showingScanner = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var selectedFilter: ScanItemStatus? = nil
    @State private var searchText = ""
    
    // Throttling pour éviter les scans trop rapides
    @State private var lastScanTime: Date?
    private let minimumScanInterval: TimeInterval = 1.0 // 1 seconde entre chaque scan
    
    private var filteredItems: [PreparationListItem] {
        var items = scanList.items
        
        // Filtrer par statut
        if let filter = selectedFilter {
            items = items.filter { $0.status == filter }
        }
        
        // Filtrer par recherche
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.sku.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items.sorted { item1, item2 in
            // Trier par statut (pending > partial > completed)
            if item1.status != item2.status {
                return item1.status.rawValue < item2.status.rawValue
            }
            // Puis par nom
            return item1.name < item2.name
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header avec progression
            headerView
            
            // Filtres et recherche
            filterSection
            
            // Liste des items
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredItems, id: \.preparationListItemId) { item in
                        PreparationItemRow(
                            item: item,
                            onTapScan: {
                                showingScanner = true
                            },
                            onUndo: { assetId in
                                undoScan(assetId: assetId, item: item)
                            }
                        )
                    }
                    
                    if filteredItems.isEmpty {
                        emptyState
                    }
                }
                .padding()
            }
            
            // Bouton scanner flottant
            if !scanList.isComplete {
                scanButton
            }
        }
        .navigationTitle("Liste de préparation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { resetScanList() }) {
                        Label("Réinitialiser", systemImage: "arrow.counterclockwise")
                    }
                    
                    Button(role: .destructive, action: { deleteScanList() }) {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            ContextualScannerView(
                scanList: scanList,
                onScanComplete: { result in
                    handleScan(result)
                }
            )
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Titre et statut
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scanList.eventName)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Image(systemName: scanList.status.icon)
                        Text(scanList.status.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(statusColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(scanList.scannedItems) / \(scanList.totalItems)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(scanList.progressPercentage)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Barre de progression
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * scanList.progress)
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
            
            // Statistiques
            HStack(spacing: 20) {
                StatBadge(
                    icon: "circle",
                    value: "\(scanList.items.filter { $0.status == .pending }.count)",
                    label: "À faire",
                    color: .gray
                )
                
                StatBadge(
                    icon: "circle.lefthalf.filled",
                    value: "\(scanList.items.filter { $0.status == .partial }.count)",
                    label: "Partiel",
                    color: .orange
                )
                
                StatBadge(
                    icon: "checkmark.circle.fill",
                    value: "\(scanList.items.filter { $0.status == .completed }.count)",
                    label: "Terminé",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            // Barre de recherche
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Rechercher un article...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            
            // Filtres par statut
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    PreparationFilterChip(
                        title: "Tous",
                        count: scanList.items.count,
                        isSelected: selectedFilter == nil,
                        action: { selectedFilter = nil }
                    )
                    
                    PreparationFilterChip(
                        title: "À faire",
                        count: scanList.items.filter { $0.status == .pending }.count,
                        isSelected: selectedFilter == .pending,
                        action: { selectedFilter = .pending }
                    )
                    
                    PreparationFilterChip(
                        title: "Partiel",
                        count: scanList.items.filter { $0.status == .partial }.count,
                        isSelected: selectedFilter == .partial,
                        action: { selectedFilter = .partial }
                    )
                    
                    PreparationFilterChip(
                        title: "Terminé",
                        count: scanList.items.filter { $0.status == .completed }.count,
                        isSelected: selectedFilter == .completed,
                        action: { selectedFilter = .completed }
                    )
                }
            }
        }
        .padding()
    }
    
    // MARK: - Scan Button
    
    private var scanButton: some View {
        Button(action: { showingScanner = true }) {
            HStack(spacing: 12) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title2)
                Text("Scanner un article")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("Aucun article correspondant")
                .font(.headline)
            
            if selectedFilter != nil || !searchText.isEmpty {
                Button("Réinitialiser les filtres") {
                    selectedFilter = nil
                    searchText = ""
                }
                .font(.subheadline)
            }
        }
        .padding(40)
    }
    
    // MARK: - Helpers
    
    private var statusColor: Color {
        switch scanList.status {
        case .pending: return .gray
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [Color.blue, Color.green],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Actions
    
    private func handleScan(_ result: ScannedAssetResult) {
        // Vérifier le throttling (1 scan par seconde max)
        let now = Date()
        if let lastTime = lastScanTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed < minimumScanInterval {
                print("⏱️ Scan ignoré : trop rapide (\(String(format: "%.2f", elapsed))s)")
                
                // Feedback visuel
                alertTitle = "⏱️ Trop rapide"
                alertMessage = "Attendez 1 seconde entre chaque scan"
                showAlert = true
                return
            }
        }
        
        // Mettre à jour le timestamp
        lastScanTime = now
        
        Task { @MainActor in
            do {
                try scanListService.recordScan(
                    assetId: result.assetId,
                    sku: result.sku,
                    scanList: scanList,
                    allAssets: allAssets,
                    modelContext: modelContext
                )
                
                // Feedback positif
                alertTitle = "✅ Scan réussi"
                alertMessage = "Article scanné avec succès"
                showAlert = true
                
            } catch let error as ScanListError {
                alertTitle = "⚠️ Erreur"
                alertMessage = error.localizedDescription
                showAlert = true
            } catch {
                alertTitle = "❌ Erreur"
                alertMessage = "Erreur lors du scan: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func undoScan(assetId: String, item: PreparationListItem) {
        Task { @MainActor in
            do {
                try scanListService.undoScan(
                    assetId: assetId,
                    sku: item.sku,
                    scanList: scanList,
                    modelContext: modelContext
                )
            } catch {
                alertTitle = "❌ Erreur"
                alertMessage = "Impossible d'annuler: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func resetScanList() {
        Task { @MainActor in
            do {
                try scanListService.resetScanList(scanList, modelContext: modelContext)
                alertTitle = "✅ Réinitialisé"
                alertMessage = "La liste a été réinitialisée"
                showAlert = true
            } catch {
                alertTitle = "❌ Erreur"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    private func deleteScanList() {
        Task { @MainActor in
            do {
                try scanListService.deleteScanList(scanList, modelContext: modelContext)
                dismiss()
            } catch {
                alertTitle = "❌ Erreur"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

// MARK: - Supporting Views

struct PreparationItemRow: View {
    let item: PreparationListItem
    let onTapScan: () -> Void
    let onUndo: (String) -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Icône de statut
                Image(systemName: item.status.icon)
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .frame(width: 30)
                
                // Informations
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(item.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Progression
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(item.quantityScanned)/\(item.quantityRequired)")
                        .font(.headline)
                        .foregroundColor(item.isComplete ? .green : .primary)
                    
                    Text("\(item.progressPercentage)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Bouton expand
                Button(action: { withAnimation { showingDetails.toggle() } }) {
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            // Détails (liste des assets scannés)
            if showingDetails && !item.scannedAssets.isEmpty {
                VStack(spacing: 8) {
                    Divider()
                    
                    ForEach(item.scannedAssets, id: \.self) { assetId in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text(assetId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: { onUndo(assetId) }) {
                                Text("Annuler")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending: return .gray
        case .partial: return .orange
        case .completed: return .green
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(value)
            }
            .font(.headline)
            .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct PreparationFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("(\(count))")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

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
    @Query private var allScanLists: [ScanList]  // 🆕 Pour trouver la liste suivante
    @StateObject private var scanListService = ScanListService()
    
    @Bindable var scanList: ScanList  // 🆕 Utiliser @Bindable pour observer les changements
    
    @State private var showingScanner = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var selectedFilter: ScanItemStatus? = nil
    @State private var searchText = ""
    @State private var nextScanList: ScanList?  // 🆕 Liste suivante pour navigation
    
    // Throttling pour éviter les scans trop rapides
    @State private var lastScanTime: Date?
    private let minimumScanInterval: TimeInterval = 1.0 // 1 seconde entre chaque scan
    
    // 🆕 Trouver la liste suivante du même événement
    private var nextList: ScanList? {
        allScanLists
            .filter { $0.eventId == scanList.eventId && $0.scanListId != scanList.scanListId }
            .filter { $0.status != .completed && $0.status != .cancelled }
            .sorted { $0.createdAt < $1.createdAt }
            .first
    }
    
    private var filteredItems: [PreparationListItem] {
        var items = scanList.items
        
        // 🐛 DEBUG: Afficher le nombre d'items
        if items.isEmpty {
            print("⚠️ [EventScanListView] scanList.items est VIDE pour scanListId: \(scanList.scanListId)")
            print("   - eventId: \(scanList.eventId)")
            print("   - totalItems: \(scanList.totalItems)")
        } else {
            print("✅ [EventScanListView] \(items.count) items trouvés pour scanListId: \(scanList.scanListId)")
        }
        
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
                            },
                            onManualIncrement: {
                                manualIncrement(item: item)
                            },
                            onManualDecrement: {
                                manualDecrement(item: item)
                            }
                        )
                    }
                    
                    if filteredItems.isEmpty {
                        emptyState
                    }
                }
                .padding()
            }
            
            // Boutons d'action
            if !scanList.isComplete {
                VStack(spacing: 12) {
                    scanButton
                    
                    // ✅ Bouton de validation pour forcer la sauvegarde
                    if scanList.scannedItems > 0 {
                        validateButton
                    }
                }
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
            ScannerSheetView(
                scanList: scanList,
                onScanComplete: { result in
                    handleScan(result)
                },
                onDismiss: {
                    showingScanner = false
                }
            )
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .navigationDestination(item: $nextScanList) { scanList in
            EventScanListView(scanList: scanList)
        }
        .onAppear {
            print("🔍 [EventScanListView] onAppear - État initial:")
            print("   - scanListId: \(scanList.scanListId)")
            print("   - eventName: \(scanList.eventName)")
            print("   - direction: \(scanList.scanDirection.displayName)")
            print("   - status: \(scanList.status.displayName)")
            print("   - scannedItems: \(scanList.scannedItems)")
            print("   - totalItems: \(scanList.totalItems)")
            print("   - progress: \(scanList.progressPercentage)%")
            print("   - isComplete: \(scanList.isComplete)")
            print("   - items.count: \(scanList.items.count)")
            
            refreshScanListStatus()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Titre et statut
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(scanList.eventName)
                        .font(.headline)
                    
                    // Badge de statut amélioré
                    HStack(spacing: 6) {
                        Image(systemName: scanList.status.icon)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(scanList.status.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(scanList.isComplete ? .white : statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(scanList.isComplete ? Color.green : statusColor.opacity(0.15))
                    )
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(scanList.scannedItems) / \(scanList.totalItems)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(scanList.isComplete ? .green : .primary)
                    
                    Text("\(scanList.progressPercentage)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(scanList.isComplete ? .green : .secondary)
                }
            }
            
            // Barre de progression OU Bouton de navigation si terminé
            // 🐛 FIX: Double vérification pour éviter l'affichage erroné avec liste vide
            if scanList.isComplete && scanList.totalItems > 0 && !scanList.items.isEmpty {
                // 🆕 Liste terminée : afficher le bouton de navigation
                completionActionButton
            } else {
                // En cours : afficher la barre de progression
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
        .padding(.horizontal)
    }
    
    /// ✅ Bouton pour valider et sauvegarder la progression du scan
    private var validateButton: some View {
        Button(action: {
            // Forcer la sauvegarde
            do {
                try modelContext.save()
                print("✅ [EventScanList] Sauvegarde manuelle réussie")
                print("   - Liste: \(scanList.displayName)")
                print("   - Scannés: \(scanList.scannedItems)/\(scanList.totalItems)")
                print("   - Complète: \(scanList.isComplete)")
                
                // Afficher une alerte de confirmation
                alertTitle = "✅ Sauvegarde réussie"
                alertMessage = "\(scanList.scannedItems) article(s) scanné(s) ont été sauvegardés."
                showAlert = true
            } catch {
                print("❌ [EventScanList] Erreur sauvegarde: \(error)")
                alertTitle = "❌ Erreur"
                alertMessage = "Impossible de sauvegarder: \(error.localizedDescription)"
                showAlert = true
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                Text("Valider le scan (\(scanList.scannedItems))")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .padding(.horizontal)
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
        
        print("🔍 [EventScanListView] handleScan - Début")
        print("   - AssetId: \(result.assetId)")
        print("   - SKU: \(result.sku)")
        print("   - Liste avant scan: \(scanList.scannedItems)/\(scanList.totalItems)")
        
        Task { @MainActor in
            do {
                // Enregistrer le scan
                try scanListService.recordScan(
                    assetId: result.assetId,
                    sku: result.sku,
                    scanList: scanList,
                    allAssets: allAssets,
                    modelContext: modelContext
                )
                
                print("✅ [EventScanListView] Scan enregistré avec succès")
                print("   - Liste après scan: \(scanList.scannedItems)/\(scanList.totalItems)")
                print("   - Statut liste: \(scanList.status.displayName)")
                print("   - isComplete: \(scanList.isComplete)")
                
                // Feedback positif adapté selon le statut
                if scanList.isComplete {
                    alertTitle = "🎉 Liste complète !"
                    alertMessage = "Tous les articles ont été scannés"
                } else {
                    alertTitle = "✅ Scan réussi"
                    alertMessage = "Article scanné (\(scanList.scannedItems)/\(scanList.totalItems))"
                }
                showAlert = true
                
            } catch let error as ScanListError {
                print("⚠️ [EventScanListView] Erreur scan: \(error.localizedDescription)")
                alertTitle = "⚠️ Erreur"
                alertMessage = error.localizedDescription
                showAlert = true
            } catch {
                print("❌ [EventScanListView] Erreur inattendue: \(error.localizedDescription)")
                alertTitle = "❌ Erreur"
                alertMessage = "Erreur lors du scan: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func undoScan(assetId: String, item: PreparationListItem) {
        print("🔄 [EventScanListView] undoScan - Début")
        print("   - AssetId: \(assetId)")
        print("   - Item: \(item.name)")
        
        Task { @MainActor in
            do {
                try scanListService.undoScan(
                    assetId: assetId,
                    sku: item.sku,
                    scanList: scanList,
                    modelContext: modelContext
                )
                
                print("✅ [EventScanListView] Scan annulé avec succès")
                print("   - Liste après annulation: \(scanList.scannedItems)/\(scanList.totalItems)")
                print("   - Statut liste: \(scanList.status.displayName)")
                
            } catch {
                print("❌ [EventScanListView] Erreur annulation: \(error.localizedDescription)")
                alertTitle = "❌ Erreur"
                alertMessage = "Impossible d'annuler: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    // ✅ Validation manuelle : incrémenter la quantité sans scanner
    private func manualIncrement(item: PreparationListItem) {
        print("➕ [EventScanListView] manualIncrement - Item: \(item.name)")
        
        guard item.quantityScanned < item.quantityRequired else {
            print("⚠️ Quantité maximale atteinte")
            return
        }
        
        Task { @MainActor in
            do {
                try scanListService.manualIncrement(
                    sku: item.sku,
                    scanList: scanList,
                    modelContext: modelContext
                )
                
                print("✅ [EventScanListView] Quantité incrémentée: \(item.quantityScanned)/\(item.quantityRequired)")
                
            } catch {
                print("❌ [EventScanListView] Erreur incrémentation: \(error.localizedDescription)")
                alertTitle = "❌ Erreur"
                alertMessage = "Impossible d'incrémenter: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    // ✅ Validation manuelle : décrémenter la quantité
    private func manualDecrement(item: PreparationListItem) {
        print("➖ [EventScanListView] manualDecrement - Item: \(item.name)")
        
        guard item.quantityScanned > 0 else {
            print("⚠️ Quantité minimale atteinte")
            return
        }
        
        Task { @MainActor in
            do {
                try scanListService.manualDecrement(
                    sku: item.sku,
                    scanList: scanList,
                    modelContext: modelContext
                )
                
                print("✅ [EventScanListView] Quantité décrémentée: \(item.quantityScanned)/\(item.quantityRequired)")
                
            } catch {
                print("❌ [EventScanListView] Erreur décrémentation: \(error.localizedDescription)")
                alertTitle = "❌ Erreur"
                alertMessage = "Impossible de décrémenter: \(error.localizedDescription)"
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
    
    private func refreshScanListStatus() {
        Task { @MainActor in
            do {
                try scanListService.refreshScanListStatus(scanList, modelContext: modelContext)
            } catch {
                print("⚠️ [EventScanListView] Erreur refresh status: \(error.localizedDescription)")
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
    
    /// ✅ Marque la liste comme complétée et met à jour le statut de l'événement
    private func markListAsCompleted() {
        scanList.status = .completed
        scanList.completedAt = Date()
        
        // Sauvegarder
        do {
            try modelContext.save()
            print("✅ [EventScanList] Liste marquée comme complétée: \(scanList.displayName)")
            
            // ✅ Mettre à jour le statut de l'événement
            updateEventStatus()
        } catch {
            print("❌ [EventScanList] Erreur sauvegarde: \(error)")
        }
    }
    
    /// ✅ Met à jour le statut de l'événement selon la liste complétée
    private func updateEventStatus() {
        // Récupérer l'événement
        let eventId = scanList.eventId
        let fetchDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.eventId == eventId }
        )
        
        guard let event = try? modelContext.fetch(fetchDescriptor).first else {
            print("❌ [EventScanList] Événement non trouvé")
            return
        }
        
        // Mettre à jour le statut selon la direction de scan
        switch scanList.scanDirection {
        case .stockToTruck:
            event.logisticsStatus = .inTransitToEvent
        case .truckToEvent:
            event.logisticsStatus = .onSite
        case .eventToTruck:
            event.logisticsStatus = .inTransitToStock
        case .truckToStock:
            event.logisticsStatus = .returned
        }
        
        event.updatedAt = Date()
        
        do {
            try modelContext.save()
            print("✅ [EventScanList] Statut événement mis à jour: \(event.logisticsStatus)")
        } catch {
            print("❌ [EventScanList] Erreur mise à jour événement: \(error)")
        }
    }
    
    // MARK: - Completion Action Button
    
    private var completionActionButton: some View {
        VStack(spacing: 16) {
            // Message de félicitations avec animation
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                
                Text("Liste complète !")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("Tous les articles ont été scannés")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.green.opacity(0.1))
            )
            
            // Bouton d'action
            if let next = nextList {
                // Il y a une liste suivante
                Button {
                    // ✅ Marquer la liste actuelle comme complétée
                    markListAsCompleted()
                    // Naviguer vers la prochaine liste
                    nextScanList = next
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Passer à la liste suivante")
                                .font(.headline)
                            Text(next.displayName)
                                .font(.caption)
                                .opacity(0.8)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                }
            } else {
                // ✅ Pas de liste suivante, proposer de voir les autres listes
                // Cliquable uniquement quand la liste est complétée ET sauvegardée
                Button(action: {
                    // ✅ Marquer la liste comme complétée avant de fermer
                    markListAsCompleted()
                    dismiss() // Retour à la liste des événements
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.title3)
                        
                        Text("Voir les autres listes")
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Supporting Views

struct PreparationItemRow: View {
    let item: PreparationListItem
    let onTapScan: () -> Void
    let onUndo: (String) -> Void
    let onManualIncrement: () -> Void  // ✅ Callback pour incrémenter manuellement
    let onManualDecrement: () -> Void  // ✅ Callback pour décrémenter manuellement
    
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
                
                // ✅ Boutons de validation manuelle +/-
                HStack(spacing: 8) {
                    Button(action: onManualDecrement) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(item.quantityScanned > 0 ? .orange : .gray.opacity(0.3))
                    }
                    .disabled(item.quantityScanned == 0)
                    .buttonStyle(.plain)
                    
                    // Progression
                    VStack(alignment: .center, spacing: 4) {
                        Text("\(item.quantityScanned)/\(item.quantityRequired)")
                            .font(.headline)
                            .foregroundColor(item.isComplete ? .green : .primary)
                        
                        Text("\(item.progressPercentage)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 60)
                    
                    Button(action: onManualIncrement) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(item.quantityScanned < item.quantityRequired ? .green : .gray.opacity(0.3))
                    }
                    .disabled(item.quantityScanned >= item.quantityRequired)
                    .buttonStyle(.plain)
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

// MARK: - Scanner Sheet View

/// Vue helper pour le scanner avec accès aux assets via @Query
private struct ScannerSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAssets: [Asset]
    
    let scanList: ScanList
    let onScanComplete: (ScannedAssetResult) -> Void
    let onDismiss: () -> Void
    
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            ModernQRScannerView(
                isScanning: .constant(false),
                isTorchOn: .constant(false),
                onCodeScanned: { code in
                    handleScan(code)
                },
                onShowList: {
                    onDismiss()
                }
            )
            .navigationTitle("Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        onDismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func handleScan(_ code: String) {
        var foundAsset: Asset? = nil
        
        for asset in allAssets {
            if asset.qrPayload == code {
                foundAsset = asset
                break
            }
        }
        
        if let asset = foundAsset {
            let result = ScannedAssetResult(
                assetId: asset.assetId,
                sku: asset.sku
            )
            onScanComplete(result)
            onDismiss()
        } else {
            alertTitle = "Article inconnu"
            alertMessage = "Le QR code scanné ne correspond à aucun article"
            showAlert = true
        }
    }
}

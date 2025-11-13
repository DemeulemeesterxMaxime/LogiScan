//
//  ScanListBrowserView.swift
//  LogiScan
//
//  Created by Copilot on 17/10/2025.
//

import SwiftUI
import SwiftData

/// Vue pour parcourir tous les événements et leurs listes de scan
struct ScanListBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Event.startDate, order: .reverse) private var allEvents: [Event]
    @Query(sort: \ScanList.createdAt, order: .reverse) private var allScanLists: [ScanList]
    
    @StateObject private var scanListService = ScanListService()
    
    @State private var searchText = ""
    @State private var selectedFilter: ScanListStatus? = nil
    @State private var expandedEventIds: Set<String> = []
    
    // Événements filtrés
    private var filteredEvents: [Event] {
        var events = allEvents
        
        // Filtre par recherche
        if !searchText.isEmpty {
            events = events.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.clientName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Garder uniquement les événements qui ont des listes
        events = events.filter { event in
            !scanListsForEvent(event.eventId).isEmpty
        }
        
        return events
    }
    
    // Récupère les listes d'un événement
    private func scanListsForEvent(_ eventId: String) -> [ScanList] {
        var lists = allScanLists.filter { $0.eventId == eventId }
        
        // Filtre par statut si sélectionné
        if let filter = selectedFilter {
            lists = lists.filter { $0.status == filter }
        }
        
        return lists
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Barre de recherche et filtres
                searchAndFiltersView
                
                Divider()
                
                // Liste des événements et leurs listes
                if filteredEvents.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredEvents) { event in
                                EventScanListsCard(
                                    event: event,
                                    scanLists: scanListsForEvent(event.eventId),
                                    isExpanded: expandedEventIds.contains(event.eventId),
                                    onToggleExpand: {
                                        toggleEventExpansion(event.eventId)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Gestion des listes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshAllScanListStatuses()
            }
            .refreshable {
                await refreshAllScanListStatusesAsync()
            }
        }
    }
    
    // MARK: - Search and Filters View
    
    private var searchAndFiltersView: some View {
        VStack(spacing: 12) {
            // Barre de recherche
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Rechercher un événement...", text: $searchText)
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
            
            // Filtres par statut
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    StatusFilterChip(
                        title: "Toutes",
                        isSelected: selectedFilter == nil,
                        count: allScanLists.count
                    ) {
                        selectedFilter = nil
                    }
                    
                    StatusFilterChip(
                        title: "En attente",
                        isSelected: selectedFilter == .pending,
                        count: allScanLists.filter { $0.status == .pending }.count,
                        color: .gray
                    ) {
                        selectedFilter = .pending
                    }
                    
                    StatusFilterChip(
                        title: "En cours",
                        isSelected: selectedFilter == .inProgress,
                        count: allScanLists.filter { $0.status == .inProgress }.count,
                        color: .orange
                    ) {
                        selectedFilter = .inProgress
                    }
                    
                    StatusFilterChip(
                        title: "Terminées",
                        isSelected: selectedFilter == .completed,
                        count: allScanLists.filter { $0.status == .completed }.count,
                        color: .green
                    ) {
                        selectedFilter = .completed
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "list.clipboard" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty ? "Aucune liste de scan" : "Aucun résultat")
                .font(.headline)
            
            if searchText.isEmpty {
                Text("Créez des événements et générez des listes de scan pour commencer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("Essayez un autre terme de recherche")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Toggle Event Expansion
    
    private func toggleEventExpansion(_ eventId: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedEventIds.contains(eventId) {
                expandedEventIds.remove(eventId)
            } else {
                expandedEventIds.insert(eventId)
            }
        }
    }
    
    // MARK: - Refresh All Scan List Statuses
    
    private func refreshAllScanListStatuses() {
        Task {
            await fetchAndRefreshAllScanLists()
        }
    }
    
    private func refreshAllScanListStatusesAsync() async {
        await fetchAndRefreshAllScanLists()
    }
    
    /// Fetch les ScanLists depuis Firebase pour tous les événements puis rafraîchit les statuts
    private func fetchAndRefreshAllScanLists() async {
        print("📥 [ScanListBrowserView] Synchronisation des listes depuis Firebase...")
        
        // Récupérer tous les événements qui ont des listes
        let eventsWithLists = Set(allScanLists.map { $0.eventId })
        
        // Fetch depuis Firebase pour chaque événement
        for eventId in eventsWithLists {
            // Trouver l'Event complet pour accéder aux QuoteItems
            guard let event = allEvents.first(where: { $0.eventId == eventId }) else {
                print("⚠️ [ScanListBrowserView] Event non trouvé: \(eventId)")
                continue
            }
            
            do {
                // Récupérer les QuoteItems depuis SwiftData
                let currentEventId = eventId  // Capture locale pour le prédicat
                let quoteItemsDescriptor = FetchDescriptor<QuoteItem>(
                    predicate: #Predicate { $0.eventId == currentEventId }
                )
                let quoteItems = try modelContext.fetch(quoteItemsDescriptor)
                
                let _ = try await scanListService.fetchScanListsFromFirebase(
                    forEvent: event,
                    quoteItems: quoteItems,
                    modelContext: modelContext
                )
                print("✅ [ScanListBrowserView] Listes synchronisées pour événement: \(event.name)")
            } catch {
                print("⚠️ [ScanListBrowserView] Erreur sync Firebase pour \(event.name): \(error.localizedDescription)")
            }
        }
        
        // Rafraîchir les statuts localement après le fetch
        await MainActor.run {
            for scanList in allScanLists {
                do {
                    try scanListService.refreshScanListStatus(scanList, modelContext: modelContext)
                } catch {
                    print("⚠️ [ScanListBrowserView] Erreur refresh \(scanList.scanListId): \(error.localizedDescription)")
                }
            }
            print("✅ [ScanListBrowserView] \(allScanLists.count) listes rafraîchies")
        }
    }
}

// MARK: - Status Filter Chip

struct StatusFilterChip: View {
    let title: String
    let isSelected: Bool
    var count: Int = 0
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? .white : color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? color.opacity(0.3) : color.opacity(0.15))
                        )
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Scan Lists Card

struct EventScanListsCard: View {
    @Environment(\.modelContext) private var modelContext
    
    let event: Event
    let scanLists: [ScanList]
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    
    @State private var selectedList: ScanList?
    @State private var showManagementView = false
    
    private var totalProgress: Double {
        guard !scanLists.isEmpty else { return 0 }
        let totalItems = scanLists.reduce(0) { $0 + $1.totalItems }
        let scannedItems = scanLists.reduce(0) { $0 + $1.scannedItems }
        guard totalItems > 0 else { return 0 }
        return Double(scannedItems) / Double(totalItems)
    }
    
    private var statusColor: Color {
        if scanLists.allSatisfy({ $0.status == .completed }) {
            return .green
        } else if scanLists.contains(where: { $0.status == .inProgress }) {
            return .orange
        } else {
            return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête de l'événement
            Button(action: onToggleExpand) {
                HStack(spacing: 12) {
                    // Icône d'expansion
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(statusColor)
                    
                    // Infos événement
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 8) {
                            Label(event.clientName, systemImage: "person.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("•")
                                .foregroundStyle(.secondary)
                            
                            Text(event.startDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Badge du nombre de listes
                    VStack(spacing: 4) {
                        Text("\(scanLists.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(statusColor)
                        
                        Text(scanLists.count > 1 ? "listes" : "liste")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            // Barre de progression globale
            if !scanLists.isEmpty {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(statusColor)
                            .frame(width: geometry.size.width * totalProgress)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal)
            }
            
            // Liste des listes de scan (si expansé)
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(scanLists) { scanList in
                        ScanListMiniCard(
                            scanList: scanList,
                            onTap: {
                                selectedList = scanList
                                showManagementView = true
                            }
                        )
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground).opacity(0.3))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showManagementView) {
            if let list = selectedList {
                ScanListManagementView(scanList: list)
            }
        }
    }
}

// MARK: - Scan List Mini Card

struct ScanListMiniCard: View {
    let scanList: ScanList
    let onTap: () -> Void
    
    private var progressPercentage: Double {
        guard scanList.totalItems > 0 else { return 0 }
        return Double(scanList.scannedItems) / Double(scanList.totalItems)
    }
    
    private var statusColor: Color {
        switch scanList.status {
        case .pending: return .gray
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icône de statut
                Image(systemName: scanList.status.icon)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .frame(width: 32)
                
                // Infos liste
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(scanList.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(scanList.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(statusColor.opacity(0.15))
                            )
                    }
                    
                    // Progression
                    HStack(spacing: 4) {
                        Text("\(scanList.scannedItems)/\(scanList.totalItems)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(scanList.isComplete ? .green : .orange)
                        
                        Text("items_count".localized())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("\(Int(progressPercentage * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(statusColor)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Event.self, ScanList.self, PreparationListItem.self,
            configurations: config
        )
        
        // Créer des événements de test
        let event1 = Event(
            eventId: "evt1",
            name: "Mariage Sophie & Marc",
            clientName: "Sophie Dubois",
            clientPhone: "+33123456789",
            clientEmail: "sophie@example.com",
            clientAddress: "Paris",
            eventAddress: "Château de Versailles",
            setupStartTime: Date(),
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400)
        )
        
        let event2 = Event(
            eventId: "evt2",
            name: "Festival LBR 2025",
            clientName: "Association LBR",
            clientPhone: "+33987654321",
            clientEmail: "contact@lbr.com",
            clientAddress: "Lyon",
            eventAddress: "Parc des Expositions",
            setupStartTime: Date().addingTimeInterval(86400 * 7),
            startDate: Date().addingTimeInterval(86400 * 7),
            endDate: Date().addingTimeInterval(86400 * 10)
        )
        
        container.mainContext.insert(event1)
        container.mainContext.insert(event2)
        
        // Créer des listes de test
        let list1 = ScanList(
            eventId: "evt1",
            eventName: "Mariage Sophie & Marc",
            scanDirection: .stockToTruck,
            totalItems: 100,
            scannedItems: 75,
            status: .inProgress
        )
        
        let list2 = ScanList(
            eventId: "evt1",
            eventName: "Mariage Sophie & Marc",
            scanDirection: .truckToEvent,
            totalItems: 50,
            scannedItems: 50,
            status: .completed
        )
        
        let list3 = ScanList(
            eventId: "evt2",
            eventName: "Festival LBR 2025",
            scanDirection: .eventToTruck,
            totalItems: 200,
            scannedItems: 20,
            status: .inProgress
        )
        
        container.mainContext.insert(list1)
        container.mainContext.insert(list2)
        container.mainContext.insert(list3)
        
        return container
    }()
    
    ScanListBrowserView()
        .modelContainer(container)
}

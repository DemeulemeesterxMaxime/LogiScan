//
//  EventSelectionView.swift
//  LogiScan
//
//  Created by Copilot on 15/10/2025.
//

import SwiftUI
import SwiftData

/// Vue pour sélectionner l'événement et la phase de scan
struct EventSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: EventSelectionViewModel
    
    let onSelectPhase: (Event, ScanMode, ScanList?) -> Void
    
    init(onSelectPhase: @escaping (Event, ScanMode, ScanList?) -> Void) {
        self.onSelectPhase = onSelectPhase
        // ViewModel sera initialisé dans onAppear avec le modelContext
        self._viewModel = StateObject(wrappedValue: EventSelectionViewModel())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient de fond
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if viewModel.isLoading {
                            ProgressView("Chargement des événements...")
                                .padding(.top, 100)
                        } else if viewModel.events.isEmpty {
                            emptyStateView
                        } else {
                            eventsListView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Sélectionner un événement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
            .task {
                viewModel.loadEvents(modelContext: modelContext)
            }
            .alert("Erreur", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("no_event".localized())
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Créez un événement avec des devis finalisés pour commencer le scan")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 100)
    }
    
    // MARK: - Events List
    
    private var eventsListView: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.events) { event in
                EventCard(
                    event: event,
                    scanLists: viewModel.scanLists[event.eventId] ?? [],
                    onPhaseSelected: { phase in
                        handlePhaseSelection(event: event, phase: phase)
                    },
                    modelContext: modelContext
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func handlePhaseSelection(event: Event, phase: ScanMode) {
        // Récupérer la ScanList correspondante pour cet événement et cette phase
        let scanList = viewModel.scanLists[event.eventId]?.first
        
        // Appeler le callback avec la ScanList
        onSelectPhase(event, phase, scanList)
        dismiss()
    }
}

// MARK: - Event Card

struct EventCard: View {
    let event: Event
    let scanLists: [ScanList]
    let onPhaseSelected: (ScanMode) -> Void
    let modelContext: ModelContext
    
    @State private var isExpanded = false
    @State private var isCreatingList = false
    @State private var showCreateSuccess = false
    @State private var createError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En-tête
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack {
                            Image(systemName: "calendar")
                            Text(event.startDate, style: .date)
                            
                            if scanLists.isEmpty {
                                Text("• Aucune liste")
                                    .foregroundStyle(.orange)
                            } else {
                                Text("• \(scanLists.count) liste(s)")
                                    .foregroundStyle(.green)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            
            // Message si aucune liste
            if isExpanded && scanLists.isEmpty {
                Divider()
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        
                        Text("Aucune liste de préparation pour cet événement")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: createScanList) {
                        HStack {
                            if isCreatingList {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text(isCreatingList ? "Création..." : "Créer la liste")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isCreatingList)
                }
                .padding()
            }
            
            // Phases de scan
            if isExpanded && !scanLists.isEmpty {
                Divider()
                
                VStack(spacing: 0) {
                    ForEach(availablePhases, id: \.rawValue) { phase in
                        PhaseRow(
                            phase: phase,
                            scanList: scanLists.first,
                            onTap: {
                                onPhaseSelected(phase)
                            }
                        )
                        
                        if phase != availablePhases.last {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .alert("Liste créée", isPresented: $showCreateSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("La liste de préparation a été créée avec succès")
        }
        .alert("Erreur", isPresented: .constant(createError != nil)) {
            Button("OK", role: .cancel) {
                createError = nil
            }
        } message: {
            if let error = createError {
                Text(error)
            }
        }
    }
    
    private var availablePhases: [ScanMode] {
        [.stockToTruck, .truckToEvent, .eventToTruck, .truckToStock]
    }
    
    private func createScanList() {
        Task { @MainActor in
            isCreatingList = true
            defer { isCreatingList = false }
            
            do {
                print("🔍 DEBUG: Début création ScanList pour event: \(event.name) (ID: \(event.eventId))")
                
                // Récupérer les articles du devis
                let eventId = event.eventId
                let descriptor = FetchDescriptor<QuoteItem>(
                    predicate: #Predicate<QuoteItem> { item in
                        item.eventId == eventId
                    }
                )
                
                let quoteItems = try modelContext.fetch(descriptor)
                print("📦 DEBUG: Trouvé \(quoteItems.count) QuoteItems")
                
                if !quoteItems.isEmpty {
                    for item in quoteItems {
                        print("   - \(item.name) (SKU: \(item.sku), Qty: \(item.quantity))")
                    }
                }
                
                guard !quoteItems.isEmpty else {
                    let errorMsg = "Aucun article dans le devis pour cet événement (eventId: \(eventId))"
                    print("❌ DEBUG: \(errorMsg)")
                    createError = errorMsg
                    return
                }
                
                // Créer la liste
                print("🔨 DEBUG: Appel generateScanList...")
                let scanListService = ScanListService()
                let newList = try scanListService.generateAllScanLists(
                    from: event,
                    quoteItems: quoteItems,
                    modelContext: modelContext
                ).first!
                
                print("✅ DEBUG: ScanList créée avec succès!")
                print("   - ID: \(newList.scanListId)")
                print("   - Items: \(newList.totalItems)")
                
                showCreateSuccess = true
                
                // Recharger après un court délai
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
            } catch {
                let errorMsg = "Erreur lors de la création: \(error.localizedDescription)"
                print("❌ DEBUG: \(errorMsg)")
                print("   Details: \(error)")
                createError = errorMsg
            }
        }
    }
}

// MARK: - Phase Row

struct PhaseRow: View {
    let phase: ScanMode
    let scanList: ScanList?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icône
                ZStack {
                    Circle()
                        .fill(phase.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: phase.icon)
                        .foregroundStyle(phase.color)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    if let list = scanList {
                        HStack(spacing: 8) {
                            if list.isComplete {
                                Label("Terminé", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("\(list.scannedItems)/\(list.totalItems)", systemImage: "circle.dashed")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                    } else {
                        Text("not_started".localized())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }
}

// MARK: - ViewModel

@MainActor
class EventSelectionViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var scanLists: [String: [ScanList]] = [:] // eventId -> [ScanList]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let firebaseService = FirebaseService()
    private let scanListService = ScanListService()
    
    func loadEvents(modelContext: ModelContext) {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                print("🔄 DEBUG: Début chargement événements...")
                
                // 1. Charger les événements depuis Firebase
                let raw = try await firebaseService.fetchEvents()
                print("📥 DEBUG: Reçu \(raw.count) événements bruts de Firebase")
                
                // 2. Convertir en Event
                var loaded: [Event] = []
                for (index, dict) in raw.enumerated() {
                    print("   📄 Event \(index + 1):")
                    print("      - eventId: \(dict["eventId"] ?? "N/A")")
                    print("      - name: \(dict["name"] ?? "N/A")")
                    print("      - status: \(dict["status"] ?? "N/A")")
                    
                    // Convertir les dates en timestamps Unix pour JSON
                    var cleanDict = dict
                    for (key, value) in dict {
                        if let date = value as? Date {
                            // Convertir en timestamp Unix (secondes depuis 1970)
                            cleanDict[key] = date.timeIntervalSince1970
                        }
                    }
                    
                    do {
                        let data = try JSONSerialization.data(withJSONObject: cleanDict, options: [])
                        
                        // Configurer le decoder pour lire les timestamps
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .secondsSince1970
                        
                        let fs = try decoder.decode(FirestoreEvent.self, from: data)
                        loaded.append(fs.toEvent())
                        print("      ✅ Converti avec succès")
                    } catch {
                        print("      ❌ Échec de conversion: \(error)")
                        if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .keyNotFound(let key, _):
                                print("         Clé manquante: \(key.stringValue)")
                            case .typeMismatch(let type, let context):
                                print("         Type incompatible: \(type) pour \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                            case .valueNotFound(let type, let context):
                                print("         Valeur null: \(type) pour \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                            case .dataCorrupted(let context):
                                print("         Données corrompues: \(context.debugDescription)")
                            @unknown default:
                                print("         Erreur inconnue")
                            }
                        }
                        
                        // Afficher les clés disponibles vs attendues
                        print("         Clés dans Firebase:")
                        for key in cleanDict.keys.sorted() {
                            print("            - \(key): \(type(of: cleanDict[key] ?? "nil"))")
                        }
                    }
                }
                
                print("📦 DEBUG: \(loaded.count) événements convertis")
                
                // 3. Filtrer les événements pertinents (devis finalisé)
                events = loaded.filter { event in
                    // Événement disponible si le devis est finalisé
                    event.quoteStatus == .finalized
                }.sorted { $0.startDate < $1.startDate }
                
                print("🎯 DEBUG: \(events.count) événements après filtrage")
                if events.isEmpty {
                    print("⚠️ DEBUG: Aucun événement avec devis finalisé")
                    print("   Tous les statuts trouvés:")
                    for event in loaded {
                        print("   - \(event.name): status=\(event.status.displayName), quote=\(event.quoteStatus)")
                    }
                }
                
                // 4. Charger les ScanLists depuis SwiftData pour chaque événement
                print("🔍 DEBUG: Chargement des ScanLists pour chaque événement...")
                for event in events {
                    let eventId = event.eventId  // Capturer la valeur
                    let descriptor = FetchDescriptor<ScanList>(
                        predicate: #Predicate { $0.eventId == eventId },
                        sortBy: [SortDescriptor(\.createdAt)]
                    )
                    
                    if let lists = try? modelContext.fetch(descriptor) {
                        scanLists[event.eventId] = lists
                        print("   📋 \(event.name): \(lists.count) liste(s) trouvée(s)")
                    } else {
                        scanLists[event.eventId] = []
                        print("   📋 \(event.name): 0 liste")
                    }
                }
                
                print("✅ DEBUG: Chargement terminé avec succès")
                isLoading = false
            } catch {
                print("❌ DEBUG: Erreur lors du chargement: \(error)")
                print("   Details: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EventSelectionView { event, phase, scanList in
        print("Selected: \(event.name) - \(phase.displayName)")
        if let list = scanList {
            print("ScanList: \(list.totalItems) items, \(list.scannedItems) scanned")
        }
    }
    .modelContainer(for: [ScanList.self, PreparationListItem.self])
}

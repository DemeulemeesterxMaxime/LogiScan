//
//  ScanWizardView.swift
//  LogiScan
//
//  Created by Copilot on 16/10/2025.
//

import SwiftUI
import SwiftData

/// Vue wizard pour configurer le scan en 3 étapes
struct ScanWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep: WizardStep = .scanMode
    @State private var selectedMode: ScanMode?
    @State private var selectedTruck: Truck?
    @State private var selectedScanList: ScanList?
    @State private var selectedEvent: Event?
    
    @Query private var trucks: [Truck]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Indicateur de progression
                stepIndicator
                
                Divider()
                
                // Contenu de l'étape actuelle
                ScrollView {
                    currentStepView
                        .padding()
                }
                
                Divider()
                
                // Boutons de navigation
                navigationButtons
                    .padding()
            }
            .navigationTitle(currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Step Indicator
    
    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(WizardStep.allCases, id: \.self) { step in
                HStack(spacing: 8) {
                    // Cercle avec numéro
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 32, height: 32)
                        
                        if step.rawValue < currentStep.rawValue {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(step.rawValue + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(step == currentStep ? .white : .secondary)
                        }
                    }
                    
                    // Label
                    Text(step.shortTitle)
                        .font(.caption)
                        .foregroundStyle(step == currentStep ? .primary : .secondary)
                    
                    // Ligne de connexion
                    if step != WizardStep.allCases.last {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding()
    }
    
    private func stepColor(for step: WizardStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return .green
        } else if step == currentStep {
            return .accentColor
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    // MARK: - Current Step View
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .scanMode:
            scanModeStepView
        case .truck:
            truckStepView
        case .scanList:
            scanListStepView
        }
    }
    
    // MARK: - Step 1: Scan Mode
    
    private var scanModeStepView: some View {
        VStack(spacing: 20) {
            Text("Sélectionnez le mode de scan")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(ScanMode.allCases, id: \.self) { mode in
                ScanModeCard(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMode = mode
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Step 2: Truck
    
    private var truckStepView: some View {
        VStack(spacing: 20) {
            Text("Sélectionnez le camion")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if trucks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "truck.box")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("Aucun camion disponible")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("Créez un camion dans l'onglet Camions")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                ForEach(trucks) { truck in
                    TruckCard(
                        truck: truck,
                        isSelected: selectedTruck?.id == truck.id,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTruck = truck
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Step 3: Scan List
    
    private var scanListStepView: some View {
        VStack(spacing: 20) {
            Text("Sélectionnez l'événement")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            EventSelectionForWizard(
                selectedEvent: $selectedEvent,
                selectedScanList: $selectedScanList,
                modelContext: modelContext
            )
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Bouton Précédent
            if currentStep != .scanMode {
                Button(action: previousStep) {
                    Label("Précédent", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Bouton Suivant/Démarrer
            Button(action: nextStep) {
                Label(nextButtonTitle, systemImage: nextButtonIcon)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? Color.accentColor : Color.gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canProceed)
        }
    }
    
    private var nextButtonTitle: String {
        currentStep == .scanList ? "Démarrer le scan" : "Suivant"
    }
    
    private var nextButtonIcon: String {
        currentStep == .scanList ? "camera.fill" : "chevron.right"
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .scanMode:
            return selectedMode != nil
        case .truck:
            return selectedTruck != nil
        case .scanList:
            return selectedScanList != nil && selectedEvent != nil
        }
    }
    
    // MARK: - Navigation Actions
    
    private func previousStep() {
        withAnimation {
            if currentStep == .truck {
                currentStep = .scanMode
            } else if currentStep == .scanList {
                currentStep = .truck
            }
        }
    }
    
    private func nextStep() {
        withAnimation {
            if currentStep == .scanMode {
                currentStep = .truck
            } else if currentStep == .truck {
                currentStep = .scanList
            } else if currentStep == .scanList {
                // Ouvrir le scanner avec la configuration
                startScanning()
            }
        }
    }
    
    private func startScanning() {
        // TODO: Naviguer vers le scanner avec la configuration
        print("🎯 Configuration complète:")
        print("   Mode: \(selectedMode?.displayName ?? "?")")
        print("   Camion: \(selectedTruck?.name ?? "?")")
        print("   Événement: \(selectedEvent?.name ?? "?")")
        print("   Liste: \(selectedScanList?.items.count ?? 0) articles")
        
        dismiss()
    }
}

// MARK: - Wizard Step Enum

enum WizardStep: Int, CaseIterable {
    case scanMode = 0
    case truck = 1
    case scanList = 2
    
    var title: String {
        switch self {
        case .scanMode: return "Mode de scan"
        case .truck: return "Camion"
        case .scanList: return "Liste de préparation"
        }
    }
    
    var shortTitle: String {
        switch self {
        case .scanMode: return "Mode"
        case .truck: return "Camion"
        case .scanList: return "Liste"
        }
    }
}

// MARK: - Scan Mode Card

struct ScanModeCard: View {
    let mode: ScanMode
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icône
                ZStack {
                    Circle()
                        .fill(mode.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: mode.icon)
                        .font(.title2)
                        .foregroundStyle(mode.color)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Indicateur de sélection
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mode.color.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? mode.color : Color.gray.opacity(0.2), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Truck Card

struct TruckCard: View {
    let truck: Truck
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icône
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "truck.box.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(truck.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 8) {
                        Label(truck.licensePlate, systemImage: "number")
                        
                        Text("• \(Int(truck.maxVolume))m³")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Indicateur de sélection
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Selection for Wizard

struct EventSelectionForWizard: View {
    @Binding var selectedEvent: Event?
    @Binding var selectedScanList: ScanList?
    let modelContext: ModelContext
    
    @StateObject private var viewModel = EventSelectionViewModel()
    @Query private var scanLists: [ScanList]
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView("Chargement des événements...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.events.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.events) { event in
                    let eventLists = scanLists.filter { $0.eventId == event.eventId }
                    EventCardForWizard(
                        event: event,
                        scanLists: eventLists,  // Passer toutes les listes
                        isSelected: selectedEvent?.eventId == event.eventId,
                        modelContext: modelContext,
                        onSelect: { scanList in
                            selectedEvent = event
                            selectedScanList = scanList
                        }
                    )
                }
            }
        }
        .onAppear {
            viewModel.loadEvents(modelContext: modelContext)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("no_event".localized())
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Créez un événement avec un devis finalisé")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Event Card for Wizard

struct EventCardForWizard: View {
    let event: Event
    let scanLists: [ScanList]  // Toutes les listes de l'événement
    let isSelected: Bool
    let modelContext: ModelContext
    let onSelect: (ScanList) -> Void
    
    @State private var isCreatingList = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAllLists = false
    
    // Sélection automatique de la liste appropriée
    private var autoSelectedList: ScanList? {
        // Priorité 1: Liste en cours (non terminée)
        if let inProgress = scanLists.first(where: { !$0.isComplete }) {
            return inProgress
        }
        // Priorité 2: Dernière liste créée
        return scanLists.sorted(by: { $0.createdAt > $1.createdAt }).first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Carte principale
            Button(action: handleTap) {
                HStack(spacing: 16) {
                    // Icône
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 8) {
                            Text(event.startDate, style: .date)
                            
                            if let list = autoSelectedList {
                                Text("• \(list.scannedItems)/\(list.totalItems)")
                                    .foregroundStyle(list.isComplete ? .green : .orange)
                            } else {
                                Text("• Pas de liste")
                                    .foregroundStyle(.red)
                            }
                            
                            // Indicateur de listes multiples
                            if scanLists.count > 1 {
                                Text("• \(scanLists.count) listes")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // État
                    if isCreatingList {
                        ProgressView()
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    } else if autoSelectedList == nil {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.orange.opacity(0.1) : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.orange : Color.gray.opacity(0.2), lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .disabled(isCreatingList)
            
            // Liste dépliable si plusieurs listes
            if scanLists.count > 1 && showAllLists {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    
                    ForEach(scanLists.sorted(by: { $0.createdAt > $1.createdAt })) { list in
                        Button {
                            onSelect(list)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(list.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    
                                    Text("\(list.scannedItems)/\(list.totalItems) articles")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if list.isComplete {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "circle.dashed")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(list.scanListId == autoSelectedList?.scanListId ? Color.orange.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
            
            // Bouton pour afficher toutes les listes
            if scanLists.count > 1 {
                Button {
                    withAnimation {
                        showAllLists.toggle()
                    }
                } label: {
                    HStack {
                        Text(showAllLists ? "Masquer les listes" : "Voir toutes les listes")
                            .font(.caption)
                        Image(systemName: showAllLists ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                    .padding(.vertical, 8)
                }
            }
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleTap() {
        if let list = autoSelectedList {
            onSelect(list)
        } else {
            createScanList()
        }
    }
    
    private func createScanList() {
        Task { @MainActor in
            isCreatingList = true
            defer { isCreatingList = false }
            
            do {
                print("🔍 Recherche des QuoteItems pour eventId: \(event.eventId)")
                
                let eventId = event.eventId
                let descriptor = FetchDescriptor<QuoteItem>(
                    predicate: #Predicate<QuoteItem> { item in
                        item.eventId == eventId
                    }
                )
                
                let quoteItems = try modelContext.fetch(descriptor)
                print("📦 Trouvé \(quoteItems.count) articles pour cet événement")
                
                guard !quoteItems.isEmpty else {
                    errorMessage = "Aucun article dans le devis pour cet événement. Ajoutez des articles au devis."
                    showError = true
                    return
                }
                
                let scanListService = ScanListService()
                let newList = try scanListService.generateAllScanLists(
                    from: event,
                    quoteItems: quoteItems,
                    modelContext: modelContext
                ).first!
                
                print("✅ Liste créée avec succès : \(newList.totalItems) articles")
                onSelect(newList)
                
            } catch {
                print("❌ Erreur création liste: \(error)")
                errorMessage = "Erreur lors de la création: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScanWizardView()
        .modelContainer(for: [Truck.self, QuoteItem.self, ScanList.self])
}

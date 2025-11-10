//
//  ScanModeBanner.swift
//  LogiScan
//
//  Created by Copilot on 16/10/2025.
//

import SwiftUI
import SwiftData

/// Bandeau de sélection du mode de scan en haut de l'écran
struct ScanModeBanner: View {
    @Binding var selectedMode: ScannerMode
    @Binding var selectedEvent: Event?
    @Binding var selectedScanList: ScanList?
    
    let onModeChange: () -> Void
    
    @State private var showEventScanFlow = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Bandeau principal avec les 3 modes
            HStack(spacing: 0) {
                ForEach(ScannerMode.allCases) { mode in
                    modeButton(mode)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .animation(.spring(response: 0.3), value: selectedMode)
        .sheet(isPresented: $showEventScanFlow) {
            EventScanFlowView()
        }
    }
    
    // MARK: - Mode Button
    
    private func modeButton(_ mode: ScannerMode) -> some View {
        Button {
            print("🔄 [ScanModeBanner] Mode sélectionné: \(mode.displayName)")
            selectedMode = mode
            
            if mode != .event {
                // Si on quitte le mode événement, réinitialiser
                selectedEvent = nil
                selectedScanList = nil
                print("   → Événement et liste réinitialisés")
            } else {
                // ✅ Ouvrir le flux en étapes pour sélectionner événement puis liste
                print("   → Ouverture du flux de sélection événement/liste")
                showEventScanFlow = true
            }
            onModeChange()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title3)
                    .foregroundStyle(selectedMode == mode ? .white : mode.color)
                
                Text(mode.displayName)
                    .font(.caption)
                    .fontWeight(selectedMode == mode ? .semibold : .regular)
                    .foregroundStyle(selectedMode == mode ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                selectedMode == mode ? mode.color : Color.clear
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scanner Mode Enum

/// Mode de scan simplifié avec 3 options principales
enum ScannerMode: String, CaseIterable, Identifiable {
    case free = "FREE"
    case inventory = "INVENTORY"
    case event = "EVENT"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .free:
            return "Libre"
        case .inventory:
            return "Inventaire"
        case .event:
            return "Événement"
        }
    }
    
    var icon: String {
        switch self {
        case .free:
            return "qrcode.viewfinder"
        case .inventory:
            return "list.clipboard"
        case .event:
            return "calendar.badge.checkmark"
        }
    }
    
    var color: Color {
        switch self {
        case .free:
            return .blue
        case .inventory:
            return .purple
        case .event:
            return .orange
        }
    }
    
    var description: String {
        switch self {
        case .free:
            return "Scanner librement pour consulter les détails"
        case .inventory:
            return "Compter et vérifier le stock"
        case .event:
            return "Scanner selon la liste de préparation"
        }
    }
}

// MARK: - Event Picker for Scanner

struct EventPickerForScanner: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedEvent: Event?
    @Binding var selectedScanList: ScanList?
    
    let onSelect: () -> Void
    
    @StateObject private var viewModel = EventSelectionViewModel()
    @Query private var scanLists: [ScanList]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView("Chargement...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.events.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.events) { event in
                                let eventLists = scanLists.filter { $0.eventId == event.eventId }
                                EventCardForPicker(
                                    event: event,
                                    scanLists: eventLists,
                                    isSelected: selectedEvent?.eventId == event.eventId,
                                    onSelect: { list in
                                        selectedEvent = event
                                        selectedScanList = list
                                        onSelect()
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Choisir un événement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadEvents(modelContext: modelContext)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Aucun événement disponible")
                .font(.headline)
            
            Text("Créez un événement avec un devis finalisé")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Event Card for Picker

struct EventCardForPicker: View {
    let event: Event
    let scanLists: [ScanList]
    let isSelected: Bool
    let onSelect: (ScanList) -> Void
    
    @State private var showAllLists = false
    
    private var autoSelectedList: ScanList? {
        // Priorité 1: Liste en cours
        if let inProgress = scanLists.first(where: { !$0.isComplete }) {
            return inProgress
        }
        // Priorité 2: Dernière liste
        return scanLists.sorted(by: { $0.createdAt > $1.createdAt }).first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                if let list = autoSelectedList {
                    onSelect(list)
                }
            } label: {
                HStack(spacing: 12) {
                    // Icône
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 8) {
                            Text(event.startDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let list = autoSelectedList {
                                Text("•")
                                Text("\(list.scannedItems)/\(list.totalItems)")
                                    .foregroundStyle(list.isComplete ? .green : .orange)
                            }
                            
                            if scanLists.count > 1 {
                                Text("•")
                                Text("\(scanLists.count) listes")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .font(.caption)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
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
            
            // Listes dépliables
            if scanLists.count > 1 {
                Button {
                    withAnimation {
                        showAllLists.toggle()
                    }
                } label: {
                    HStack {
                        Text(showAllLists ? "Masquer" : "Voir toutes les listes")
                            .font(.caption)
                        Image(systemName: showAllLists ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                    .padding(.vertical, 6)
                }
                
                if showAllLists {
                    VStack(spacing: 8) {
                        ForEach(scanLists.sorted(by: { $0.createdAt > $1.createdAt })) { list in
                            Button {
                                onSelect(list)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(list.displayName)
                                            .font(.subheadline)
                                        
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
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(list.scanListId == autoSelectedList?.scanListId ? Color.orange.opacity(0.05) : Color(.secondarySystemBackground))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var mode: ScannerMode = .free
    @Previewable @State var event: Event? = nil
    @Previewable @State var scanList: ScanList? = nil
    
    ScanModeBanner(
        selectedMode: $mode,
        selectedEvent: $event,
        selectedScanList: $scanList,
        onModeChange: {}
    )
}

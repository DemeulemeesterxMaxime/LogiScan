//
//  EventScanFlowView.swift
//  LogiScan
//
//  Created by Assistant on 07/11/2025.
//  Flux en étapes pour le scan d'événement : Événement → Liste → Scan
//

import SwiftUI
import SwiftData

/// Vue de flux en étapes pour le mode Événement
struct EventScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var events: [Event]
    @Query private var scanLists: [ScanList]
    
    @State private var currentStep: ScanStep = .selectEvent
    @State private var selectedEvent: Event?
    @State private var selectedScanList: ScanList?
    @State private var showScanner = false
    
    enum ScanStep {
        case selectEvent
        case selectList
        case scanning
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient de fond
                LinearGradient(
                    colors: [Color.orange.opacity(0.1), Color.red.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Indicateur d'étapes
                    stepIndicator
                    
                    // Contenu selon l'étape
                    Group {
                        switch currentStep {
                        case .selectEvent:
                            eventSelectionView
                        case .selectList:
                            listSelectionView
                        case .scanning:
                            scanningView
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentStep != .scanning {
                        Button("Annuler") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if currentStep == .selectList && selectedEvent != nil {
                        Button(action: goBack) {
                            Label("Retour", systemImage: "chevron.left")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Step Indicator
    
    private var stepIndicator: some View {
        HStack(spacing: 12) {
            StepDot(isActive: currentStep == .selectEvent, isCompleted: selectedEvent != nil, number: 1)
            StepLine(isActive: selectedEvent != nil)
            StepDot(isActive: currentStep == .selectList, isCompleted: selectedScanList != nil, number: 2)
            StepLine(isActive: selectedScanList != nil)
            StepDot(isActive: currentStep == .scanning, isCompleted: false, number: 3)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Event Selection
    
    private var eventSelectionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if filteredEvents.isEmpty {
                    emptyEventState
                } else {
                    ForEach(filteredEvents) { event in
                        EventSelectionCard(
                            event: event,
                            isSelected: selectedEvent?.eventId == event.eventId,
                            onSelect: {
                                withAnimation(.spring()) {
                                    selectedEvent = event
                                    // Pré-sélectionner la première liste
                                    selectedScanList = availableLists(for: event).first
                                    currentStep = .selectList
                                }
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - List Selection
    
    private var listSelectionView: some View {
        VStack(spacing: 20) {
            if let event = selectedEvent {
                // Info événement
                VStack(spacing: 8) {
                    Text(event.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(event.startDate, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                // Listes disponibles
                ScrollView {
                    VStack(spacing: 12) {
                        let lists = availableLists(for: event)
                        
                        if lists.isEmpty {
                            noListsView
                        } else {
                            ForEach(lists) { list in
                                ScanListSelectionCard(
                                    scanList: list,
                                    isSelected: selectedScanList?.scanListId == list.scanListId,
                                    onSelect: {
                                        withAnimation(.spring()) {
                                            selectedScanList = list
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
                
                // Bouton Suivant
                if selectedScanList != nil {
                    Button(action: startScanning) {
                        HStack {
                            Text("Commencer le scan")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Scanning View
    
    private var scanningView: some View {
        Group {
            if let scanList = selectedScanList {
                EventScanListView(scanList: scanList)
            } else {
                Text("Erreur : Aucune liste sélectionnée")
                    .foregroundStyle(.red)
            }
        }
    }
    
    // MARK: - Empty States
    
    private var emptyEventState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Aucun événement disponible")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Créez un événement avec un devis finalisé pour commencer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private var noListsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Aucune liste de scan")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Générez d'abord les listes de scan pour cet événement")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Helpers
    
    private var stepTitle: String {
        switch currentStep {
        case .selectEvent:
            return "Sélectionner un événement"
        case .selectList:
            return "Choisir une liste"
        case .scanning:
            return "Scanner"
        }
    }
    
    private var filteredEvents: [Event] {
        events.filter { $0.quoteStatus == .finalized }
    }
    
    private func availableLists(for event: Event) -> [ScanList] {
        scanLists
            .filter { $0.eventId == event.eventId }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private func goBack() {
        withAnimation(.spring()) {
            currentStep = .selectEvent
            selectedScanList = nil
        }
    }
    
    private func startScanning() {
        withAnimation(.spring()) {
            currentStep = .scanning
        }
    }
}

// MARK: - Step Components

struct StepDot: View {
    let isActive: Bool
    let isCompleted: Bool
    let number: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.green : (isActive ? Color.orange : Color.gray.opacity(0.3)))
                .frame(width: 36, height: 36)
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(number)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isActive ? .white : .gray)
            }
        }
    }
}

struct StepLine: View {
    let isActive: Bool
    
    var body: some View {
        Rectangle()
            .fill(isActive ? Color.green : Color.gray.opacity(0.3))
            .frame(height: 2)
    }
}

// MARK: - Event Selection Card

struct EventSelectionCard: View {
    let event: Event
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icône
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.orange : Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : .orange)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack {
                        Image(systemName: "calendar")
                        Text(event.startDate, style: .date)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Indicateur sélection
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? .orange.opacity(0.3) : .black.opacity(0.1), radius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scan List Selection Card

struct ScanListSelectionCard: View {
    let scanList: ScanList
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: scanList.scanDirection.icon)
                        .font(.title3)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scanList.scanDirection.displayName)
                            .font(.headline)
                        
                        Text(scanList.scanDirection.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Sélection
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }
                
                // Progression
                HStack {
                    ProgressView(value: scanList.progress)
                        .tint(.orange)
                    
                    Text("\(scanList.progressPercentage)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }
                
                // Stats
                HStack(spacing: 16) {
                    StatItem(icon: "checkmark.circle", value: "\(scanList.scannedItems)", label: "Scannés")
                    StatItem(icon: "circle.dashed", value: "\(scanList.remainingItems)", label: "Restants")
                    
                    Spacer()
                    
                    // Badge statut
                    HStack(spacing: 4) {
                        Image(systemName: scanList.status.icon)
                            .font(.caption2)
                        Text(scanList.status.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.15))
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? .orange.opacity(0.3) : .black.opacity(0.1), radius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var statusColor: Color {
        switch scanList.status {
        case .pending: return .gray
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EventScanFlowView()
        .modelContainer(for: [Event.self, ScanList.self])
}

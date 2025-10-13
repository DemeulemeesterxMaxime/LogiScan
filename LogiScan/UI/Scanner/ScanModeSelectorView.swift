//
//  ScanModeSelectorView.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import SwiftUI
import SwiftData

struct ScanModeSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var trucks: [Truck]
    @Query private var events: [Event]
    
    let onModeSelected: (ScanMode, Truck?, Event?, [Asset]?) -> Void
    
    @State private var selectedMode: ScanMode?
    @State private var selectedTruck: Truck?
    @State private var selectedEvent: Event?
    @State private var showTruckPicker = false
    @State private var showEventPicker = false
    @State private var showAssetPicker = false
    @State private var selectedAssets: [Asset] = []
    
    private var canProceed: Bool {
        guard let mode = selectedMode else { return false }
        
        switch mode {
        case .free, .inventory:
            return true
        case .stockToTruck, .truckToStock:
            return selectedTruck != nil
        case .truckToEvent, .eventToTruck:
            return selectedTruck != nil && selectedEvent != nil
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Mode Grid
                    modesGrid
                    
                    // Context Selection
                    if selectedMode != nil && selectedMode != .free {
                        contextSelection
                    }
                    
                    // Asset List (optional)
                    if canProceed && selectedMode != .free && selectedMode != .inventory {
                        assetListSection
                    }
                    
                    // Start Button
                    if canProceed {
                        startButton
                    }
                }
                .padding()
            }
            .navigationTitle("Mode de Scan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showTruckPicker) {
                TruckPickerSheet(trucks: trucks, selectedTruck: $selectedTruck)
            }
            .sheet(isPresented: $showEventPicker) {
                EventPickerSheet(events: events, selectedEvent: $selectedEvent)
            }
        }
    }
    
    // MARK: - Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Choisissez un mode de scan")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Sélectionnez le type d'opération que vous souhaitez effectuer")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private var modesGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(ScanMode.allCases) { mode in
                ModeCard(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMode = mode
                            
                            // Reset context si changement de mode
                            if mode == .free || mode == .inventory {
                                selectedTruck = nil
                                selectedEvent = nil
                                selectedAssets = []
                            }
                        }
                    }
                )
            }
        }
    }
    
    private var contextSelection: some View {
        VStack(spacing: 16) {
            if selectedMode != .free && selectedMode != .inventory {
                // Sélection du camion
                if needsTruckSelection {
                    ContextSelectionCard(
                        title: "Camion",
                        icon: "truck.box.fill",
                        value: selectedTruck?.displayName ?? "Sélectionner",
                        isSelected: selectedTruck != nil,
                        action: { showTruckPicker = true }
                    )
                }
                
                // Sélection de l'événement
                if needsEventSelection {
                    ContextSelectionCard(
                    title: "Événement",
                    icon: "calendar",
                    value: selectedEvent?.name ?? "Sélectionner",
                    isSelected: selectedEvent != nil,
                    action: { showEventPicker = true }
                )
                }
            }
        }
    }
    
    private var assetListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Liste de scan (optionnel)")
                    .font(.headline)
                
                Spacer()
                
                Text("\(selectedAssets.count) assets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { showAssetPicker = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(selectedAssets.isEmpty ? "Ajouter une liste" : "Modifier la liste")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Text("Ajoutez une liste d'assets attendus pour suivre la progression")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
    
    private var startButton: some View {
        Button(action: {
            guard let mode = selectedMode else { return }
            onModeSelected(
                mode,
                selectedTruck,
                selectedEvent,
                selectedAssets.isEmpty ? nil : selectedAssets
            )
            dismiss()
        }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Démarrer le scan")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedMode?.gradient ?? LinearGradient(colors: [.blue], startPoint: .leading, endPoint: .trailing))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .padding(.top)
    }
    
    // MARK: - Helper Properties
    
    private var needsTruckSelection: Bool {
        guard let mode = selectedMode else { return false }
        return [.stockToTruck, .truckToEvent, .eventToTruck, .truckToStock].contains(mode)
    }
    
    private var needsEventSelection: Bool {
        guard let mode = selectedMode else { return false }
        return [.truckToEvent, .eventToTruck].contains(mode)
    }
}

// MARK: - Mode Card

struct ModeCard: View {
    let mode: ScanMode
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(mode.gradient)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: mode.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    Text(mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(mode.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? mode.color.opacity(0.3) : .black.opacity(0.05), radius: isSelected ? 12 : 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(mode.color, lineWidth: isSelected ? 3 : 0)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Context Selection Card

struct ContextSelectionCard: View {
    let title: String
    let icon: String
    let value: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Picker Sheets

struct TruckPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let trucks: [Truck]
    @Binding var selectedTruck: Truck?
    
    var body: some View {
        NavigationView {
            List(trucks, id: \.truckId) { truck in
                Button(action: {
                    selectedTruck = truck
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(truck.displayName)
                                .font(.headline)
                            Text(truck.licensePlate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedTruck?.truckId == truck.truckId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Sélectionner un camion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

struct EventPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let events: [Event]
    @Binding var selectedEvent: Event?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(events, id: \.eventId) { event in
                    Button(action: {
                        selectedEvent = event
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.name)
                                    .font(.headline)
                                Text(event.startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedEvent?.eventId == event.eventId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sélectionner un événement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScanModeSelectorView(
        onModeSelected: { mode, truck, event, assets in
            print("Mode sélectionné: \(mode.displayName)")
        }
    )
    .modelContainer(for: [Truck.self, Event.self], inMemory: true)
}

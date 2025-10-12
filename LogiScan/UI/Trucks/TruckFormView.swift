//
//  TruckFormView.swift
//  LogiScan
//
//  Created by Demeulemeester on 08/10/2025.
//

import SwiftUI
import SwiftData

struct TruckFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let truck: Truck?
    
    @State private var licensePlate = ""
    @State private var maxVolume: Double = 40.0
    @State private var maxWeight: Double = 3500.0
    @State private var status: TruckStatus = .available
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var isSaving = false
    
    var isEditing: Bool {
        truck != nil
    }
    
    init(truck: Truck? = nil) {
        self.truck = truck
        if let truck = truck {
            _licensePlate = State(initialValue: truck.licensePlate)
            _maxVolume = State(initialValue: truck.maxVolume)
            _maxWeight = State(initialValue: truck.maxWeight)
            _status = State(initialValue: truck.status)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Identification") {
                    HStack {
                        Text("Immatriculation")
                        Spacer()
                        TextField("AB-123-CD", text: $licensePlate)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                            .textCase(.uppercase)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Capacités") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Volume maximum")
                            Spacer()
                            Text(String(format: "%.0f m³", maxVolume))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $maxVolume, in: 10...150, step: 5)
                        
                        HStack {
                            Text("10 m³")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("150 m³")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Poids maximum")
                            Spacer()
                            Text(String(format: "%.0f kg", maxWeight))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $maxWeight, in: 500...15000, step: 100)
                        
                        HStack {
                            Text("500 kg")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("15 000 kg")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Statut") {
                    Picker("Statut du camion", selection: $status) {
                        ForEach(TruckStatus.allCases, id: \.self) { status in
                            HStack {
                                Image(systemName: statusIcon(for: status))
                                Text(status.displayName)
                            }
                            .tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section {
                    VStack(spacing: 12) {
                        // Preview card
                        TruckPreviewCard(
                            licensePlate: licensePlate.isEmpty ? "AB-123-CD" : licensePlate,
                            maxVolume: maxVolume,
                            maxWeight: maxWeight,
                            status: status
                        )
                        
                        Text("Aperçu du camion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(isEditing ? "Modifier le camion" : "Nouveau camion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Enregistrer" : "Créer") {
                        saveTruck()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Enregistrement...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 10)
                        )
                    }
                }
            }
            .alert("Validation", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private func statusIcon(for status: TruckStatus) -> String {
        switch status {
        case .available: return "checkmark.circle.fill"
        case .loading: return "arrow.down.circle.fill"
        case .enRoute: return "arrow.right.circle.fill"
        case .atSite: return "location.circle.fill"
        case .returning: return "arrow.uturn.left.circle.fill"
        case .maintenance: return "wrench.fill"
        }
    }
    
    private func saveTruck() {
        // Validation
        guard !licensePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Veuillez saisir une immatriculation"
            showValidationError = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                let firebaseService = FirebaseService()
                
                if isEditing {
                    // Modifier le camion existant
                    if let truck = truck {
                        truck.licensePlate = licensePlate
                        truck.maxVolume = maxVolume
                        truck.maxWeight = maxWeight
                        truck.status = status
                        truck.updatedAt = Date()
                        
                        // Sauvegarder dans SwiftData
                        try modelContext.save()
                        
                        // Synchroniser immédiatement avec Firebase
                        await firebaseService.updateTruck(truck)
                        
                        print("✅ Camion modifié et synchronisé: \(truck.licensePlate)")
                    }
                } else {
                    // Créer un nouveau camion
                    let newTruck = Truck(
                        truckId: "TRUCK-\(UUID().uuidString.prefix(8))",
                        licensePlate: licensePlate,
                        maxVolume: maxVolume,
                        maxWeight: maxWeight,
                        status: status
                    )
                    modelContext.insert(newTruck)
                    
                    // Sauvegarder dans SwiftData
                    try modelContext.save()
                    
                    // Synchroniser immédiatement avec Firebase
                    await firebaseService.saveTruck(newTruck)
                    
                    print("✅ Nouveau camion créé et synchronisé: \(newTruck.licensePlate)")
                }
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    validationMessage = "Erreur lors de la sauvegarde: \(error.localizedDescription)"
                    showValidationError = true
                }
                print("❌ Erreur sauvegarde camion: \(error)")
            }
        }
    }
}

struct TruckPreviewCard: View {
    let licensePlate: String
    let maxVolume: Double
    let maxWeight: Double
    let status: TruckStatus
    
    var body: some View {
        HStack(spacing: 16) {
            // Icône
            VStack(spacing: 4) {
                Image(systemName: "truck.box")
                    .font(.title)
                    .foregroundColor(status.swiftUIColor)
                
                Text(licensePlate)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(width: 80)
            
            // Infos
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Camion")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(status.swiftUIColor.opacity(0.2))
                        )
                        .foregroundColor(status.swiftUIColor)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Capacité")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.0f kg", maxWeight))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Volume")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.0f m³", maxVolume))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview("Nouveau") {
    TruckFormView()
        .modelContainer(for: [Truck.self], inMemory: true)
}

#Preview("Édition") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Truck.self, configurations: config)
    let truck = Truck(
        truckId: "TRUCK-001",
        licensePlate: "AB-123-CD",
        maxVolume: 40.0,
        maxWeight: 3500.0,
        status: .available
    )
    container.mainContext.insert(truck)
    
    return TruckFormView(truck: truck)
        .modelContainer(container)
}

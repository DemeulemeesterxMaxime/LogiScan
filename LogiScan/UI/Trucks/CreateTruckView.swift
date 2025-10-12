//
//  CreateTruckView.swift
//  LogiScan
//
//  Created by Demeulemeester on 09/10/2025.
//

import SwiftUI
import SwiftData

struct CreateTruckView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var licensePlate = ""
    @State private var name = "" // Nom optionnel du camion
    @State private var maxVolume: Double = 40.0
    @State private var maxWeight: Double = 3500.0
    @State private var status: TruckStatus = .available
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var isSaving = false
    
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
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Nom (optionnel)")
                            Spacer()
                            TextField("Ex: Camion Nord", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                                .multilineTextAlignment(.trailing)
                        }
                        Text("Si renseigné, ce nom remplacera la plaque d'immatriculation dans l'app")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
            }
            .navigationTitle("Nouveau camion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Créer") {
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
        guard !licensePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Veuillez saisir une immatriculation"
            showValidationError = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                let newTruck = Truck(
                    truckId: "TRUCK-\(UUID().uuidString.prefix(8))",
                    licensePlate: licensePlate,
                    name: name.isEmpty ? nil : name,
                    maxVolume: maxVolume,
                    maxWeight: maxWeight,
                    status: status
                )
                modelContext.insert(newTruck)
                
                try modelContext.save()
                
                let firebaseService = FirebaseService()
                await firebaseService.saveTruck(newTruck)
                
                print("✅ Nouveau camion créé et synchronisé: \(newTruck.licensePlate)")
                
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

#Preview {
    CreateTruckView()
        .modelContainer(for: [Truck.self], inMemory: true)
}

//
//  CreateEventView.swift
//  LogiScan
//
//  Created by Demeulemeester on 09/10/2025.
//

import SwiftUI
import SwiftData

struct CreateEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var trucks: [Truck]
    
    // Étape actuelle
    @State private var currentStep: Int = 1
    
    // ÉTAPE 1 : Informations de base (obligatoire)
    @State private var eventName: String = ""
    
    // ÉTAPE 2 : Informations client et événement (optionnel)
    @State private var clientName: String = ""
    @State private var clientPhone: String = ""
    @State private var clientEmail: String = ""
    @State private var clientAddress: String = ""
    @State private var eventAddress: String = ""
    @State private var notes: String = ""
    
    // ÉTAPE 3 : Dates et logistique (optionnel)
    @State private var setupStartTime: Date = Date()
    @State private var startDate: Date = Date().addingTimeInterval(3600) // +1h
    @State private var endDate: Date = Date().addingTimeInterval(86400) // +1 jour
    @State private var selectedTruckId: String? = nil
    @State private var selectedStatus: EventStatus = .planning
    
    // Alerts
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var canProceedFromStep1: Bool {
        !eventName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Indicateur d'étapes
                stepIndicator
                
                // Contenu selon l'étape
                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case 1:
                            step1Content
                        case 2:
                            step2Content
                        case 3:
                            step3Content
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
                
                // Boutons de navigation
                navigationButtons
            }
            .navigationTitle("Nouvel Événement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
            .alert("Erreur", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Step Indicator
    
    private var stepIndicator: some View {
        HStack(spacing: 16) {
            ForEach(1...3, id: \.self) { step in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                        
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.caption.bold())
                        } else {
                            Text("\(step)")
                                .foregroundColor(step == currentStep ? .white : .gray)
                                .font(.caption.bold())
                        }
                    }
                    
                    Text(stepTitle(step))
                        .font(.caption2)
                        .foregroundColor(step == currentStep ? .primary : .secondary)
                }
                
                if step < 3 {
                    Rectangle()
                        .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 2)
    }
    
    private func stepTitle(_ step: Int) -> String {
        switch step {
        case 1: return "Nom"
        case 2: return "Infos"
        case 3: return "Dates"
        default: return ""
        }
    }
    
    // MARK: - Step 1: Nom de l'événement (obligatoire)
    
    private var step1Content: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Nom de l'événement", systemImage: "calendar")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("Le nom est la seule information obligatoire. Vous pourrez compléter les autres détails plus tard.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TextField("Ex: Mariage Dupont, Festival d'été...", text: $eventName)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .padding(.vertical, 4)
            
            if !canProceedFromStep1 && !eventName.isEmpty {
                Text("Le nom ne peut pas être vide")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Step 2: Informations client et événement (optionnel)
    
    private var step2Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Informations Client
            VStack(alignment: .leading, spacing: 12) {
                Label("Informations Client", systemImage: "person.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("Ces informations sont optionnelles")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    FormField(
                        icon: "person",
                        placeholder: "Nom du client",
                        text: $clientName
                    )
                    
                    FormField(
                        icon: "phone",
                        placeholder: "Téléphone",
                        text: $clientPhone,
                        keyboardType: .phonePad
                    )
                    
                    FormField(
                        icon: "envelope",
                        placeholder: "Email",
                        text: $clientEmail,
                        keyboardType: .emailAddress
                    )
                    
                    FormField(
                        icon: "house",
                        placeholder: "Adresse de facturation",
                        text: $clientAddress
                    )
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            // Informations Événement
            VStack(alignment: .leading, spacing: 12) {
                Label("Détails de l'événement", systemImage: "location.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("Informations optionnelles sur le lieu et les détails")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    FormField(
                        icon: "mappin",
                        placeholder: "Adresse de l'événement",
                        text: $eventAddress
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("Notes")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Step 3: Dates et logistique (optionnel)
    
    private var step3Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Dates
            VStack(alignment: .leading, spacing: 12) {
                Label("Dates et horaires", systemImage: "clock.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("Planifiez les horaires de montage et de l'événement")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 16) {
                    DatePickerRow(
                        icon: "hammer",
                        label: "Début du montage",
                        date: $setupStartTime
                    )
                    
                    DatePickerRow(
                        icon: "play.circle",
                        label: "Début de l'événement",
                        date: $startDate
                    )
                    
                    DatePickerRow(
                        icon: "stop.circle",
                        label: "Fin de l'événement",
                        date: $endDate
                    )
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            // Logistique
            VStack(alignment: .leading, spacing: 12) {
                Label("Logistique", systemImage: "truck.box.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("Assignez un camion et définissez le statut")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 16) {
                    // Sélection du camion
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "truck.box")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("Camion assigné")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        
                        Picker("Camion", selection: $selectedTruckId) {
                            Text("Aucun").tag(nil as String?)
                            ForEach(trucks) { truck in
                                Text(truck.displayName).tag(truck.truckId as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(10)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                    }
                    
                    // Sélection du statut
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "flag")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("Statut")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        
                        Picker("Statut", selection: $selectedStatus) {
                            ForEach(EventStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(10)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Bouton Précédent
            if currentStep > 1 {
                Button(action: {
                    withAnimation {
                        currentStep -= 1
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Précédent")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
            }
            
            // Bouton Suivant ou Créer
            Button(action: {
                if currentStep < 3 {
                    if currentStep == 1 && !canProceedFromStep1 {
                        alertMessage = "Veuillez entrer un nom pour l'événement"
                        showAlert = true
                        return
                    }
                    withAnimation {
                        currentStep += 1
                    }
                } else {
                    createEvent()
                }
            }) {
                HStack {
                    Text(currentStep == 3 ? "Créer" : "Suivant")
                    if currentStep < 3 {
                        Image(systemName: "chevron.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(currentStep == 1 && !canProceedFromStep1 ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(currentStep == 1 && !canProceedFromStep1)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: -2)
    }
    
    // MARK: - Create Event
    
    private func createEvent() {
        let newEvent = Event(
            eventId: UUID().uuidString,
            name: eventName.trimmingCharacters(in: .whitespaces),
            clientName: clientName,
            clientPhone: clientPhone,
            clientEmail: clientEmail,
            clientAddress: clientAddress,
            eventAddress: eventAddress,
            setupStartTime: setupStartTime,
            startDate: startDate,
            endDate: endDate,
            status: selectedStatus,
            notes: notes,
            assignedTruckId: selectedTruckId
        )
        
        modelContext.insert(newEvent)
        
        Task {
            do {
                try modelContext.save()
                
                // Synchroniser avec Firebase
                let firebaseService = FirebaseService()
                await firebaseService.saveEvent(newEvent)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Erreur lors de la création: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct FormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

struct DatePickerRow: View {
    let icon: String
    let label: String
    @Binding var date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(label)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            
            DatePicker("", selection: $date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(10)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
        }
    }
}

#Preview {
    CreateEventView()
        .modelContainer(for: [Event.self, Truck.self], inMemory: true)
}

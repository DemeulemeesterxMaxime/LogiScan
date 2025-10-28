//
//  EventDetailView.swift
//  LogiScan
//
//  Created by Demeulemeester on 09/10/2025.
//

import SwiftUI
import SwiftData

struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var trucks: [Truck]
    // ❌ SUPPRIMÉ: @Query private var allQuoteItems: [QuoteItem]
    // Cette Query rendait la vue hyper-réactive et causait des reconstructions intempestives
    
    let event: Event  // ✅ Revenir à l'Event directement mais isoler l'observation
    
    // ✅ Binding depuis le parent pour survivre aux reconstructions
    @Binding var activeQuoteBuilder: String?  // EventID actif dans QuoteBuilder
    
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingQuotePDF = false
    
    // 🔍 LOG: Compteur pour tracer les reconstructions de la vue
    @State private var viewRebuildCount = 0
    
    // ✅ Cache local chargé une seule fois pour hasExistingQuote
    @State private var cachedQuoteItemsCount: Int = 0
    
    // ✅ Computed property pour savoir si QuoteBuilder est actif pour CET event
    private var isShowingQuoteBuilder: Bool {
        get { activeQuoteBuilder == event.eventId }
        nonmutating set {
            if newValue {
                activeQuoteBuilder = event.eventId
            } else {
                if activeQuoteBuilder == event.eventId {
                    activeQuoteBuilder = nil
                }
            }
        }
    }
    
    // États d'édition
    @State private var editedName = ""
    @State private var editedClientName = ""
    @State private var editedClientPhone = ""
    @State private var editedClientEmail = ""
    @State private var editedClientAddress = ""
    @State private var editedEventAddress = ""
    @State private var editedSetupStartTime = Date()
    @State private var editedStartDate = Date()
    @State private var editedEndDate = Date()
    @State private var editedStatus: EventStatus = .planning
    @State private var editedNotes = ""
    @State private var editedAssignedTruckId: String? = nil
    
    var assignedTruck: Truck? {
        guard let truckId = event.assignedTruckId else { return nil }
        return trucks.first { $0.truckId == truckId }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // En-tête
                headerSection
                
                // Informations événement
                eventInfoSection
                
                // Informations client
                clientInfoSection
                
                // Camion assigné
                truckSection
                
                // Statut et notes
                statusSection
                
                // Actions
                if !isEditing {
                    actionsSection
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .navigationDestination(isPresented: Binding(
            get: { isShowingQuoteBuilder },
            set: { isShowingQuoteBuilder = $0 }
        )) {
            QuoteBuilderView(event: event)
        }
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        cancelEditing()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sauvegarder") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Modifier") {
                        startEditing()
                    }
                    .requiresPermission(.writeEvents)
                }
            }
        }
        .confirmationDialog(
            "Êtes-vous sûr de vouloir supprimer cet événement ?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                deleteEvent()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est irréversible.")
        }
        .alert("Information", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingQuotePDF) {
            QuotePDFView(event: event, quoteItems: eventQuoteItems)
        }
        .onAppear {
            // Charger le compteur une seule fois au chargement
            loadQuoteItemsCount()
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
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(event.status.swiftUIColor)
            
            if isEditing {
                TextField("Nom de l'événement", text: $editedName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
            } else {
                Text(event.name)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var eventInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Informations de l'événement")
                .font(.headline)
            
            if isEditing {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Heure début montage", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $editedSetupStartTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    Label("Début événement", systemImage: "calendar.badge.clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $editedStartDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    Label("Fin événement", systemImage: "calendar.badge.checkmark")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $editedEndDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    Label("Adresse", systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Adresse de l'événement", text: $editedEventAddress)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                EventInfoRow(icon: "clock", title: "Montage", value: event.setupStartTime.formatted(date: .abbreviated, time: .shortened))
                EventInfoRow(icon: "calendar.badge.clock", title: "Début", value: event.startDate.formatted(date: .abbreviated, time: .shortened))
                EventInfoRow(icon: "calendar.badge.checkmark", title: "Fin", value: event.endDate.formatted(date: .abbreviated, time: .shortened))
                
                if !event.eventAddress.isEmpty {
                    EventInfoRow(icon: "location.fill", title: "Adresse", value: event.eventAddress)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var clientInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Informations client")
                .font(.headline)
            
            if isEditing {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Nom", systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Nom du client", text: $editedClientName)
                        .textFieldStyle(.roundedBorder)
                    
                    Label("Téléphone", systemImage: "phone.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Téléphone", text: $editedClientPhone)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.phonePad)
                    
                    Label("Email", systemImage: "envelope.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Email", text: $editedClientEmail)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textCase(.lowercase)
                    
                    Label("Adresse", systemImage: "building.2.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Adresse de facturation", text: $editedClientAddress)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                if !event.clientName.isEmpty {
                    EventInfoRow(icon: "person.fill", title: "Nom", value: event.clientName)
                }
                if !event.clientPhone.isEmpty {
                    EventInfoRow(icon: "phone.fill", title: "Téléphone", value: event.clientPhone)
                }
                if !event.clientEmail.isEmpty {
                    EventInfoRow(icon: "envelope.fill", title: "Email", value: event.clientEmail)
                }
                if !event.clientAddress.isEmpty {
                    EventInfoRow(icon: "building.2.fill", title: "Adresse", value: event.clientAddress)
                }
                
                if event.clientName.isEmpty && event.clientPhone.isEmpty {
                    Text("Aucune information client")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var truckSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Camion assigné")
                .font(.headline)
            
            if isEditing {
                Picker("Camion", selection: $editedAssignedTruckId) {
                    Text("Aucun").tag(nil as String?)
                    ForEach(trucks) { truck in
                        Text("\(truck.displayName) - \(Int(truck.maxVolume))m³").tag(truck.truckId as String?)
                    }
                }
                .pickerStyle(.menu)
            } else {
                if let truck = assignedTruck {
                    HStack(spacing: 16) {
                        Image(systemName: "truck.box.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(truck.displayName)
                                .font(.headline)
                            
                            HStack(spacing: 12) {
                                Label("\(Int(truck.maxVolume)) m³", systemImage: "cube")
                                Label("\(Int(truck.maxWeight)) kg", systemImage: "scalemass")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                } else {
                    Text("Aucun camion assigné")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statut et notes")
                .font(.headline)
            
            if isEditing {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Statut", systemImage: "flag.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Picker("Statut", selection: $editedStatus) {
                        ForEach(EventStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Label("Notes", systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextEditor(text: $editedNotes)
                        .frame(height: 100)
                        .padding(4)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                }
            } else {
                HStack {
                    Text("Statut:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(event.status.displayName)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(event.status.swiftUIColor.opacity(0.2))
                        )
                        .foregroundColor(event.status.swiftUIColor)
                }
                
                if !event.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes:")
                            .foregroundColor(.secondary)
                        Text(event.notes)
                            .font(.body)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Bouton Créer/Continuer/Voir le devis (3 scénarios)
            if event.quoteStatus == .finalized || event.quoteStatus == .sent {
                // Scénario 3 : Devis finalisé - Badge + Bouton unique pour voir
                VStack(spacing: 12) {
                    // Badge de statut
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Devis terminé")
                            .font(.headline)
                            .foregroundColor(.green)
                        Spacer()
                        Text(event.updatedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Bouton pour voir le devis (le bouton Revoir sera dans le PDF)
                    Button(action: { showingQuotePDF = true }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Voir le devis")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            } else {
                // Scénario 1 & 2 : Button stable avec navigation programmatique
                Button(action: {
                    isShowingQuoteBuilder = true
                }) {
                    HStack {
                        Image(systemName: hasExistingQuote ? "doc.text" : "doc.text.fill")
                        Text(hasExistingQuote ? "Continuer le devis" : "Créer le devis")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasExistingQuote ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            // Bouton supprimer
            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Supprimer l'événement")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .requiresPermission(.writeEvents)
        }
        .padding(.horizontal)
    }
    
    private var hasExistingQuote: Bool {
        // Utilise le cache au lieu de la Query réactive
        cachedQuoteItemsCount > 0
    }
    
    private var eventQuoteItems: [QuoteItem] {
        // Query directe sans observation pour le PDF uniquement
        let eventId = event.eventId  // Capturer dans une variable locale pour le Predicate
        let descriptor = FetchDescriptor<QuoteItem>(
            predicate: #Predicate { $0.eventId == eventId }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Actions
    
    private func loadQuoteItemsCount() {
        let eventId = event.eventId  // Capturer dans une variable locale
        let descriptor = FetchDescriptor<QuoteItem>(
            predicate: #Predicate { $0.eventId == eventId }
        )
        if let items = try? modelContext.fetch(descriptor) {
            cachedQuoteItemsCount = items.count
        } else {
            cachedQuoteItemsCount = 0
        }
    }
    
    private func startEditing() {
        editedName = event.name
        editedClientName = event.clientName
        editedClientPhone = event.clientPhone
        editedClientEmail = event.clientEmail
        editedClientAddress = event.clientAddress
        editedEventAddress = event.eventAddress
        editedSetupStartTime = event.setupStartTime
        editedStartDate = event.startDate
        editedEndDate = event.endDate
        editedStatus = event.status
        editedNotes = event.notes
        editedAssignedTruckId = event.assignedTruckId
        
        isEditing = true
    }
    
    private func cancelEditing() {
        // Réinitialiser toutes les valeurs éditées aux valeurs originales de l'événement
        editedName = event.name
        editedClientName = event.clientName
        editedClientPhone = event.clientPhone
        editedClientEmail = event.clientEmail
        editedClientAddress = event.clientAddress
        editedEventAddress = event.eventAddress
        editedSetupStartTime = event.setupStartTime
        editedStartDate = event.startDate
        editedEndDate = event.endDate
        editedStatus = event.status
        editedNotes = event.notes
        editedAssignedTruckId = event.assignedTruckId
        
        // Quitter le mode édition
        isEditing = false
    }
    
    private func saveChanges() {
        isSaving = true
        
        Task {
            do {
                event.name = editedName
                event.clientName = editedClientName
                event.clientPhone = editedClientPhone
                event.clientEmail = editedClientEmail
                event.clientAddress = editedClientAddress
                event.eventAddress = editedEventAddress
                event.setupStartTime = editedSetupStartTime
                event.startDate = editedStartDate
                event.endDate = editedEndDate
                event.status = editedStatus
                event.notes = editedNotes
                
                // 🆕 Détecter le changement de camion
                let oldTruckId = event.assignedTruckId
                event.assignedTruckId = editedAssignedTruckId
                event.updatedAt = Date()
                
                try modelContext.save()
                
                // 🆕 Mettre à jour le statut des camions affectés
                if oldTruckId != editedAssignedTruckId {
                    try? TruckStatusService.handleTruckAssignmentChange(
                        event: event,
                        oldTruckId: oldTruckId,
                        newTruckId: editedAssignedTruckId,
                        modelContext: modelContext
                    )
                } else if editedAssignedTruckId != nil {
                    // Dates ou statut changés, mettre à jour le camion assigné
                    try? TruckStatusService.handleEventChange(event: event, modelContext: modelContext)
                }
                
                // Synchroniser avec Firebase
                let firebaseService = FirebaseService()
                await firebaseService.updateEvent(event)
                
                await MainActor.run {
                    isSaving = false
                    isEditing = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    alertMessage = "Erreur lors de la mise à jour: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func deleteEvent() {
        Task {
            do {
                // 🆕 Sauvegarder le truckId avant suppression
                let truckId = event.assignedTruckId
                
                // Supprimer de Firebase
                let firebaseService = FirebaseService()
                await firebaseService.deleteEvent(event.eventId)
                
                // Supprimer de SwiftData
                modelContext.delete(event)
                try modelContext.save()
                
                // 🆕 Mettre à jour le statut du camion (maintenant disponible)
                if let truckId = truckId {
                    try? TruckStatusService.updateTruckStatusById(truckId: truckId, modelContext: modelContext)
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Erreur lors de la suppression: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct EventInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
    }
}

#Preview {
    @Previewable @State var activeQuoteBuilder: String? = nil
    
    NavigationStack {
        EventDetailView(
            event: Event(
                eventId: "EVT-001",
                name: "Concert Jazz Festival"
            ),
            activeQuoteBuilder: $activeQuoteBuilder
        )
    }
    .modelContainer(for: [Event.self, Truck.self], inMemory: true)
}

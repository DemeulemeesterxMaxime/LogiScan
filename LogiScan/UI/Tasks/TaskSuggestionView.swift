//
//  TaskSuggestionView.swift
//  LogiScan
//
//  Created by Demeulemeester on 19/10/2025.
//

import SwiftUI
import SwiftData

struct TaskSuggestionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let event: Event
    let suggestedTasks: [TodoTask]
    let onValidate: ([TodoTask]) -> Void
    
    @State private var editableTasks: [TodoTask] = []
    @State private var isCreatingScanLists = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Liste des tâches
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(editableTasks.enumerated()), id: \.element.taskId) { index, task in
                            TaskSuggestionCard(
                                task: task,
                                stepNumber: index + 1,
                                totalSteps: editableTasks.count,
                                onAssign: { userId, userName in
                                    editableTasks[index].assignedToUserId = userId
                                    editableTasks[index].assignedToUserName = userName
                                },
                                onRemove: {
                                    withAnimation {
                                        editableTasks.remove(at: index)
                                        // Rechaîner les tâches
                                        rechainTasks()
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                // Footer avec validation
                footerSection
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tâches suggérées")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
            .alert("Information", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                    
                    Text("Événement du \(event.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack {
                Label("\(editableTasks.count) tâches", systemImage: "list.bullet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let truckId = event.assignedTruckId {
                    Label("Camion assigné", systemImage: "truck.box.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            // Option de création automatique des listes de scan
            Toggle(isOn: $isCreatingScanLists) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Créer les listes de scan automatiquement")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Génère 4 listes : Stock→Camion, Camion→Event, Event→Camion, Camion→Stock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            
            // Bouton de validation
            Button {
                validateTasks()
            } label: {
                Label("Valider et créer les \(editableTasks.count) tâches", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(editableTasks.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(editableTasks.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
    }
    
    // MARK: - Methods
    
    init(event: Event, suggestedTasks: [TodoTask], onValidate: @escaping ([TodoTask]) -> Void) {
        self.event = event
        self.suggestedTasks = suggestedTasks
        self.onValidate = onValidate
        _editableTasks = State(initialValue: suggestedTasks)
    }
    
    private func rechainTasks() {
        for i in 0..<editableTasks.count {
            if i > 0 {
                editableTasks[i].previousTaskId = editableTasks[i - 1].taskId
            } else {
                editableTasks[i].previousTaskId = nil
            }
            
            if i < editableTasks.count - 1 {
                editableTasks[i].nextTaskId = editableTasks[i + 1].taskId
            } else {
                editableTasks[i].nextTaskId = nil
            }
        }
    }
    
    private func validateTasks() {
        guard !editableTasks.isEmpty else {
            alertMessage = "Aucune tâche à créer"
            showAlert = true
            return
        }
        
        // Si option cochée, créer les listes de scan
        if isCreatingScanLists {
            Task {
                await createScanListsForEvent()
            }
        }
        
        // Appeler le callback avec les tâches finales
        onValidate(editableTasks)
        dismiss()
    }
    
    // MARK: - Scan Lists Generation
    
    private func createScanListsForEvent() async {
        // Définir les 4 directions de scan
        let scanDirections: [(name: String, direction: ScanDirection)] = [
            ("Stock → Camion - \(event.name)", .stockToTruck),
            ("Camion → Event - \(event.name)", .truckToEvent),
            ("Event → Camion - \(event.name)", .eventToTruck),
            ("Camion → Stock - \(event.name)", .truckToStock)
        ]
        
        // Créer les 4 listes de scan
        for (listName, direction) in scanDirections {
            let scanList = ScanList(
                scanListId: UUID().uuidString,
                eventId: event.eventId,
                eventName: event.name,
                scanDirection: direction,
                totalItems: 0,  // Sera mis à jour après ajout des items
                scannedItems: 0,
                status: .pending,
                createdAt: Date()
            )
            
            // Insérer la liste dans SwiftData
            modelContext.insert(scanList)
            
            print("✅ Liste de scan créée : \(listName)")
        }
        
        // Sauvegarder
        do {
            try modelContext.save()
            print("✅ 4 listes de scan créées avec succès pour l'événement \(event.name)")
        } catch {
            print("❌ Erreur lors de la création des listes : \(error.localizedDescription)")
        }
    }
}

// MARK: - Task Suggestion Card

struct TaskSuggestionCard: View {
    let task: TodoTask
    let stepNumber: Int
    let totalSteps: Int
    let onAssign: (String, String) -> Void
    let onRemove: () -> Void
    
    @State private var showAssignSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête avec numéro d'étape
            HStack {
                // Numéro d'étape
                ZStack {
                    Circle()
                        .fill(task.priority.swiftUIColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Text("\(stepNumber)")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(task.priority.swiftUIColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: task.type.icon)
                            .foregroundStyle(task.priority.swiftUIColor)
                        
                        Text(task.displayTitle)
                            .font(.headline)
                    }
                    
                    if let description = task.taskDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Bouton supprimer
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            }
            
            Divider()
            
            // Métadonnées
            HStack(spacing: 16) {
                // Priorité
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(task.priority.displayName)
                        .font(.caption)
                }
                .foregroundStyle(task.priority.swiftUIColor)
                
                // Localisation
                if let location = task.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(task.type.suggestedLocation)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Attribution
            HStack {
                Image(systemName: task.assignedToUserId != nil ? "person.fill" : "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(task.assignedToUserId != nil ? .blue : .orange)
                
                if let userName = task.assignedToUserName {
                    Text(userName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                } else {
                    Text("Libre-service (toute l'équipe)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Modifier") {
                    showAssignSheet = true
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .sheet(isPresented: $showAssignSheet) {
            TaskAssignmentSheet(task: task, onAssign: onAssign)
        }
    }
}

// MARK: - Task Assignment Sheet

struct TaskAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let task: TodoTask
    let onAssign: (String, String) -> Void
    
    @State private var selectedUserId: String?
    @State private var selectedUserName: String?
    @State private var users: [User] = []
    
    var body: some View {
        NavigationStack {
            List {
                freeServiceSection
                
                Section("Attribuer à une personne") {
                    ForEach(users, id: \.userId) { user in
                        userRow(for: user)
                    }
                }
            }
            .navigationTitle("Attribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadUsers()
            }
        }
    }
    
    private var freeServiceSection: some View {
        Section {
            Button {
                onAssign("", "")
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Libre-service")
                            .font(.headline)
                        Text("Toute l'équipe peut prendre cette tâche")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if task.assignedToUserId == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }
    
    private func userRow(for user: User) -> some View {
        Button {
            onAssign(user.userId, user.displayName)
            dismiss()
        } label: {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.headline)
                    Text(user.role?.displayName ?? "Employé")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if task.assignedToUserId == user.userId {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .foregroundStyle(.primary)
    }
    
    private func loadUsers() {
        // Charger les utilisateurs de la même entreprise
        guard !task.companyId.isEmpty else { return }
        
        let companyId = task.companyId
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.companyId == companyId
            }
        )
        
        do {
            users = try modelContext.fetch(descriptor)
        } catch {
            print("❌ Erreur chargement utilisateurs: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Event.self, TodoTask.self, User.self, configurations: config)
    
    let event = Event(
        eventId: "preview",
        name: "Mariage Sophie & Pierre",
        clientName: "Sophie Martin",
        eventAddress: "456 avenue event",
        setupStartTime: Date().addingTimeInterval(3600),
        startDate: Date().addingTimeInterval(7200),
        endDate: Date().addingTimeInterval(14400),
        status: .confirmed,
        quoteStatus: .finalized
    )
    
    let task1 = TodoTask(
        title: nil,
        type: .createScanList,
        priority: .high,
        eventId: event.eventId,
        createdBy: "user1",
        companyId: "company1"
    )
    
    let task2 = TodoTask(
        title: nil,
        type: .prepareItems,
        priority: .high,
        eventId: event.eventId,
        createdBy: "user1",
        companyId: "company1"
    )
    
    let tasks = [task1, task2]
    
    TaskSuggestionView(event: event, suggestedTasks: tasks) { validatedTasks in
        print("Validated \(validatedTasks.count) tasks")
    }
    .modelContainer(container)
}

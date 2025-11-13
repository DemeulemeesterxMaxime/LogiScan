//
//  CreateTaskView.swift
//  LogiScan
//
//  Created by Demeulemeester on 18/10/2025.
//

import SwiftUI
import SwiftData

struct CreateTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var permissionService = PermissionService.shared
    @State private var firebaseService = FirebaseService()
    
    // Membres de l'équipe (chargés depuis Firebase)
    @State private var teamMembers: [User] = []
    @State private var isLoadingMembers = false
    
    // Formulaire
    @State private var title = ""
    @State private var taskDescription = ""
    @State private var selectedType: TodoTask.TaskType = .custom
    @State private var selectedPriority: TodoTask.TaskPriority = .medium
    @State private var selectedStatus: TodoTask.TaskStatus = .pending
    
    // Attribution
    @State private var assignedToUserId: String?
    @State private var assignedToUserName: String?
    @State private var isUnassigned = false  // NON libre-service par défaut
    @State private var selectedUserIds: Set<String> = []  // Sélection multiple
    @State private var memberSearchText = ""  // Recherche de membres
    
    // Relations
    @State private var eventId: String?
    @State private var scanListId: String?
    @State private var truckId: String?
    
    // Métadonnées
    @State private var dueDate: Date?
    @State private var hasDueDate = false
    @State private var estimatedDuration: Int?
    @State private var hasEstimatedDuration = false
    @State private var location = ""
    
    // Workflow
    @State private var triggerNotification = true
    
    // État
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Validation du formulaire
    private var isFormValid: Bool {
        // Si la tâche n'est pas en libre-service, on doit avoir sélectionné au moins un membre
        if !isUnassigned {
            return !selectedUserIds.isEmpty
        }
        return true
    }
    
    // Membres filtrés par recherche
    private var filteredMembers: [User] {
        if memberSearchText.isEmpty {
            return teamMembers
        }
        return teamMembers.filter { user in
            user.displayName.localizedCaseInsensitiveContains(memberSearchText) ||
            user.email.localizedCaseInsensitiveContains(memberSearchText) ||
            (user.role?.displayName.localizedCaseInsensitiveContains(memberSearchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Section Informations de base
                Section {
                    TextField("Titre de la tâche (optionnel)", text: $title)
                        .textInputAutocapitalization(.sentences)
                    
                    ZStack(alignment: .topLeading) {
                        if taskDescription.isEmpty {
                            Text("Description (optionnelle)")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $taskDescription)
                            .frame(minHeight: 100)
                            .padding(.leading, -4)
                    }
                } header: {
                    Text("Informations de base")
                } footer: {
                    Text("Si aucun titre n'est fourni, le nom du type de tâche sera utilisé automatiquement.")
                        .font(.caption)
                }
                
                // Section Type et Priorité
                Section {
                    Picker("Type de tâche", selection: $selectedType) {
                        ForEach(TodoTask.TaskType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    
                    Picker("Priorité", selection: $selectedPriority) {
                        ForEach(TodoTask.TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priority.icon)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    
                    HStack {
                        Image(systemName: selectedType.icon)
                            .foregroundColor(.blue)
                        Text("Lieu suggéré")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(selectedType.suggestedLocation)
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("Type et Priorité")
                }
                
                // Section Attribution
                Section {
                    Toggle("Tâche en libre-service", isOn: $isUnassigned)
                        .onChange(of: isUnassigned) { _, newValue in
                            if newValue {
                                // Réinitialiser l'attribution
                                selectedUserIds.removeAll()
                                memberSearchText = ""
                            }
                        }
                    
                    if !isUnassigned {
                        if isLoadingMembers {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Chargement des membres...")
                                    .foregroundColor(.secondary)
                            }
                            .font(.callout)
                        } else if teamMembers.isEmpty {
                            HStack {
                                Image(systemName: "person.slash")
                                    .foregroundColor(.secondary)
                                Text("Aucun autre membre dans l'équipe")
                                    .foregroundColor(.secondary)
                            }
                            .font(.callout)
                        } else {
                            // Barre de recherche
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Rechercher un membre...", text: $memberSearchText)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                
                                if !memberSearchText.isEmpty {
                                    Button(action: { memberSearchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            
                            // Résumé de la sélection
                            if !selectedUserIds.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("\(selectedUserIds.count) membre(s) sélectionné(s)")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Tout désélectionner") {
                                        selectedUserIds.removeAll()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            // Liste des membres avec sélection multiple
                            ForEach(filteredMembers, id: \.userId) { user in
                                Button(action: {
                                    toggleUserSelection(user.userId)
                                }) {
                                    HStack {
                                        // Checkbox
                                        Image(systemName: selectedUserIds.contains(user.userId) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedUserIds.contains(user.userId) ? .green : .secondary)
                                            .font(.title3)
                                        
                                        // Avatar
                                        Image(systemName: user.role?.icon ?? "person.fill")
                                            .foregroundColor(isCurrentUser(user.userId) ? .orange : .blue)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(user.displayName)
                                                    .foregroundColor(.primary)
                                                
                                                // Badge "Vous" pour l'utilisateur actuel
                                                if isCurrentUser(user.userId) {
                                                    Text("(Vous)")
                                                        .font(.caption2)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Color.orange.opacity(0.2))
                                                        .foregroundColor(.orange)
                                                        .cornerRadius(3)
                                                }
                                            }
                                            
                                            HStack {
                                                if let role = user.role {
                                                    Text(role.displayName)
                                                        .font(.caption2)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(role.color.opacity(0.2))
                                                        .foregroundColor(role.color)
                                                        .cornerRadius(4)
                                                }
                                                
                                                Text(user.email)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Message si recherche sans résultat
                            if filteredMembers.isEmpty && !memberSearchText.isEmpty {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.secondary)
                                    Text("Aucun membre trouvé pour '\(memberSearchText)'")
                                        .foregroundColor(.secondary)
                                        .font(.callout)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                } header: {
                    Text("Attribution")
                } footer: {
                    if isUnassigned {
                        Text("La tâche sera disponible pour tous les membres de l'équipe")
                    } else if isLoadingMembers {
                        Text("Chargement des membres de l'équipe depuis Firebase...")
                    } else if teamMembers.isEmpty {
                        Text("Aucun membre dans votre équipe. Invitez des membres dans la section Administration.")
                    } else if selectedUserIds.isEmpty {
                        Text("Sélectionnez un ou plusieurs membres pour attribuer cette tâche (vous pouvez vous inclure)")
                    } else {
                        let selectedNames = teamMembers
                            .filter { selectedUserIds.contains($0.userId) }
                            .map { user in
                                isCurrentUser(user.userId) ? "\(user.displayName) (Vous)" : user.displayName
                            }
                            .joined(separator: ", ")
                        Text("Tâche attribuée à : \(selectedNames)")
                    }
                }
                
                // Section Planification
                Section {
                    Toggle("Définir une échéance", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Date d'échéance", selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    Toggle("Durée estimée", isOn: $hasEstimatedDuration)
                    
                    if hasEstimatedDuration {
                        Stepper("Durée: \(estimatedDuration ?? 30) min", value: Binding(
                            get: { estimatedDuration ?? 30 },
                            set: { estimatedDuration = $0 }
                        ), in: 15...480, step: 15)
                    }
                    
                    TextField("Lieu", text: $location)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("planning".localized())
                }
                
                // Section Notifications
                Section {
                    Toggle("Notifier à la complétion", isOn: $triggerNotification)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Envoyer une notification lorsque cette tâche est terminée")
                }
            }
            .navigationTitle("Créer une tâche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        createTask()
                    }
                    .disabled(isSaving || !isFormValid)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView("Création...")
                        .padding()
                        .background(Color(.systemBackground).opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadTeamMembers()
            }
        }
    }
    
    // MARK: - Load Team Members
    
    private func isCurrentUser(_ userId: String) -> Bool {
        return permissionService.currentUser?.userId == userId
    }
    
    private func toggleUserSelection(_ userId: String) {
        if selectedUserIds.contains(userId) {
            selectedUserIds.remove(userId)
        } else {
            selectedUserIds.insert(userId)
        }
    }
    
    private func loadTeamMembers() async {
        guard let currentUser = permissionService.currentUser,
              let companyId = currentUser.companyId else {
            print("❌ [CreateTask] Pas d'utilisateur ou de companyId")
            return
        }
        
        isLoadingMembers = true
        print("🔄 [CreateTask] Chargement des membres depuis Firebase...")
        print("   - CompanyId: \(companyId)")
        
        do {
            let allMembers = try await firebaseService.fetchCompanyMembers(companyId: companyId)
            print("📥 [CreateTask] \(allMembers.count) membres récupérés depuis Firebase")
            
            // Ne plus filtrer l'utilisateur actuel - permettre l'auto-assignation
            // Trier par rôle : admin > manager > employee
            let sortedMembers = allMembers.sorted { u1, u2 in
                // Placer l'utilisateur actuel en premier
                if u1.userId == currentUser.userId {
                    return true
                }
                if u2.userId == currentUser.userId {
                    return false
                }
                
                // Puis trier par rôle
                if let r1 = u1.role, let r2 = u2.role {
                    return r1.rawValue < r2.rawValue
                }
                return u1.displayName < u2.displayName
            }
            
            await MainActor.run {
                self.teamMembers = sortedMembers
                print("✅ [CreateTask] \(sortedMembers.count) membres disponibles pour assignation")
                
                for member in sortedMembers {
                    let isCurrent = member.userId == currentUser.userId ? " (Vous)" : ""
                    print("   - \(member.displayName)\(isCurrent) (\(member.role?.displayName ?? "pas de rôle"))")
                }
            }
        } catch {
            print("❌ [CreateTask] Erreur chargement membres: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Erreur lors du chargement des membres: \(error.localizedDescription)"
                showingError = true
            }
        }
        
        isLoadingMembers = false
    }
    
    // MARK: - Actions
    
    private func createTask() {
        guard let currentUser = permissionService.currentUser else {
            errorMessage = "Utilisateur non connecté"
            showingError = true
            return
        }
        
        guard let companyId = currentUser.companyId else {
            errorMessage = "Aucune entreprise associée"
            showingError = true
            return
        }
        
        // Vérifier les permissions
        guard permissionService.checkPermission(.writeTasks) else {
            errorMessage = "Vous n'avez pas la permission de créer des tâches"
            showingError = true
            return
        }
        
        isSaving = true
        
        Task {
            // Si le titre est vide, on le laisse nil pour utiliser le nom du type
            let taskTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title
            
            // Si en libre-service OU aucun membre sélectionné : créer 1 tâche non assignée
            if isUnassigned || selectedUserIds.isEmpty {
                let newTask = TodoTask(
                    title: taskTitle,
                    taskDescription: taskDescription.isEmpty ? nil : taskDescription,
                    type: selectedType,
                    status: selectedStatus,
                    priority: selectedPriority,
                    eventId: eventId,
                    scanListId: scanListId,
                    truckId: truckId,
                    assignedToUserId: nil,
                    assignedToUserName: nil,
                    createdBy: currentUser.userId,
                    companyId: companyId,
                    triggerNotification: triggerNotification,
                    dueDate: hasDueDate ? dueDate : nil,
                    estimatedDuration: hasEstimatedDuration ? estimatedDuration : nil,
                    location: location.isEmpty ? selectedType.suggestedLocation : location
                )
                
                await createSingleTask(newTask)
            } else {
                // Créer une tâche pour chaque membre sélectionné
                let selectedMembers = teamMembers.filter { selectedUserIds.contains($0.userId) }
                
                for member in selectedMembers {
                    let newTask = TodoTask(
                        title: taskTitle,
                        taskDescription: taskDescription.isEmpty ? nil : taskDescription,
                        type: selectedType,
                        status: selectedStatus,
                        priority: selectedPriority,
                        eventId: eventId,
                        scanListId: scanListId,
                        truckId: truckId,
                        assignedToUserId: member.userId,
                        assignedToUserName: member.displayName,
                        createdBy: currentUser.userId,
                        companyId: companyId,
                        triggerNotification: triggerNotification,
                        dueDate: hasDueDate ? dueDate : nil,
                        estimatedDuration: hasEstimatedDuration ? estimatedDuration : nil,
                        location: location.isEmpty ? selectedType.suggestedLocation : location
                    )
                    
                    await createSingleTask(newTask)
                }
            }
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
    
    private func createSingleTask(_ task: TodoTask) async {
        do {
            _ = try await TaskService.shared.createTask(task, modelContext: modelContext)
            print("✅ Tâche créée et synchronisée avec Firebase: \(task.title ?? task.type.displayName)")
        } catch {
            await MainActor.run {
                errorMessage = "Erreur lors de la création: \(error.localizedDescription)"
                showingError = true
                isSaving = false
            }
        }
    }
}

#Preview {
    CreateTaskView()
        .modelContainer(for: [TodoTask.self], inMemory: true)
}

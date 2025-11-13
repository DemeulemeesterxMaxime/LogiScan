//
//  TaskDetailView.swift
//  LogiScan
//
//  Created by Demeulemeester on 18/10/2025.
//

import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var permissionService = PermissionService.shared
    
    let task: TodoTask
    
    @State private var showingDeleteAlert = false
    @State private var showingCancelAlert = false
    @State private var cancelReason = ""
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    private var canEdit: Bool {
        guard let currentUser = permissionService.currentUser else { return false }
        
        // Admin et Manager peuvent tout modifier
        if permissionService.checkPermission(.manageTasks) {
            return true
        }
        
        // Le créateur peut modifier sa propre tâche
        if task.createdBy == currentUser.userId {
            return true
        }
        
        // L'assigné peut modifier le statut
        if task.assignedToUserId == currentUser.userId {
            return true
        }
        
        return false
    }
    
    private var canDelete: Bool {
        permissionService.checkPermission(.manageTasks)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // En-tête avec statut et priorité
                headerSection
                
                // Informations principales
                mainInfoSection
                
                // Détails de la tâche
                detailsSection
                
                // Attribution
                assignmentSection
                
                // Planification
                planningSection
                
                // Timeline
                timelineSection
                
                // Actions
                if canEdit {
                    actionsSection
                }
            }
            .padding()
        }
        .navigationTitle(task.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if canDelete {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .alert("Supprimer la tâche", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer cette tâche ? Cette action est irréversible.")
        }
        .alert("Annuler la tâche", isPresented: $showingCancelAlert) {
            TextField("Raison (optionnel)", text: $cancelReason)
            Button("Annuler l'action", role: .cancel) { }
            Button("Confirmer l'annulation", role: .destructive) {
                cancelTask()
            }
        } message: {
            Text("Pourquoi annulez-vous cette tâche ?")
        }
        .alert("Erreur", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Une erreur est survenue")
        }
        .overlay {
            if isUpdating {
                ProgressView("Mise à jour...")
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Type de tâche
                Label(task.type.displayName, systemImage: task.type.icon)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Priorité
                Label(task.priority.displayName, systemImage: task.priority.icon)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(task.priority.swiftUIColor)
                    .cornerRadius(20)
            }
            
            // Statut
            HStack {
                Circle()
                    .fill(task.status.swiftUIColor)
                    .frame(width: 12, height: 12)
                
                Text(task.status.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Main Info Section
    
    private var mainInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
            
            if let description = task.taskDescription {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                Text("Aucune description")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("details".localized())
                .font(.headline)
            
            VStack(spacing: 12) {
                if let eventId = task.eventId {
                    TaskDetailRow(icon: "calendar.badge.clock", 
                             label: "Événement", 
                             value: eventId,
                             color: .red)
                }
                
                if let truckId = task.truckId {
                    TaskDetailRow(icon: "truck.box.fill", 
                             label: "Camion", 
                             value: truckId,
                             color: .blue)
                }
                
                if let location = task.location {
                    TaskDetailRow(icon: "location.fill", 
                             label: "Lieu", 
                             value: location,
                             color: .green)
                }
                
                if let duration = task.estimatedDuration {
                    TaskDetailRow(icon: "clock.fill", 
                             label: "Durée estimée", 
                             value: "\(duration) minutes",
                             color: .orange)
                }
            }
        }
    }
    
    // MARK: - Assignment Section
    
    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attribution")
                .font(.headline)
            
            if let userName = task.assignedToUserName {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Attribuée à")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(userName)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if task.status == .pending && permissionService.checkPermission(.assignTasks) {
                        Button("Réattribuer") {
                            // TODO: Implémenter la réattribution
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text("Libre-service")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text("Disponible pour toute l'équipe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if task.status == .pending && permissionService.checkPermission(.writeTasks) {
                        Button("M'attribuer") {
                            assignToSelf()
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Planning Section
    
    private var planningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("planning".localized())
                .font(.headline)
            
            VStack(spacing: 12) {
                // Date d'échéance
                if let dueDate = task.dueDate {
                    let isOverdue = dueDate < Date() && task.status != .completed
                    
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(isOverdue ? .red : .blue)
                        
                        VStack(alignment: .leading) {
                            Text("Date d'échéance")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(dueDate.formatted(date: .long, time: .shortened))
                                .font(.body)
                                .foregroundColor(isOverdue ? .red : .primary)
                        }
                        
                        Spacer()
                        
                        if isOverdue {
                            Text("EN RETARD")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                    .background(isOverdue ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Text("Aucune échéance définie")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
    
    // MARK: - Timeline Section
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historique")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                TimelineItem(
                    icon: "plus.circle.fill",
                    title: "Tâche créée",
                    date: task.createdAt,
                    color: .blue
                )
                
                if let startedAt = task.startedAt {
                    TimelineItem(
                        icon: "play.circle.fill",
                        title: "Démarrée",
                        date: startedAt,
                        color: .green
                    )
                }
                
                if let completedAt = task.completedAt {
                    TimelineItem(
                        icon: "checkmark.circle.fill",
                        title: "Terminée",
                        date: completedAt,
                        color: .green
                    )
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            switch task.status {
            case .pending:
                Button {
                    startTask()
                } label: {
                    Label("Démarrer la tâche", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button {
                    showingCancelAlert = true
                } label: {
                    Label("Annuler la tâche", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
                
            case .inProgress:
                Button {
                    completeTask()
                } label: {
                    Label("Marquer comme terminée", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button {
                    showingCancelAlert = true
                } label: {
                    Label("Annuler la tâche", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
                
            case .blocked:
                Text("⚠️ Cette tâche est bloquée")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                
            case .completed:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Tâche terminée")
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
            case .cancelled:
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Tâche annulée")
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Actions
    
    private func assignToSelf() {
        guard let currentUser = permissionService.currentUser else { return }
        
        isUpdating = true
        
        Task {
            do {
                task.assignedToUserId = currentUser.userId
                task.assignedToUserName = currentUser.displayName
                
                try await TaskService.shared.updateTask(task, modelContext: modelContext)
                
                await MainActor.run {
                    isUpdating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Erreur lors de l'attribution: \(error.localizedDescription)"
                    showingError = true
                    isUpdating = false
                }
            }
        }
    }
    
    private func startTask() {
        guard let currentUser = permissionService.currentUser else { return }
        
        isUpdating = true
        
        Task {
            do {
                try await TaskService.shared.startTask(task, userId: currentUser.userId, modelContext: modelContext)
                
                await MainActor.run {
                    isUpdating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Erreur lors du démarrage: \(error.localizedDescription)"
                    showingError = true
                    isUpdating = false
                }
            }
        }
    }
    
    private func completeTask() {
        isUpdating = true
        
        Task {
            do {
                try await TaskService.shared.completeTask(task, modelContext: modelContext)
                
                await MainActor.run {
                    isUpdating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Erreur lors de la complétion: \(error.localizedDescription)"
                    showingError = true
                    isUpdating = false
                }
            }
        }
    }
    
    private func cancelTask() {
        isUpdating = true
        
        Task {
            do {
                try await TaskService.shared.cancelTask(
                    task, 
                    reason: cancelReason.isEmpty ? nil : cancelReason,
                    modelContext: modelContext
                )
                
                await MainActor.run {
                    isUpdating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Erreur lors de l'annulation: \(error.localizedDescription)"
                    showingError = true
                    isUpdating = false
                }
            }
        }
    }
    
    private func deleteTask() {
        isUpdating = true
        
        Task {
            do {
                try await TaskService.shared.deleteTask(taskId: task.taskId, modelContext: modelContext)
                
                await MainActor.run {
                    isUpdating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Erreur lors de la suppression: \(error.localizedDescription)"
                    showingError = true
                    isUpdating = false
                }
            }
        }
    }
}

// MARK: - Task Detail Row

struct TaskDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
    }
}

// MARK: - Timeline Item

struct TimelineItem: View {
    let icon: String
    let title: String
    let date: Date
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(task: TodoTask(
            title: "Préparer le matériel",
            taskDescription: "Préparer tout le matériel nécessaire pour l'événement de demain",
            type: .prepareItems,
            status: .pending,
            priority: .high,
            createdBy: "user123",
            companyId: "company123"
        ))
    }
    .modelContainer(for: [TodoTask.self], inMemory: true)
}

//
//  TaskService.swift
//  LogiScan
//
//  Created by Demeulemeester on 18/10/2025.
//

import Foundation
import SwiftData
import FirebaseFirestore

class TaskService {
    static let shared = TaskService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Create Task
    
    /// Créer une tâche et la synchroniser avec Firebase
    func createTask(_ task: TodoTask, modelContext: ModelContext) async throws -> TodoTask {
        print("🔄 [TaskService] Création tâche: \(task.displayTitle)")
        print("   - TaskId: \(task.taskId)")
        print("   - CompanyId: \(task.companyId)")
        print("   - EventId: \(task.eventId ?? "nil")")
        
        // 1. Sauvegarder localement dans SwiftData
        modelContext.insert(task)
        try modelContext.save()
        print("✅ [TaskService] Tâche sauvegardée localement")
        
        // 2. Synchroniser avec Firebase
        try await syncTaskToFirebase(task)
        print("✅ [TaskService] Tâche synchronisée avec Firebase")
        
        print("✅ Tâche créée et synchronisée: \(task.displayTitle)")
        return task
    }
    
    // MARK: - Sync to Firebase
    
    /// Synchroniser une tâche vers Firebase
    private func syncTaskToFirebase(_ task: TodoTask) async throws {
        let taskData: [String: Any] = [
            "taskId": task.taskId,
            "title": task.title ?? task.type.displayName,  // Utilise le nom du type si titre nil
            "taskDescription": task.taskDescription as Any,
            "type": task.type.rawValue,
            "status": task.status.rawValue,
            "priority": task.priority.rawValue,
            "eventId": task.eventId as Any,
            "scanListId": task.scanListId as Any,
            "truckId": task.truckId as Any,
            "assignedToUserId": task.assignedToUserId as Any,
            "assignedToUserName": task.assignedToUserName as Any,
            "createdBy": task.createdBy,
            "companyId": task.companyId,
            "nextTaskId": task.nextTaskId as Any,
            "previousTaskId": task.previousTaskId as Any,
            "triggerNotification": task.triggerNotification,
            "createdAt": Timestamp(date: task.createdAt),
            "startedAt": task.startedAt != nil ? Timestamp(date: task.startedAt!) : NSNull(),
            "completedAt": task.completedAt != nil ? Timestamp(date: task.completedAt!) : NSNull(),
            "dueDate": task.dueDate != nil ? Timestamp(date: task.dueDate!) : NSNull(),
            "estimatedDuration": task.estimatedDuration as Any,
            "location": task.location as Any
        ]
        
        try await db.collection("tasks").document(task.taskId).setData(taskData)
    }
    
    // MARK: - Fetch Tasks
    
    /// Récupérer toutes les tâches d'une entreprise depuis Firebase
    func fetchTasks(for companyId: String) async throws -> [TodoTask] {
        let snapshot = try await db.collection("tasks")
            .whereField("companyId", isEqualTo: companyId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        var tasks: [TodoTask] = []
        
        for document in snapshot.documents {
            if let task = try? parseTaskFromFirestore(document) {
                tasks.append(task)
            }
        }
        
        return tasks
    }
    
    /// Récupérer les tâches d'un utilisateur spécifique
    func fetchTasksForUser(userId: String, companyId: String) async throws -> [TodoTask] {
        let snapshot = try await db.collection("tasks")
            .whereField("companyId", isEqualTo: companyId)
            .whereField("assignedToUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        var tasks: [TodoTask] = []
        
        for document in snapshot.documents {
            if let task = try? parseTaskFromFirestore(document) {
                tasks.append(task)
            }
        }
        
        return tasks
    }
    
    /// Récupérer les tâches en libre-service (non attribuées)
    func fetchUnassignedTasks(for companyId: String) async throws -> [TodoTask] {
        let snapshot = try await db.collection("tasks")
            .whereField("companyId", isEqualTo: companyId)
            .whereField("assignedToUserId", isEqualTo: NSNull())
            .whereField("status", isEqualTo: TodoTask.TaskStatus.pending.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        var tasks: [TodoTask] = []
        
        for document in snapshot.documents {
            if let task = try? parseTaskFromFirestore(document) {
                tasks.append(task)
            }
        }
        
        return tasks
    }
    
    // MARK: - Update Task
    
    /// Mettre à jour une tâche
    func updateTask(_ task: TodoTask, modelContext: ModelContext) async throws {
        // 1. Sauvegarder localement
        try modelContext.save()
        
        // 2. Synchroniser avec Firebase
        try await syncTaskToFirebase(task)
        
        print("✅ Tâche mise à jour: \(task.displayTitle)")
    }
    
    /// Marquer une tâche comme démarrée
    func startTask(_ task: TodoTask, userId: String, modelContext: ModelContext) async throws {
        task.status = .inProgress
        task.startedAt = Date()
        task.assignedToUserId = userId
        
        try await updateTask(task, modelContext: modelContext)
        
        // Notifier le créateur
        try? TaskNotificationService.shared.notifyTaskStarted(task: task, modelContext: modelContext)
    }
    
    /// Marquer une tâche comme terminée
    func completeTask(_ task: TodoTask, modelContext: ModelContext) async throws {
        task.status = .completed
        task.completedAt = Date()
        
        try await updateTask(task, modelContext: modelContext)
        
        // Récupérer la tâche suivante
        var nextTask: TodoTask?
        if let nextTaskId = task.nextTaskId {
            let descriptor = FetchDescriptor<TodoTask>(
                predicate: #Predicate { $0.taskId == nextTaskId }
            )
            nextTask = try? modelContext.fetch(descriptor).first
        }
        
        // Déclencher notification
        try? TaskNotificationService.shared.notifyTaskCompleted(
            task: task,
            nextTask: nextTask,
            modelContext: modelContext
        )
    }
    
    /// Annuler une tâche
    func cancelTask(_ task: TodoTask, reason: String?, modelContext: ModelContext) async throws {
        task.status = .cancelled
        
        try await updateTask(task, modelContext: modelContext)
        
        // Notifier l'annulation
        try? TaskNotificationService.shared.notifyTaskCancelled(
            task: task,
            reason: reason,
            modelContext: modelContext
        )
        
        print("❌ Tâche annulée: \(task.displayTitle)")
        if let reason = reason {
            print("   Raison: \(reason)")
        }
    }
    
    // MARK: - Delete Task
    
    /// Supprimer une tâche
    func deleteTask(taskId: String, modelContext: ModelContext) async throws {
        // 1. Supprimer de Firebase
        try await db.collection("tasks").document(taskId).delete()
        
        // 2. Supprimer localement
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate { $0.taskId == taskId }
        )
        
        if let task = try modelContext.fetch(descriptor).first {
            modelContext.delete(task)
            try modelContext.save()
        }
        
        print("🗑️ Tâche supprimée: \(taskId)")
    }
    
    // MARK: - Statistics
    
    /// Obtenir les statistiques des tâches pour une entreprise
    func getTaskStatistics(for companyId: String) async throws -> TaskStatistics {
        let snapshot = try await db.collection("tasks")
            .whereField("companyId", isEqualTo: companyId)
            .getDocuments()
        
        var stats = TaskStatistics()
        
        for document in snapshot.documents {
            guard let statusRaw = document.data()["status"] as? String,
                  let status = TodoTask.TaskStatus(rawValue: statusRaw),
                  let priorityRaw = document.data()["priority"] as? String,
                  let priority = TodoTask.TaskPriority(rawValue: priorityRaw) else {
                continue
            }
            
            // Compter par statut
            switch status {
            case .pending: stats.pendingCount += 1
            case .inProgress: stats.inProgressCount += 1
            case .completed: stats.completedCount += 1
            case .cancelled: stats.cancelledCount += 1
            case .blocked: stats.blockedCount += 1
            }
            
            // Compter les urgentes
            if priority == .urgent && status != .completed && status != .cancelled {
                stats.urgentCount += 1
            }
            
            // Compter les non attribuées
            if document.data()["assignedToUserId"] == nil && status == .pending {
                stats.unassignedCount += 1
            }
            
            // Compter les en retard
            if let dueDateTimestamp = document.data()["dueDate"] as? Timestamp {
                let dueDate = dueDateTimestamp.dateValue()
                if dueDate < Date() && status != .completed && status != .cancelled {
                    stats.overdueCount += 1
                }
            }
        }
        
        stats.totalCount = snapshot.documents.count
        
        return stats
    }
    
    // MARK: - Task Generation
    
    /// Générer les tâches suggérées pour un événement à partir du devis
    func generateSuggestedTasks(
        for event: Event,
        companyId: String,
        createdBy: String,
        modelContext: ModelContext
    ) throws -> [TodoTask] {
        var suggestedTasks: [TodoTask] = []
        
        // 1. Créer liste de scan (Stock → Camion)
        let scanListTask = TodoTask(
            title: nil,  // Utilisera le nom du type
            taskDescription: "Créer la liste de scan pour préparer le matériel",
            type: .createScanList,
            status: .pending,
            priority: .high,
            eventId: event.eventId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(scanListTask)
        
        // 2. Préparer articles au stock
        let prepareItemsTask = TodoTask(
            title: nil,
            taskDescription: "Rassembler et préparer le matériel au stock selon la liste",
            type: .prepareItems,
            status: .pending,
            priority: .high,
            eventId: event.eventId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(prepareItemsTask)
        
        // 3. Scanner préparation
        let scanPrepTask = TodoTask(
            title: nil,
            taskDescription: "Scanner chaque article préparé",
            type: .scanPreparation,
            status: .pending,
            priority: .medium,
            eventId: event.eventId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(scanPrepTask)
        
        // 4. Charger camion au stock
        let loadTruckTask = TodoTask(
            title: nil,
            taskDescription: "Charger le matériel scanné dans le camion",
            type: .loadTruckFromStock,
            status: .pending,
            priority: .high,
            eventId: event.eventId,
            truckId: event.assignedTruckId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(loadTruckTask)
        
        // 5. Scanner chargement
        let scanLoadingTask = TodoTask(
            title: nil,
            taskDescription: "Vérifier le chargement avec le scanner",
            type: .scanLoading,
            status: .pending,
            priority: .medium,
            eventId: event.eventId,
            truckId: event.assignedTruckId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(scanLoadingTask)
        
        // 6. Transport vers événement
        let transportToEventTask = TodoTask(
            title: nil,
            taskDescription: "Conduire jusqu'à l'adresse de l'événement",
            type: .transportToEvent,
            status: .pending,
            priority: .high,
            eventId: event.eventId,
            truckId: event.assignedTruckId,
            createdBy: createdBy,
            companyId: companyId,
            location: event.eventAddress
        )
        suggestedTasks.append(transportToEventTask)
        
        // 7. Décharger camion à l'événement
        let unloadAtEventTask = TodoTask(
            title: nil,
            taskDescription: "Décharger le matériel du camion sur le site",
            type: .unloadTruckAtEvent,
            status: .pending,
            priority: .high,
            eventId: event.eventId,
            truckId: event.assignedTruckId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(unloadAtEventTask)
        
        // 8. Scanner déchargement
        let scanUnloadingTask = TodoTask(
            title: nil,
            taskDescription: "Scanner le matériel déchargé",
            type: .scanUnloading,
            status: .pending,
            priority: .medium,
            eventId: event.eventId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(scanUnloadingTask)
        
        // 9. Montage/Installation
        let setupTask = TodoTask(
            title: nil,
            taskDescription: "Installer et monter le matériel pour l'événement",
            type: .eventSetup,
            status: .pending,
            priority: .high,
            eventId: event.eventId,
            createdBy: createdBy,
            companyId: companyId,
            dueDate: event.setupStartTime
        )
        suggestedTasks.append(setupTask)
        
        // 10. Opération événement
        let operationTask = TodoTask(
            title: nil,
            taskDescription: "Superviser et gérer l'événement",
            type: .eventOperation,
            status: .pending,
            priority: .medium,
            eventId: event.eventId,
            createdBy: createdBy,
            companyId: companyId,
            dueDate: event.startDate
        )
        suggestedTasks.append(operationTask)
        
        // 11. Démontage
        let teardownTask = TodoTask(
            title: nil,
            taskDescription: "Démonter et emballer le matériel",
            type: .eventTeardown,
            status: .pending,
            priority: .high,
            eventId: event.eventId,
            createdBy: createdBy,
            companyId: companyId,
            dueDate: event.endDate
        )
        suggestedTasks.append(teardownTask)
        
        // 12. Charger camion à l'événement (retour)
        let loadReturnTask = TodoTask(
            title: nil,
            taskDescription: "Charger le matériel dans le camion pour le retour",
            type: .loadTruckAtEvent,
            status: .pending,
            priority: .high,
            eventId: event.eventId,
            truckId: event.assignedTruckId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(loadReturnTask)
        
        // 13. Scanner chargement retour
        let scanReturnLoadingTask = TodoTask(
            title: nil,
            taskDescription: "Scanner le matériel chargé pour le retour",
            type: .scanReturn,
            status: .pending,
            priority: .medium,
            eventId: event.eventId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(scanReturnLoadingTask)
        
        // 14. Transport retour
        let transportReturnTask = TodoTask(
            title: nil,
            taskDescription: "Retour au stock",
            type: .transportReturn,
            status: .pending,
            priority: .high,
            eventId: event.eventId,
            truckId: event.assignedTruckId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(transportReturnTask)
        
        // 15. Décharger camion au stock
        let unloadAtStockTask = TodoTask(
            title: nil,
            taskDescription: "Décharger le matériel au stock",
            type: .unloadTruckAtStock,
            status: .pending,
            priority: .medium,
            eventId: event.eventId,
            truckId: event.assignedTruckId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(unloadAtStockTask)
        
        // 16. Scanner retour au stock
        let scanStockReturnTask = TodoTask(
            title: nil,
            taskDescription: "Scanner le matériel de retour au stock",
            type: .scanReturn,
            status: .pending,
            priority: .medium,
            eventId: event.eventId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(scanStockReturnTask)
        
        // 17. Ranger articles au stock
        let returnToPlaceTask = TodoTask(
            title: nil,
            taskDescription: "Remettre chaque article à sa place dans le stock",
            type: .returnItemsToPlace,
            status: .pending,
            priority: .low,
            eventId: event.eventId,
            createdBy: createdBy,
            companyId: companyId
        )
        suggestedTasks.append(returnToPlaceTask)
        
        // Chaîner les tâches (workflow)
        for i in 0..<suggestedTasks.count - 1 {
            suggestedTasks[i].nextTaskId = suggestedTasks[i + 1].taskId
            suggestedTasks[i + 1].previousTaskId = suggestedTasks[i].taskId
        }
        
        return suggestedTasks
    }
    
    // MARK: - Helper Methods
    
    /// Parser une tâche depuis Firestore
    private func parseTaskFromFirestore(_ document: DocumentSnapshot) throws -> TodoTask {
        let data = document.data() ?? [:]
        
        guard let taskId = data["taskId"] as? String,
              let title = data["title"] as? String,
              let typeRaw = data["type"] as? String,
              let statusRaw = data["status"] as? String,
              let priorityRaw = data["priority"] as? String,
              let createdBy = data["createdBy"] as? String,
              let companyId = data["companyId"] as? String,
              let _ = data["createdAt"] as? Timestamp,
              let type = TodoTask.TaskType(rawValue: typeRaw),
              let status = TodoTask.TaskStatus(rawValue: statusRaw),
              let priority = TodoTask.TaskPriority(rawValue: priorityRaw) else {
            throw NSError(domain: "TaskService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid task data"])
        }
        
        let task = TodoTask(
            taskId: taskId,
            title: title,
            taskDescription: data["taskDescription"] as? String,
            type: type,
            status: status,
            priority: priority,
            eventId: data["eventId"] as? String,
            scanListId: data["scanListId"] as? String,
            truckId: data["truckId"] as? String,
            assignedToUserId: data["assignedToUserId"] as? String,
            assignedToUserName: data["assignedToUserName"] as? String,
            createdBy: createdBy,
            companyId: companyId,
            nextTaskId: data["nextTaskId"] as? String,
            previousTaskId: data["previousTaskId"] as? String,
            triggerNotification: data["triggerNotification"] as? Bool ?? false,
            dueDate: (data["dueDate"] as? Timestamp)?.dateValue(),
            estimatedDuration: data["estimatedDuration"] as? Int,
            location: data["location"] as? String
        )
        
        // Mettre à jour les timestamps
        if let startedAtTimestamp = data["startedAt"] as? Timestamp {
            task.startedAt = startedAtTimestamp.dateValue()
        }
        if let completedAtTimestamp = data["completedAt"] as? Timestamp {
            task.completedAt = completedAtTimestamp.dateValue()
        }
        
        return task
    }
}

// MARK: - Task Statistics

struct TaskStatistics {
    var totalCount: Int = 0
    var pendingCount: Int = 0
    var inProgressCount: Int = 0
    var completedCount: Int = 0
    var cancelledCount: Int = 0
    var blockedCount: Int = 0
    var urgentCount: Int = 0
    var unassignedCount: Int = 0
    var overdueCount: Int = 0
}

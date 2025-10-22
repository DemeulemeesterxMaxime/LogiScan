//
//  TaskNotificationService.swift
//  LogiScan
//
//  Created by Demeulemeester on 19/10/2025.
//

import Foundation
import SwiftData
import FirebaseFirestore

class TaskNotificationService {
    static let shared = TaskNotificationService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Create Notification
    
    /// Créer une notification et la synchroniser avec Firebase
    func createNotification(
        taskId: String,
        taskTitle: String,
        recipientUserId: String? = nil,
        recipientRole: String? = nil,
        type: TaskNotification.NotificationType,
        message: String,
        companyId: String,
        modelContext: ModelContext
    ) throws {
        let notification = TaskNotification(
            taskId: taskId,
            taskTitle: taskTitle,
            recipientUserId: recipientUserId,
            recipientRole: recipientRole,
            type: type,
            message: message,
            companyId: companyId
        )
        
        // Sauvegarder localement
        modelContext.insert(notification)
        try modelContext.save()
        
        // Synchroniser avec Firebase
        Task {
            try await syncNotificationToFirebase(notification)
        }
        
        print("📬 Notification créée: \(type.displayName) - \(taskTitle)")
    }
    
    // MARK: - Sync to Firebase
    
    private func syncNotificationToFirebase(_ notification: TaskNotification) async throws {
        let notificationData: [String: Any] = [
            "notificationId": notification.notificationId,
            "taskId": notification.taskId,
            "taskTitle": notification.taskTitle,
            "recipientUserId": notification.recipientUserId as Any,
            "recipientRole": notification.recipientRole as Any,
            "type": notification.type.rawValue,
            "message": notification.message,
            "companyId": notification.companyId,
            "isRead": notification.isRead,
            "createdAt": Timestamp(date: notification.createdAt),
            "readAt": notification.readAt != nil ? Timestamp(date: notification.readAt!) : NSNull()
        ]
        
        try await db.collection("taskNotifications")
            .document(notification.notificationId)
            .setData(notificationData)
    }
    
    // MARK: - Mark as Read
    
    /// Marquer une notification comme lue
    func markAsRead(notificationId: String, modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<TaskNotification>(
            predicate: #Predicate { $0.notificationId == notificationId }
        )
        
        guard let notification = try modelContext.fetch(descriptor).first else {
            throw NSError(domain: "TaskNotificationService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Notification not found"])
        }
        
        notification.markAsRead()
        try modelContext.save()
        
        // Mettre à jour Firebase
        Task {
            try await db.collection("taskNotifications")
                .document(notificationId)
                .updateData([
                    "isRead": true,
                    "readAt": Timestamp(date: Date())
                ])
        }
    }
    
    // MARK: - Delete Notification
    
    /// Supprimer une notification
    func deleteNotification(notificationId: String, modelContext: ModelContext) throws {
        // Supprimer de Firebase
        Task {
            try await db.collection("taskNotifications")
                .document(notificationId)
                .delete()
        }
        
        // Supprimer localement
        let descriptor = FetchDescriptor<TaskNotification>(
            predicate: #Predicate { $0.notificationId == notificationId }
        )
        
        if let notification = try modelContext.fetch(descriptor).first {
            modelContext.delete(notification)
            try modelContext.save()
        }
    }
    
    // MARK: - Fetch Notifications
    
    /// Récupérer les notifications non lues pour un utilisateur
    func fetchUnreadNotifications(for userId: String, companyId: String) async throws -> [TaskNotification] {
        let snapshot = try await db.collection("taskNotifications")
            .whereField("companyId", isEqualTo: companyId)
            .whereField("isRead", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        var notifications: [TaskNotification] = []
        
        for document in snapshot.documents {
            if let notification = try? parseNotificationFromFirestore(document) {
                // Filtrer par utilisateur
                if notification.recipientUserId == nil || notification.recipientUserId == userId {
                    notifications.append(notification)
                }
            }
        }
        
        return notifications
    }
    
    // MARK: - Helper Methods
    
    private func parseNotificationFromFirestore(_ document: DocumentSnapshot) throws -> TaskNotification {
        let data = document.data() ?? [:]
        
        guard let notificationId = data["notificationId"] as? String,
              let taskId = data["taskId"] as? String,
              let taskTitle = data["taskTitle"] as? String,
              let typeRaw = data["type"] as? String,
              let message = data["message"] as? String,
              let companyId = data["companyId"] as? String,
              let isRead = data["isRead"] as? Bool,
              let type = TaskNotification.NotificationType(rawValue: typeRaw) else {
            throw NSError(domain: "TaskNotificationService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid notification data"])
        }
        
        let notification = TaskNotification(
            notificationId: notificationId,
            taskId: taskId,
            taskTitle: taskTitle,
            recipientUserId: data["recipientUserId"] as? String,
            recipientRole: data["recipientRole"] as? String,
            type: type,
            message: message,
            companyId: companyId,
            isRead: isRead
        )
        
        if let readAtTimestamp = data["readAt"] as? Timestamp {
            notification.readAt = readAtTimestamp.dateValue()
        }
        
        return notification
    }
}

// MARK: - Notification Triggers

extension TaskNotificationService {
    
    /// Notifier lors de l'attribution d'une tâche
    func notifyTaskAssigned(task: TodoTask, modelContext: ModelContext) throws {
        guard let assignedToUserId = task.assignedToUserId,
              let _ = task.assignedToUserName else {
            return
        }
        
        try createNotification(
            taskId: task.taskId,
            taskTitle: task.displayTitle,
            recipientUserId: assignedToUserId,
            type: .taskAssigned,
            message: "La tâche '\(task.displayTitle)' vous a été attribuée",
            companyId: task.companyId,
            modelContext: modelContext
        )
    }
    
    /// Notifier lorsqu'une tâche est prête (tâche précédente terminée)
    func notifyTaskReady(task: TodoTask, modelContext: ModelContext) throws {
        if let assignedToUserId = task.assignedToUserId {
            // Tâche attribuée → notifier la personne
            try createNotification(
                taskId: task.taskId,
                taskTitle: task.displayTitle,
                recipientUserId: assignedToUserId,
                type: .taskReady,
                message: "La tâche précédente est terminée. Vous pouvez commencer '\(task.displayTitle)'",
                companyId: task.companyId,
                modelContext: modelContext
            )
        } else {
            // Tâche libre-service → notifier toute l'équipe
            try createNotification(
                taskId: task.taskId,
                taskTitle: task.displayTitle,
                recipientUserId: nil,  // Broadcast
                type: .taskAvailable,
                message: "Nouvelle tâche disponible : '\(task.displayTitle)'",
                companyId: task.companyId,
                modelContext: modelContext
            )
        }
    }
    
    /// Notifier lors de la complétion d'une tâche
    func notifyTaskCompleted(task: TodoTask, nextTask: TodoTask?, modelContext: ModelContext) throws {
        // Si la tâche avait triggerNotification activé
        guard task.triggerNotification else { return }
        
        // Notifier le créateur de la tâche
        try createNotification(
            taskId: task.taskId,
            taskTitle: task.displayTitle,
            recipientUserId: task.createdBy,
            type: .taskCompleted,
            message: "La tâche '\(task.displayTitle)' a été terminée",
            companyId: task.companyId,
            modelContext: modelContext
        )
        
        // Si il y a une tâche suivante, la débloquer
        if let nextTask = nextTask {
            try notifyTaskReady(task: nextTask, modelContext: modelContext)
        }
    }
    
    /// Notifier lors de l'annulation d'une tâche
    func notifyTaskCancelled(task: TodoTask, reason: String?, modelContext: ModelContext) throws {
        // Notifier la personne assignée (si existante)
        if let assignedToUserId = task.assignedToUserId {
            let message = reason != nil 
                ? "La tâche '\(task.displayTitle)' a été annulée. Raison : \(reason!)"
                : "La tâche '\(task.displayTitle)' a été annulée"
            
            try createNotification(
                taskId: task.taskId,
                taskTitle: task.displayTitle,
                recipientUserId: assignedToUserId,
                type: .taskCancelled,
                message: message,
                companyId: task.companyId,
                modelContext: modelContext
            )
        }
        
        // Notifier le créateur
        if task.createdBy != task.assignedToUserId {
            try createNotification(
                taskId: task.taskId,
                taskTitle: task.displayTitle,
                recipientUserId: task.createdBy,
                type: .taskCancelled,
                message: "La tâche '\(task.displayTitle)' a été annulée",
                companyId: task.companyId,
                modelContext: modelContext
            )
        }
    }
    
    /// Notifier lors du démarrage d'une tâche
    func notifyTaskStarted(task: TodoTask, modelContext: ModelContext) throws {
        // Notifier le créateur si ce n'est pas la même personne
        guard task.createdBy != task.assignedToUserId else { return }
        
        try createNotification(
            taskId: task.taskId,
            taskTitle: task.displayTitle,
            recipientUserId: task.createdBy,
            type: .taskStarted,
            message: "La tâche '\(task.displayTitle)' a été démarrée",
            companyId: task.companyId,
            modelContext: modelContext
        )
    }
    
    /// Notifier pour les tâches en retard
    func notifyTaskOverdue(task: TodoTask, modelContext: ModelContext) throws {
        guard let assignedToUserId = task.assignedToUserId else { return }
        
        try createNotification(
            taskId: task.taskId,
            taskTitle: task.displayTitle,
            recipientUserId: assignedToUserId,
            type: .taskOverdue,
            message: "⚠️ La tâche '\(task.displayTitle)' est en retard !",
            companyId: task.companyId,
            modelContext: modelContext
        )
    }
}

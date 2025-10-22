//
//  TaskNotification.swift
//  LogiScan
//
//  Created by Demeulemeester on 18/10/2025.
//

import Foundation
import SwiftData

@Model
final class TaskNotification {
    @Attribute(.unique) var notificationId: String
    var taskId: String
    var taskTitle: String
    var recipientUserId: String?  // nil = toute l'équipe (broadcast)
    var recipientRole: String?  // Pour filtrer par rôle (User.UserRole en String)
    var type: NotificationType
    var message: String
    var isRead: Bool
    var companyId: String
    var createdAt: Date
    var readAt: Date?
    
    init(
        notificationId: String = UUID().uuidString,
        taskId: String,
        taskTitle: String,
        recipientUserId: String? = nil,
        recipientRole: String? = nil,
        type: NotificationType,
        message: String,
        companyId: String,
        isRead: Bool = false
    ) {
        self.notificationId = notificationId
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.recipientUserId = recipientUserId
        self.recipientRole = recipientRole
        self.type = type
        self.message = message
        self.companyId = companyId
        self.isRead = isRead
        self.createdAt = Date()
    }
    
    // MARK: - Helper Methods
    
    /// Marquer comme lue
    func markAsRead() {
        isRead = true
        readAt = Date()
    }
    
    /// Vérifier si la notification concerne un utilisateur spécifique
    func isForUser(_ userId: String, role: User.UserRole?) -> Bool {
        // Si recipientUserId est défini, vérifier si c'est bien l'utilisateur
        if let recipientUserId = recipientUserId {
            return recipientUserId == userId
        }
        
        // Si recipientRole est défini, vérifier si l'utilisateur a ce rôle
        if let recipientRole = recipientRole, let role = role {
            return recipientRole == role.rawValue
        }
        
        // Sinon, c'est un broadcast pour toute l'entreprise
        return true
    }
}

// MARK: - Notification Type

extension TaskNotification {
    enum NotificationType: String, Codable, CaseIterable {
        case taskAssigned = "task_assigned"
        case taskReady = "task_ready"
        case taskAvailable = "task_available"
        case taskCompleted = "task_completed"
        case taskOverdue = "task_overdue"
        case taskCancelled = "task_cancelled"
        case taskReassigned = "task_reassigned"
        case taskStarted = "task_started"
        case taskBlocked = "task_blocked"
        case taskUnblocked = "task_unblocked"
        
        var displayName: String {
            switch self {
            case .taskAssigned: return "Tâche attribuée"
            case .taskReady: return "Tâche prête"
            case .taskAvailable: return "Tâche disponible"
            case .taskCompleted: return "Tâche terminée"
            case .taskOverdue: return "Tâche en retard"
            case .taskCancelled: return "Tâche annulée"
            case .taskReassigned: return "Tâche réattribuée"
            case .taskStarted: return "Tâche démarrée"
            case .taskBlocked: return "Tâche bloquée"
            case .taskUnblocked: return "Tâche débloquée"
            }
        }
        
        var icon: String {
            switch self {
            case .taskAssigned: return "person.badge.plus"
            case .taskReady: return "checkmark.circle"
            case .taskAvailable: return "tray.2"
            case .taskCompleted: return "checkmark.circle.fill"
            case .taskOverdue: return "exclamationmark.triangle.fill"
            case .taskCancelled: return "xmark.circle.fill"
            case .taskReassigned: return "arrow.triangle.2.circlepath"
            case .taskStarted: return "play.circle.fill"
            case .taskBlocked: return "lock.fill"
            case .taskUnblocked: return "lock.open.fill"
            }
        }
        
        var color: String {
            switch self {
            case .taskAssigned: return "blue"
            case .taskReady: return "green"
            case .taskAvailable: return "orange"
            case .taskCompleted: return "green"
            case .taskOverdue: return "red"
            case .taskCancelled: return "red"
            case .taskReassigned: return "purple"
            case .taskStarted: return "blue"
            case .taskBlocked: return "gray"
            case .taskUnblocked: return "green"
            }
        }
        
        var priority: NotificationPriority {
            switch self {
            case .taskAssigned, .taskReady, .taskAvailable:
                return .normal
            case .taskOverdue:
                return .high
            case .taskCompleted, .taskStarted:
                return .low
            case .taskCancelled, .taskBlocked:
                return .normal
            case .taskReassigned, .taskUnblocked:
                return .normal
            }
        }
    }
    
    enum NotificationPriority: String, Codable {
        case low = "low"
        case normal = "normal"
        case high = "high"
        
        var displayName: String {
            switch self {
            case .low: return "Basse"
            case .normal: return "Normale"
            case .high: return "Haute"
            }
        }
    }
}

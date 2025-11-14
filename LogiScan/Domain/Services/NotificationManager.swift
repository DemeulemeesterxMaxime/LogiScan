//
//  NotificationManager.swift
//  LogiScan
//
//  Created by Assistant on 12/11/2025.
//

import Foundation
import UserNotifications
import SwiftData

/// Gestionnaire central des notifications Apple pour l'application
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    
    /// Demande l'autorisation pour les notifications
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await checkAuthorizationStatus()
            print("📬 [NotificationManager] Autorisation notifications: \(granted ? "✅ Accordée" : "❌ Refusée")")
            return granted
        } catch {
            print("❌ [NotificationManager] Erreur demande autorisation: \(error)")
            return false
        }
    }
    
    /// Vérifie le statut d'autorisation actuel
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
        
        print("📬 [NotificationManager] Statut autorisation: \(settings.authorizationStatus.rawValue)")
    }
    
    // MARK: - Task Notifications
    
    /// Notifie l'attribution d'une tâche
    func notifyTaskAssigned(task: TodoTask, userName: String) async {
        guard isAuthorized else {
            print("⚠️ [NotificationManager] Notifications non autorisées")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Nouvelle tâche assignée"
        content.body = "La tâche '\(task.displayTitle)' vous a été attribuée"
        content.sound = .default
        content.badge = NSNumber(value: await getUnreadTaskCount())
        
        // Données personnalisées pour ouvrir la tâche
        content.userInfo = [
            "type": "task_assigned",
            "taskId": task.taskId,
            "taskTitle": task.displayTitle
        ]
        
        // Catégorie pour actions rapides
        content.categoryIdentifier = "TASK_ASSIGNED"
        
        // Déclenchement immédiat
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "task_assigned_\(task.taskId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📬 [NotificationManager] Notification envoyée: Tâche assignée à \(userName)")
        } catch {
            print("❌ [NotificationManager] Erreur envoi notification: \(error)")
        }
    }
    
    /// Notifie qu'une tâche est prête (tâche précédente terminée)
    func notifyTaskReady(task: TodoTask, previousTaskTitle: String) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Tâche prête à commencer"
        content.body = "'\(previousTaskTitle)' est terminée. Vous pouvez commencer '\(task.displayTitle)'"
        content.sound = .default
        content.badge = NSNumber(value: await getUnreadTaskCount())
        
        content.userInfo = [
            "type": "task_ready",
            "taskId": task.taskId,
            "taskTitle": task.displayTitle
        ]
        
        content.categoryIdentifier = "TASK_READY"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task_ready_\(task.taskId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📬 [NotificationManager] Notification envoyée: Tâche prête")
        } catch {
            print("❌ [NotificationManager] Erreur: \(error)")
        }
    }
    
    /// Notifie qu'une tâche est disponible (broadcast pour toute l'équipe)
    func notifyTaskAvailable(task: TodoTask) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Nouvelle tâche disponible"
        content.body = "Une nouvelle tâche est disponible : '\(task.displayTitle)'"
        content.sound = .default
        content.badge = NSNumber(value: await getUnreadTaskCount())
        
        content.userInfo = [
            "type": "task_available",
            "taskId": task.taskId,
            "taskTitle": task.displayTitle
        ]
        
        content.categoryIdentifier = "TASK_AVAILABLE"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task_available_\(task.taskId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📬 [NotificationManager] Notification broadcast: Tâche disponible")
        } catch {
            print("❌ [NotificationManager] Erreur: \(error)")
        }
    }
    
    /// Notifie la complétion d'une tâche
    func notifyTaskCompleted(task: TodoTask, completedBy: String) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Tâche terminée"
        content.body = "'\(task.displayTitle)' a été terminée par \(completedBy)"
        content.sound = .default
        content.badge = NSNumber(value: await getUnreadTaskCount())
        
        content.userInfo = [
            "type": "task_completed",
            "taskId": task.taskId,
            "taskTitle": task.displayTitle
        ]
        
        content.categoryIdentifier = "TASK_COMPLETED"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task_completed_\(task.taskId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📬 [NotificationManager] Notification envoyée: Tâche complétée")
        } catch {
            print("❌ [NotificationManager] Erreur: \(error)")
        }
    }
    
    /// Notifie qu'une tâche a été annulée
    func notifyTaskCancelled(task: TodoTask, reason: String?) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Tâche annulée"
        
        if let reason = reason {
            content.body = "'\(task.displayTitle)' a été annulée. Raison : \(reason)"
        } else {
            content.body = "'\(task.displayTitle)' a été annulée"
        }
        
        content.sound = .default
        content.badge = NSNumber(value: await getUnreadTaskCount())
        
        content.userInfo = [
            "type": "task_cancelled",
            "taskId": task.taskId,
            "taskTitle": task.displayTitle
        ]
        
        content.categoryIdentifier = "TASK_CANCELLED"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task_cancelled_\(task.taskId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📬 [NotificationManager] Notification envoyée: Tâche annulée")
        } catch {
            print("❌ [NotificationManager] Erreur: \(error)")
        }
    }
    
    /// Notifie qu'une tâche est en retard
    func notifyTaskOverdue(task: TodoTask) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Tâche en retard"
        content.body = "La tâche '\(task.displayTitle)' est en retard !"
        content.sound = UNNotificationSound.defaultCritical
        content.badge = NSNumber(value: await getUnreadTaskCount())
        
        content.userInfo = [
            "type": "task_overdue",
            "taskId": task.taskId,
            "taskTitle": task.displayTitle
        ]
        
        content.categoryIdentifier = "TASK_OVERDUE"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task_overdue_\(task.taskId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📬 [NotificationManager] Notification envoyée: Tâche en retard")
        } catch {
            print("❌ [NotificationManager] Erreur: \(error)")
        }
    }
    
    // MARK: - Scan List Notifications
    
    /// Notifie qu'une liste de scan est complète
    func notifyScanListCompleted(scanList: ScanList, eventName: String) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "✅ Liste de scan terminée"
        content.body = "Liste '\(scanList.displayName)' pour '\(eventName)' est complète"
        content.sound = .default
        
        content.userInfo = [
            "type": "scan_list_completed",
            "scanListId": scanList.scanListId,
            "eventId": scanList.eventId
        ]
        
        content.categoryIdentifier = "SCAN_LIST_COMPLETED"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "scan_list_completed_\(scanList.scanListId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📬 [NotificationManager] Notification: Liste de scan complète")
        } catch {
            print("❌ [NotificationManager] Erreur: \(error)")
        }
    }
    
    // MARK: - Utility
    
    /// Supprime une notification par identifiant
    func removeNotification(identifier: String) {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        print("🗑️ [NotificationManager] Notification supprimée: \(identifier)")
    }
    
    /// Supprime toutes les notifications
    func removeAllNotifications() {
        center.removeAllDeliveredNotifications()
        print("🗑️ [NotificationManager] Toutes les notifications supprimées")
    }
    
    /// Badge app avec le nombre de tâches non lues
    private func getUnreadTaskCount() async -> Int {
        // TODO: Implémenter avec SwiftData
        return 0
    }
    
    // MARK: - Notification Categories Setup
    
    /// Configure les catégories de notifications avec actions rapides
    func setupNotificationCategories() {
        // Catégorie: Tâche assignée
        let viewTaskAction = UNNotificationAction(
            identifier: "VIEW_TASK",
            title: "Voir la tâche",
            options: .foreground
        )
        
        let startTaskAction = UNNotificationAction(
            identifier: "START_TASK",
            title: "Commencer",
            options: .foreground
        )
        
        let taskAssignedCategory = UNNotificationCategory(
            identifier: "TASK_ASSIGNED",
            actions: [viewTaskAction, startTaskAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Catégorie: Tâche prête
        let taskReadyCategory = UNNotificationCategory(
            identifier: "TASK_READY",
            actions: [viewTaskAction, startTaskAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Catégorie: Tâche disponible
        let taskAvailableCategory = UNNotificationCategory(
            identifier: "TASK_AVAILABLE",
            actions: [viewTaskAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Catégorie: Tâche complétée
        let taskCompletedCategory = UNNotificationCategory(
            identifier: "TASK_COMPLETED",
            actions: [viewTaskAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Catégorie: Tâche annulée
        let taskCancelledCategory = UNNotificationCategory(
            identifier: "TASK_CANCELLED",
            actions: [viewTaskAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Catégorie: Tâche en retard
        let taskOverdueCategory = UNNotificationCategory(
            identifier: "TASK_OVERDUE",
            actions: [viewTaskAction, startTaskAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Catégorie: Liste de scan complète
        let scanListCompletedCategory = UNNotificationCategory(
            identifier: "SCAN_LIST_COMPLETED",
            actions: [viewTaskAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Enregistrer toutes les catégories
        center.setNotificationCategories([
            taskAssignedCategory,
            taskReadyCategory,
            taskAvailableCategory,
            taskCompletedCategory,
            taskCancelledCategory,
            taskOverdueCategory,
            scanListCompletedCategory
        ])
        
        print("📬 [NotificationManager] Catégories de notifications configurées")
    }
}

//
//  NotificationCenterView.swift
//  LogiScan
//
//  Created by Demeulemeester on 19/10/2025.
//

import SwiftUI
import SwiftData

struct NotificationCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService()
    
    @Query(sort: \TaskNotification.createdAt, order: .reverse)
    private var allNotifications: [TaskNotification]
    
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showingTaskDetail = false
    @State private var selectedTaskId: String?
    
    private var currentUserId: String? {
        authService.currentUserId
    }
    
    private var currentUser: User? {
        guard let userId = currentUserId else { return nil }
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.userId == userId
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    // Filtrer les notifications pour l'utilisateur actuel
    private var userNotifications: [TaskNotification] {
        guard let currentUser = currentUser else { return [] }
        
        return allNotifications.filter { notification in
            notification.companyId == (currentUser.companyId ?? "") &&
            notification.isForUser(currentUser.userId, role: currentUser.role)
        }
    }
    
    private var unreadNotifications: [TaskNotification] {
        userNotifications.filter { !$0.isRead }
    }
    
    private var readNotifications: [TaskNotification] {
        userNotifications.filter { $0.isRead }
    }
    
    private var filteredNotifications: [TaskNotification] {
        switch selectedFilter {
        case .all:
            return userNotifications
        case .unread:
            return unreadNotifications
        case .type(let type):
            return userNotifications.filter { $0.type == type }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filtres
                filterSection
                
                if filteredNotifications.isEmpty {
                    emptyStateView
                } else {
                    // Liste des notifications
                    List {
                        if selectedFilter == .all {
                            // Section Non lues
                            if !unreadNotifications.isEmpty {
                                Section {
                                    ForEach(unreadNotifications, id: \.notificationId) { notification in
                                        NotificationRow(
                                            notification: notification,
                                            onTap: {
                                                handleNotificationTap(notification)
                                            },
                                            onMarkAsRead: {
                                                markAsRead(notification)
                                            },
                                            onDelete: {
                                                deleteNotification(notification)
                                            }
                                        )
                                    }
                                } header: {
                                    Text("Non lues (\(unreadNotifications.count))")
                                }
                            }
                            
                            // Section Lues
                            if !readNotifications.isEmpty {
                                Section {
                                    ForEach(readNotifications, id: \.notificationId) { notification in
                                        NotificationRow(
                                            notification: notification,
                                            onTap: {
                                                handleNotificationTap(notification)
                                            },
                                            onMarkAsRead: {
                                                markAsRead(notification)
                                            },
                                            onDelete: {
                                                deleteNotification(notification)
                                            }
                                        )
                                    }
                                } header: {
                                    Text("Lues")
                                }
                            }
                        } else {
                            // Liste simple pour les filtres
                            ForEach(filteredNotifications, id: \.notificationId) { notification in
                                NotificationRow(
                                    notification: notification,
                                    onTap: {
                                        handleNotificationTap(notification)
                                    },
                                    onMarkAsRead: {
                                        markAsRead(notification)
                                    },
                                    onDelete: {
                                        deleteNotification(notification)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !unreadNotifications.isEmpty {
                        Button {
                            markAllAsRead()
                        } label: {
                            Text("Tout marquer lu")
                                .font(.subheadline)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingTaskDetail) {
                if let taskId = selectedTaskId {
                    TaskDetailNavigationView(taskId: taskId)
                }
            }
        }
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                NotificationFilterChip(
                    title: "Toutes",
                    count: userNotifications.count,
                    isSelected: selectedFilter == .all
                ) {
                    selectedFilter = .all
                }
                
                NotificationFilterChip(
                    title: "Non lues",
                    count: unreadNotifications.count,
                    isSelected: selectedFilter == .unread
                ) {
                    selectedFilter = .unread
                }
                
                // Filtres par type
                ForEach(TaskNotification.NotificationType.allCases, id: \.self) { type in
                    let count = userNotifications.filter { $0.type == type }.count
                    if count > 0 {
                        NotificationFilterChip(
                            title: type.displayName,
                            count: count,
                            isSelected: selectedFilter == .type(type)
                        ) {
                            selectedFilter = .type(type)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Aucune notification")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "Vous n'avez aucune notification pour le moment"
        case .unread:
            return "Toutes vos notifications ont été lues"
        case .type(let type):
            return "Aucune notification de type \"\(type.displayName)\""
        }
    }
    
    // MARK: - Actions
    
    private func handleNotificationTap(_ notification: TaskNotification) {
        // Marquer comme lue
        markAsRead(notification)
        
        // Ouvrir la tâche associée
        selectedTaskId = notification.taskId
        showingTaskDetail = true
    }
    
    private func markAsRead(_ notification: TaskNotification) {
        guard !notification.isRead else { return }
        
        notification.markAsRead()
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Erreur marquage notification comme lue: \(error)")
        }
    }
    
    private func markAllAsRead() {
        for notification in unreadNotifications {
            notification.markAsRead()
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Erreur marquage toutes notifications: \(error)")
        }
    }
    
    private func deleteNotification(_ notification: TaskNotification) {
        modelContext.delete(notification)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Erreur suppression notification: \(error)")
        }
    }
}

// MARK: - Notification Filter

enum NotificationFilter: Equatable {
    case all
    case unread
    case type(TaskNotification.NotificationType)
}

// MARK: - Filter Chip

struct NotificationFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: TaskNotification
    let onTap: () -> Void
    let onMarkAsRead: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Icône
                ZStack {
                    Circle()
                        .fill(typeColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(typeColor)
                }
                
                // Contenu
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(notification.type.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if !notification.isRead {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.taskTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(notification.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    Text(notification.createdAt.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
            
            if !notification.isRead {
                Button {
                    onMarkAsRead()
                } label: {
                    Label("Lu", systemImage: "checkmark")
                }
                .tint(.blue)
            }
        }
        .listRowBackground(notification.isRead ? Color.clear : Color.blue.opacity(0.05))
    }
    
    private var typeColor: Color {
        switch notification.type.color {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "gray": return .gray
        default: return .blue
        }
    }
}

// MARK: - Task Detail Navigation View

struct TaskDetailNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let taskId: String
    
    @State private var task: TodoTask?
    
    var body: some View {
        NavigationStack {
            if let task = task {
                TaskDetailView(task: task)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Fermer") {
                                dismiss()
                            }
                        }
                    }
            } else {
                ContentUnavailableView(
                    "Tâche introuvable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Cette tâche n'existe plus ou a été supprimée")
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Fermer") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            loadTask()
        }
    }
    
    private func loadTask() {
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate<TodoTask> { task in
                task.taskId == taskId
            }
        )
        
        task = try? modelContext.fetch(descriptor).first
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TaskNotification.self, TodoTask.self, User.self,
        configurations: config
    )
    
    // Créer des notifications de test
    let notification1 = TaskNotification(
        taskId: "task1",
        taskTitle: "Préparer les articles",
        recipientUserId: "user1",
        type: .taskAssigned,
        message: "La tâche 'Préparer les articles' vous a été attribuée",
        companyId: "company1",
        isRead: false
    )
    
    let notification2 = TaskNotification(
        taskId: "task2",
        taskTitle: "Scanner chargement",
        recipientUserId: "user1",
        type: .taskReady,
        message: "La tâche précédente est terminée, vous pouvez commencer",
        companyId: "company1",
        isRead: true
    )
    
    container.mainContext.insert(notification1)
    container.mainContext.insert(notification2)
    
    return NotificationCenterView()
        .modelContainer(container)
}

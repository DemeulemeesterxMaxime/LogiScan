//
//  TodoListView.swift
//  LogiScan
//
//  Created by Demeulemeester on 18/10/2025.
//

import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var permissionService = PermissionService.shared
    
    // Filtres
    @State private var selectedFilter: TaskFilter
    @State private var selectedStatus: TodoTask.TaskStatus?
    @State private var selectedPriority: TodoTask.TaskPriority?
    @State private var searchText = ""
    
    // Données
    @State private var tasks: [TodoTask] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Navigation
    @State private var selectedTask: TodoTask?
    @State private var showingCreateTask = false
    
    // Initializer avec filtre par défaut
    init(defaultFilter: TaskFilter = .myTasks) {
        _selectedFilter = State(initialValue: defaultFilter)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filtres principaux
            filterSegmentedControl
            
            // Filtres secondaires (statut, priorité)
            secondaryFilters
            
            if isLoading {
                ProgressView("Chargement des tâches...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tasks.isEmpty {
                emptyStateView
            } else {
                tasksList
            }
        }
        .navigationTitle("Mes Tâches")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Rechercher une tâche")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if permissionService.checkPermission(.writeTasks) {
                    Button {
                        showingCreateTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateTask) {
            CreateTaskView()
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .alert("Erreur", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Une erreur est survenue")
        }
        .onAppear {
            loadTasks()
        }
        .refreshable {
            await refreshTasks()
        }
    }
    
    // MARK: - Filter Segmented Control
    
    private var filterSegmentedControl: some View {
        Picker("Filtre", selection: $selectedFilter) {
            Text("Mes tâches").tag(TaskFilter.myTasks)
            Text("Libre-service").tag(TaskFilter.unassigned)
            
            if permissionService.checkPermission(.manageTasks) {
                Text("Toutes").tag(TaskFilter.all)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .onChange(of: selectedFilter) { _, _ in
            loadTasks()
        }
    }
    
    // MARK: - Secondary Filters
    
    private var secondaryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Filtre par statut
                Menu {
                    Button {
                        selectedStatus = nil
                    } label: {
                        Label("Tous les statuts", systemImage: selectedStatus == nil ? "checkmark" : "")
                    }
                    
                    Divider()
                    
                    ForEach([TodoTask.TaskStatus.pending, .inProgress, .blocked], id: \.self) { status in
                        Button {
                            selectedStatus = status
                        } label: {
                            Label(status.displayName, systemImage: selectedStatus == status ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedStatus?.displayName ?? "Statut")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedStatus != nil ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(selectedStatus != nil ? .white : .primary)
                    .cornerRadius(20)
                }
                
                // Filtre par priorité
                Menu {
                    Button {
                        selectedPriority = nil
                    } label: {
                        Label("Toutes les priorités", systemImage: selectedPriority == nil ? "checkmark" : "")
                    }
                    
                    Divider()
                    
                    ForEach([TodoTask.TaskPriority.urgent, .high, .medium, .low], id: \.self) { priority in
                        Button {
                            selectedPriority = priority
                        } label: {
                            Label(priority.displayName, systemImage: selectedPriority == priority ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                        Text(selectedPriority?.displayName ?? "Priorité")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedPriority != nil ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(selectedPriority != nil ? .white : .primary)
                    .cornerRadius(20)
                }
                
                // Réinitialiser les filtres
                if selectedStatus != nil || selectedPriority != nil {
                    Button {
                        selectedStatus = nil
                        selectedPriority = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
        .onChange(of: selectedStatus) { _, _ in
            loadTasks()
        }
        .onChange(of: selectedPriority) { _, _ in
            loadTasks()
        }
    }
    
    // MARK: - Tasks List
    
    private var tasksList: some View {
        List {
            ForEach(groupedTasks.keys.sorted(by: sortStatuses), id: \.self) { status in
                Section {
                    ForEach(groupedTasks[status] ?? []) { task in
                        TaskRowView(task: task)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTask = task
                            }
                    }
                } header: {
                    HStack {
                        Circle()
                            .fill(status.swiftUIColor)
                            .frame(width: 8, height: 8)
                        
                        Text(status.displayName)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(groupedTasks[status]?.count ?? 0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedFilter == .myTasks ? "checkmark.circle" : "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(emptyStateTitle)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if selectedFilter == .unassigned && permissionService.checkPermission(.writeTasks) {
                Button {
                    showingCreateTask = true
                } label: {
                    Label("Créer une tâche", systemImage: "plus.circle.fill")
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .myTasks:
            return "Aucune tâche assignée"
        case .unassigned:
            return "Aucune tâche disponible"
        case .all:
            return "Aucune tâche"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .myTasks:
            return "Vous n'avez aucune tâche assignée pour le moment. Consultez les tâches en libre-service ou attendez qu'on vous en attribue."
        case .unassigned:
            return "Il n'y a pas de tâches en libre-service disponibles. Consultez vos tâches assignées."
        case .all:
            return "Aucune tâche n'a été créée pour votre entreprise."
        }
    }
    
    // MARK: - Data Loading
    
    private func loadTasks() {
        guard let currentUser = permissionService.currentUser,
              let companyId = currentUser.companyId else {
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let fetchedTasks: [TodoTask]
                
                switch selectedFilter {
                case .myTasks:
                    fetchedTasks = try await TaskService.shared.fetchTasksForUser(
                        userId: currentUser.userId,
                        companyId: companyId
                    )
                    
                case .unassigned:
                    fetchedTasks = try await TaskService.shared.fetchUnassignedTasks(for: companyId)
                    
                case .all:
                    fetchedTasks = try await TaskService.shared.fetchTasks(for: companyId)
                }
                
                await MainActor.run {
                    self.tasks = fetchedTasks
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Erreur lors du chargement: \(error.localizedDescription)"
                    self.showingError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func refreshTasks() async {
        guard let currentUser = permissionService.currentUser,
              let companyId = currentUser.companyId else {
            return
        }
        
        do {
            let fetchedTasks: [TodoTask]
            
            switch selectedFilter {
            case .myTasks:
                fetchedTasks = try await TaskService.shared.fetchTasksForUser(
                    userId: currentUser.userId,
                    companyId: companyId
                )
                
            case .unassigned:
                fetchedTasks = try await TaskService.shared.fetchUnassignedTasks(for: companyId)
                
            case .all:
                fetchedTasks = try await TaskService.shared.fetchTasks(for: companyId)
            }
            
            await MainActor.run {
                self.tasks = fetchedTasks
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Erreur lors du chargement: \(error.localizedDescription)"
                self.showingError = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredTasks: [TodoTask] {
        var result = tasks
        
        // Filtre par statut
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }
        
        // Filtre par priorité
        if let priority = selectedPriority {
            result = result.filter { $0.priority == priority }
        }
        
        // Filtre par recherche
        if !searchText.isEmpty {
            result = result.filter { task in
                (task.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (task.taskDescription?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                task.type.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    private var groupedTasks: [TodoTask.TaskStatus: [TodoTask]] {
        Dictionary(grouping: filteredTasks, by: \.status)
    }
    
    private func sortStatuses(_ lhs: TodoTask.TaskStatus, _ rhs: TodoTask.TaskStatus) -> Bool {
        let order: [TodoTask.TaskStatus] = [.blocked, .inProgress, .pending, .completed, .cancelled]
        return order.firstIndex(of: lhs) ?? 0 < order.firstIndex(of: rhs) ?? 0
    }
}

// MARK: - Task Filter Enum

enum TaskFilter {
    case myTasks
    case unassigned
    case all
}

// MARK: - Task Row View

struct TaskRowView: View {
    let task: TodoTask
    
    var body: some View {
        HStack(spacing: 12) {
            // Icône du type de tâche
            Image(systemName: task.type.icon)
                .font(.title2)
                .foregroundColor(task.priority.swiftUIColor)
                .frame(width: 40, height: 40)
                .background(task.priority.swiftUIColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                // Titre
                Text(task.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                // Description ou type
                Text(task.taskDescription ?? task.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Informations supplémentaires
                HStack(spacing: 8) {
                    // Priorité
                    Label(task.priority.displayName, systemImage: task.priority.icon)
                        .font(.caption)
                        .foregroundColor(task.priority.swiftUIColor)
                    
                    // Attribution
                    if let userName = task.assignedToUserName {
                        Label(userName, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Label("Libre-service", systemImage: "person.crop.circle.badge.questionmark")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    // Date d'échéance
                    if let dueDate = task.dueDate {
                        let isOverdue = dueDate < Date() && task.status != .completed
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), 
                              systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(isOverdue ? .red : .secondary)
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TodoListView()
        .modelContainer(for: [TodoTask.self], inMemory: true)
}

//
//  AdminTaskManagementView.swift
//  LogiScan
//
//  Created by Demeulemeester on 18/10/2025.
//

import SwiftUI
import SwiftData
import Charts

struct AdminTaskManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var permissionService = PermissionService.shared
    
    // Données
    @State private var tasks: [TodoTask] = []
    @State private var taskStats: TaskStatistics?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Navigation
    @State private var selectedTask: TodoTask?
    @State private var showingCreateTask = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // En-tête avec statistiques
                    if let stats = taskStats {
                        statisticsSection(stats: stats)
                    }
                    
                    // Graphiques
                    if let stats = taskStats {
                        chartsSection(stats: stats)
                    }
                    
                    // Liste des tâches par priorité
                    tasksByPrioritySection
                    
                    // Tâches en retard
                    overdueTasksSection
                    
                    // Actions rapides
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("Gestion des tâches")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingCreateTask) {
                NavigationStack {
                    CreateTaskView()
                }
            }
            .sheet(item: $selectedTask) { task in
                NavigationStack {
                    TaskDetailView(task: task)
                }
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Une erreur est survenue")
            }
            .onAppear {
                loadData()
            }
            .refreshable {
                await refreshData()
            }
            .overlay {
                if isLoading {
                    ProgressView("Chargement...")
                        .padding()
                        .background(Color(.systemBackground).opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private func statisticsSection(stats: TaskStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vue d'ensemble")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                spacing: 12
            ) {
                TaskStatCard(
                    title: "Total",
                    value: "\(stats.totalCount)",
                    icon: "list.bullet.clipboard",
                    color: .blue
                )
                
                TaskStatCard(
                    title: "En cours",
                    value: "\(stats.inProgressCount)",
                    icon: "circle.hexagongrid.circle.fill",
                    color: .green
                )
                
                TaskStatCard(
                    title: "Urgentes",
                    value: "\(stats.urgentCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
                
                TaskStatCard(
                    title: "En retard",
                    value: "\(stats.overdueCount)",
                    icon: "clock.badge.exclamationmark.fill",
                    color: .orange
                )
                
                TaskStatCard(
                    title: "Non attribuées",
                    value: "\(stats.unassignedCount)",
                    icon: "person.crop.circle.badge.questionmark",
                    color: .purple
                )
                
                TaskStatCard(
                    title: "Terminées",
                    value: "\(stats.completedCount)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Charts Section
    
    private func chartsSection(stats: TaskStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Répartition")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Graphique par statut
            VStack(alignment: .leading, spacing: 8) {
                Text("Par statut")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                let statusData = [
                    StatusChartData(status: "En attente", count: stats.pendingCount, color: .blue),
                    StatusChartData(status: "En cours", count: stats.inProgressCount, color: .green),
                    StatusChartData(status: "Bloquées", count: stats.blockedCount, color: .orange),
                    StatusChartData(status: "Terminées", count: stats.completedCount, color: .gray)
                ].filter { $0.count > 0 }
                
                if !statusData.isEmpty {
                    Chart(statusData) { data in
                        SectorMark(
                            angle: .value("Count", data.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(data.color)
                        .annotation(position: .overlay) {
                            Text("\(data.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 180)
                    
                    // Légende
                    HStack(spacing: 16) {
                        ForEach(statusData, id: \.status) { data in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(data.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(data.status)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Text("Aucune donnée à afficher")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Tasks by Priority Section
    
    private var tasksByPrioritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tâches par priorité")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink {
                    TodoListView()
                } label: {
                    Text("Voir tout")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            
            VStack(spacing: 8) {
                ForEach([TodoTask.TaskPriority.urgent, .high, .medium, .low], id: \.self) { priority in
                    let priorityTasks = tasks.filter { 
                        $0.priority == priority && 
                        $0.status != .completed && 
                        $0.status != .cancelled 
                    }
                    
                    if !priorityTasks.isEmpty {
                        PriorityRow(
                            priority: priority,
                            count: priorityTasks.count,
                            tasks: Array(priorityTasks.prefix(3))
                        ) { task in
                            selectedTask = task
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Overdue Tasks Section
    
    private var overdueTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tâches en retard")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !overdueTasks.isEmpty {
                    Text("\(overdueTasks.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(12)
                }
            }
            
            if overdueTasks.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Aucune tâche en retard")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(overdueTasks.prefix(5)) { task in
                        OverdueTaskRow(task: task)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTask = task
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("quick_actions".localized())
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                spacing: 12
            ) {
                Button {
                    showingCreateTask = true
                } label: {
                    ActionCard(
                        icon: "plus.circle.fill",
                        title: "Créer une tâche",
                        color: .blue
                    )
                }
                
                NavigationLink {
                    TodoListView()
                } label: {
                    ActionCard(
                        icon: "list.bullet.clipboard.fill",
                        title: "Toutes les tâches",
                        color: .green
                    )
                }
                
                Button {
                    // TODO: Export rapport
                } label: {
                    ActionCard(
                        icon: "arrow.down.doc.fill",
                        title: "Exporter rapport",
                        color: .orange
                    )
                }
                
                Button {
                    // TODO: Statistiques avancées
                } label: {
                    ActionCard(
                        icon: "chart.bar.fill",
                        title: "Statistiques",
                        color: .purple
                    )
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        guard let companyId = permissionService.currentUser?.companyId else { return }
        
        isLoading = true
        
        Task {
            do {
                async let tasksResult = TaskService.shared.fetchTasks(for: companyId)
                async let statsResult = TaskService.shared.getTaskStatistics(for: companyId)
                
                let (fetchedTasks, fetchedStats) = try await (tasksResult, statsResult)
                
                await MainActor.run {
                    self.tasks = fetchedTasks
                    self.taskStats = fetchedStats
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
    
    private func refreshData() async {
        guard let companyId = permissionService.currentUser?.companyId else { return }
        
        do {
            async let tasksResult = TaskService.shared.fetchTasks(for: companyId)
            async let statsResult = TaskService.shared.getTaskStatistics(for: companyId)
            
            let (fetchedTasks, fetchedStats) = try await (tasksResult, statsResult)
            
            await MainActor.run {
                self.tasks = fetchedTasks
                self.taskStats = fetchedStats
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Erreur lors du chargement: \(error.localizedDescription)"
                self.showingError = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var overdueTasks: [TodoTask] {
        let now = Date()
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now && task.status != .completed && task.status != .cancelled
        }.sorted { ($0.dueDate ?? Date()) < ($1.dueDate ?? Date()) }
    }
}

// MARK: - Task Stat Card

struct TaskStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Status Chart Data

struct StatusChartData: Identifiable {
    let id = UUID()
    let status: String
    let count: Int
    let color: Color
}

// MARK: - Priority Row

struct PriorityRow: View {
    let priority: TodoTask.TaskPriority
    let count: Int
    let tasks: [TodoTask]
    let onTaskTap: (TodoTask) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(priority.displayName, systemImage: priority.icon)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(priority.swiftUIColor)
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priority.swiftUIColor)
                    .cornerRadius(12)
            }
            
            ForEach(tasks) { task in
                Button {
                    onTaskTap(task)
                } label: {
                    HStack {
                        Circle()
                            .fill(task.status.swiftUIColor)
                            .frame(width: 8, height: 8)
                        
                        Text(task.displayTitle)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(priority.swiftUIColor.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Overdue Task Row

struct OverdueTaskRow: View {
    let task: TodoTask
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let dueDate = task.dueDate {
                    let daysOverdue = Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
                    Text("En retard de \(daysOverdue) jour\(daysOverdue > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Label(task.priority.displayName, systemImage: task.priority.icon)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(task.priority.swiftUIColor)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Action Card

struct ActionCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    AdminTaskManagementView()
        .modelContainer(for: [TodoTask.self], inMemory: true)
}

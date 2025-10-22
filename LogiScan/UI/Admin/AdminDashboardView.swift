//
//  AdminDashboardView.swift
//  LogiScan
//
//  Created by Demeulemeester on 18/10/2025.
//

import Charts
import FirebaseAuth
import SwiftData
import SwiftUI

struct AdminDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stockItems: [StockItem]
    @Query private var movements: [Movement]
    @Query private var assets: [Asset]
    @Query private var events: [Event]
    @Query private var allTasks: [TodoTask]
    @Query private var users: [User]
    @StateObject private var syncManager = SyncManager()
    
    @State private var permissionService = PermissionService.shared
    @State private var selectedPeriod: DashboardPeriod = .today
    @State private var isRefreshing = false
    @State private var showingNotifications = false
    @State private var showingCreateTask = false
    @State private var showingAllTasks = false
    
    @Query private var allUsers: [User]
    
    // Computed property pour l'utilisateur actuel
    private var currentUser: User? {
        // Récupérer l'utilisateur depuis Firebase Auth
        guard let firebaseUser = Auth.auth().currentUser else { return nil }
        // Trouver l'utilisateur correspondant dans SwiftData
        return allUsers.first { $0.userId == firebaseUser.uid }
    }
    
    // Tâches filtrées par companyId
    private var companyTasks: [TodoTask] {
        guard let companyId = currentUser?.companyId else { return [] }
        return allTasks.filter { $0.companyId == companyId }
    }
    
    // Tâches urgentes (high/urgent priority et pas completed/cancelled)
    private var urgentTasks: [TodoTask] {
        companyTasks.filter { task in
            (task.priority == .high || task.priority == .urgent) &&
            (task.status != .completed && task.status != .cancelled)
        }
    }
    
    // Tâches en cours
    private var inProgressTasks: [TodoTask] {
        companyTasks.filter { $0.status == .inProgress }
    }
    
    // Tâches non attribuées (libre-service)
    private var unassignedTasks: [TodoTask] {
        companyTasks.filter { task in
            task.assignedToUserId == nil &&
            task.status != .completed &&
            task.status != .cancelled
        }
    }
    
    // Tâches complétées aujourd'hui
    private var tasksCompletedToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return companyTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= today && completedAt < tomorrow
        }.count
    }
    
    private var assetsOK: Int {
        assets.filter { $0.status == .available }.count
    }
    
    var todayMovementsCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return movements.filter { movement in
            movement.timestamp >= today && movement.timestamp < tomorrow
        }.count
    }
    
    var activeEvents: Int {
        let now = Date()
        return events.filter { event in
            let startDate = event.startDate
            let endDate = event.endDate
            return startDate <= now && now <= endDate
        }.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Date du jour en haut
                    HStack {
                        Text(Date().formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if syncManager.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Header avec période sélectionnée
                    periodSelector
                    
                    // SECTION 1: Stats globales
                    metricsGrid
                    
                    // SECTION 2: TodoList entreprise
                    todoListSection
                    
                    // SECTION 3: Activité équipe
                    teamActivitySection
                    
                    // SECTION 4: Graphiques
                    chartsSection
                    
                    // SECTION 4: Actions rapides
                    quickActionsSection
                }
                .padding()
            }
            .refreshable {
                await syncManager.syncFromFirebase(modelContext: modelContext)
            }
            .navigationTitle("Dashboard Admin")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingNotifications = true
                        } label: {
                            Image(systemName: "bell.fill")
                        }
                        
                        NavigationLink(destination: ProfileView()) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        NavigationLink(destination: AdminView()) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationCenterView()
            }
            .sheet(isPresented: $showingCreateTask) {
                CreateTaskView()
            }
            .overlay {
                if syncManager.isSyncing {
                    VStack {
                        ProgressView("Synchronisation...")
                            .padding()
                            .background(Color(.systemBackground).opacity(0.9))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
            }
            .onAppear {
                Task {
                    await syncManager.syncFromFirebaseIfNeeded(
                        modelContext: modelContext, forceRefresh: true)
                }
            }
        }
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(DashboardPeriod.allCases, id: \.self) { period in
                    periodButton(for: period)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func periodButton(for period: DashboardPeriod) -> some View {
        Button(action: {
            selectedPeriod = period
        }) {
            Text(period.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            selectedPeriod == period ? Color.accentColor : Color.gray.opacity(0.2))
                )
                .foregroundColor(selectedPeriod == period ? .white : .primary)
        }
    }
    
    // MARK: - SECTION 1: Metrics Grid
    
    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vue d'ensemble")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16
            ) {
                MetricCard(
                    title: "Événements actifs",
                    value: "\(activeEvents)",
                    change: nil,
                    icon: "calendar.badge.clock",
                    color: .red
                )
                
                MetricCard(
                    title: "Mouvements aujourd'hui",
                    value: "\(todayMovementsCount)",
                    change: nil,
                    icon: "arrow.left.arrow.right.circle.fill",
                    color: .purple
                )
                
                MetricCard(
                    title: "Assets actifs",
                    value: "\(assetsOK)",
                    change: nil,
                    icon: "cube.box.fill",
                    color: .blue
                )
                
                MetricCard(
                    title: "Stock total",
                    value: "\(stockItems.map(\.totalQuantity).reduce(0, +))",
                    change: nil,
                    icon: "square.stack.3d.up.fill",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - SECTION 2: TodoList (Real Data)
    
    private var todoListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tâches de l'entreprise")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink {
                    AdminTaskManagementView()
                } label: {
                    Text("Voir tout")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            
            VStack(spacing: 12) {
                // Tâches urgentes
                NavigationLink {
                    AdminTaskManagementView()
                } label: {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tâches urgentes")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(urgentTasks.isEmpty ? "Aucune tâche urgente" : "\(urgentTasks.count) tâche\(urgentTasks.count > 1 ? "s" : "") nécessite\(urgentTasks.count > 1 ? "nt" : "") votre attention")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(urgentTasks.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(urgentTasks.isEmpty ? Color.gray.opacity(0.1) : Color.red.opacity(0.1))
                    )
                }
                
                // Tâches en cours
                NavigationLink {
                    AdminTaskManagementView()
                } label: {
                    HStack {
                        Image(systemName: "circle.hexagongrid.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tâches en cours")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(inProgressTasks.isEmpty ? "Aucune tâche en cours" : "Actuellement en cours par l'équipe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(inProgressTasks.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                // Tâches non attribuées (libre-service)
                NavigationLink {
                    AdminTaskManagementView()
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .foregroundColor(.orange)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tâches non attribuées")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(unassignedTasks.isEmpty ? "Toutes les tâches sont attribuées" : "En libre-service pour l'équipe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(unassignedTasks.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - SECTION 3: Team Activity
    
    private var teamActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activité de l'équipe")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Qui fait quoi en temps réel
                whoIsDoingWhatCard
                
                // Performance par personne
                performanceCard
                
                // Tâches complétées aujourd'hui
                tasksCompletedTodayCard
            }
        }
    }
    
    private var whoIsDoingWhatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            whoIsDoingWhatHeader
            
            if inProgressTasks.isEmpty {
                emptyInProgressView
            } else {
                inProgressTasksList
            }
        }
        .padding()
        .background(cardBackground)
    }
    
    private var whoIsDoingWhatHeader: some View {
        HStack {
            Image(systemName: "person.3.fill")
                .foregroundColor(.blue)
            Text("Qui fait quoi")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
        }
    }
    
    private var emptyInProgressView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                Text("Aucune tâche en cours")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
    
    private var inProgressTasksList: some View {
        VStack(spacing: 12) {
            ForEach(inProgressTasks.prefix(5), id: \.taskId) { task in
                taskInProgressRow(task)
            }
            
            if inProgressTasks.count > 5 {
                moreTasksLink
            }
        }
    }
    
    private func taskInProgressRow(_ task: TodoTask) -> some View {
        HStack(spacing: 12) {
            taskAvatar(name: task.assignedToUserName ?? "?", color: .blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.assignedToUserName ?? "Non attribué")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(task.displayTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: task.type.icon)
                .foregroundColor(Color(task.priority.color))
                .font(.caption)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    private func taskAvatar(name: String, color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.2))
            .frame(width: 36, height: 36)
            .overlay {
                Text(getInitials(for: name))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
    }
    
    private var moreTasksLink: some View {
        NavigationLink {
            AdminTaskManagementView()
        } label: {
            HStack {
                Spacer()
                Text("Voir \(inProgressTasks.count - 5) de plus")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var performanceCard: some View {
        let userPerformance = calculateUserPerformance()
        
        return VStack(alignment: .leading, spacing: 12) {
            performanceHeader
            
            if userPerformance.isEmpty {
                emptyPerformanceView
            } else {
                performanceList(userPerformance)
            }
        }
        .padding()
        .background(cardBackground)
    }
    
    private var performanceHeader: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .foregroundColor(.purple)
            Text("Performance par personne")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
        }
    }
    
    private var emptyPerformanceView: some View {
        HStack {
            Spacer()
            Text("Aucune donnée de performance disponible")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 20)
            Spacer()
        }
    }
    
    private func performanceList(_ userPerformance: [UserPerformance]) -> some View {
        let sorted = userPerformance.sorted(by: { $0.tasksCompleted > $1.tasksCompleted })
        let maxCompleted = userPerformance.map(\.tasksCompleted).max() ?? 1
        
        return VStack(spacing: 12) {
            ForEach(sorted.prefix(5), id: \.userId) { performance in
                performanceRow(performance, maxCompleted: maxCompleted)
            }
        }
    }
    
    private func performanceRow(_ performance: UserPerformance, maxCompleted: Int) -> some View {
        HStack(spacing: 12) {
            taskAvatar(name: performance.userName, color: .purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(performance.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(performance.tasksCompleted) tâche\(performance.tasksCompleted > 1 ? "s" : "") terminée\(performance.tasksCompleted > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if maxCompleted > 0 {
                performanceProgressBar(completed: performance.tasksCompleted, max: maxCompleted)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    private func performanceProgressBar(completed: Int, max: Int) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.purple.opacity(0.2))
                .frame(width: 60, height: 8)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.purple)
                .frame(width: 60 * CGFloat(completed) / CGFloat(max), height: 8)
        }
        .frame(width: 60, height: 8)
    }
    
    private var tasksCompletedTodayCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Tâches complétées aujourd'hui")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(tasksCompletedToday)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    // Helper function to calculate user performance
    private func calculateUserPerformance() -> [UserPerformance] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let completedTasksToday = companyTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= today && completedAt < tomorrow && task.assignedToUserId != nil
        }
        
        let groupedByUser = Dictionary(grouping: completedTasksToday, by: { $0.assignedToUserId ?? "" })
        
        return groupedByUser.compactMap { userId, tasks in
            guard let userName = tasks.first?.assignedToUserName, !userId.isEmpty else { return nil }
            return UserPerformance(userId: userId, userName: userName, tasksCompleted: tasks.count)
        }
    }
    
    // Helper function to get initials
    private func getInitials(for name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
    
    // MARK: - SECTION 4: Charts
    
    private var chartsSection: some View {
        VStack(spacing: 16) {
            stockDistributionChart
        }
    }
    
    private var stockDistributionChart: some View {
        ChartCard(title: "Répartition du stock par catégorie") {
            if stockItems.isEmpty {
                emptyChartView
            } else {
                stockPieChart
            }
        }
    }
    
    private var emptyChartView: some View {
        Text("Aucune donnée disponible")
            .foregroundColor(.secondary)
            .frame(height: 150)
    }
    
    private var stockPieChart: some View {
        let categoryData = stockItemsByCategory()
        
        return Chart(categoryData) { data in
            SectorMark(
                angle: .value("Count", data.count),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(by: .value("Category", data.category))
        }
        .frame(height: 150)
    }
    
    private func stockItemsByCategory() -> [DistributionCategoryData] {
        let grouped = Dictionary(grouping: stockItems, by: \.category)
        return grouped.map { category, items in
            let totalCount = items.map(\.totalQuantity).reduce(0, +)
            return DistributionCategoryData(category: category, count: totalCount)
        }
    }
    
    // MARK: - SECTION 5: Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions rapides")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12
            ) {
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Créer tâche",
                    color: .blue,
                    action: {
                        showingCreateTask = true
                    }
                )
                
                NavigationLink {
                    AdminTaskManagementView()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        Text("Toutes les tâches")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                
                NavigationLink {
                    AdminView()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Gérer équipe")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                
                QuickActionButton(
                    icon: "bell.badge.fill",
                    title: "Notifications",
                    color: .orange,
                    action: {
                        showingNotifications = true
                    }
                )
                
                NavigationLink {
                    EventsListView()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundColor(.red)
                        
                        Text("Événements")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                
                QuickActionButton(
                    icon: "square.and.arrow.up.fill",
                    title: "Exporter",
                    color: .teal,
                    action: {
                        exportReport()
                    }
                )
            }
        }
    }
    
    // MARK: - Export Function
    
    private func exportReport() {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        var csv = "Rapport de tâches - \(formatter.string(from: today))\n\n"
        csv += "Titre,Type,Statut,Priorité,Assigné à,Créé le,Complété le\n"
        
        for task in companyTasks {
            let created = formatter.string(from: task.createdAt)
            let completed = task.completedAt.map { formatter.string(from: $0) } ?? "-"
            
            csv += "\"\(task.displayTitle)\","
            csv += "\(task.type.displayName),"
            csv += "\(task.status.displayName),"
            csv += "\(task.priority.displayName),"
            csv += "\"\(task.assignedToUserName ?? "Non attribué")\","
            csv += "\(created),"
            csv += "\(completed)\n"
        }
        
        shareCSV(csv)
    }
    
    private func shareCSV(_ content: String) {
        let activityVC = UIActivityViewController(
            activityItems: [content],
            applicationActivities: nil
        )
        
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }
        
        rootVC.present(activityVC, animated: true)
    }
}

// MARK: - Supporting Types

struct UserPerformance {
    let userId: String
    let userName: String
    let tasksCompleted: Int
}

#Preview {
    AdminDashboardView()
        .modelContainer(
            for: [StockItem.self, Asset.self, Movement.self, Event.self], inMemory: true
        )
}

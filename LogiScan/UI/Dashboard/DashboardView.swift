//
//  DashboardView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var localizationManager: LocalizationManager
    @Query private var stockItems: [StockItem]
    @Query private var movements: [Movement]
    @Query private var assets: [Asset]
    @StateObject private var syncManager = SyncManager()

    @State private var selectedPeriod: DashboardPeriod = .today
    @State private var isRefreshing = false
    @State private var isLoadingTestData = false
    @State private var showTestDataSuccess = false

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

    var recentMovements: [Movement] {
        Array(movements.sorted { $0.timestamp > $1.timestamp }.prefix(5))
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

                    // Métriques principales
                    metricsGrid

                    // Graphiques
                    chartsSection

                    // Actions rapides
                    quickActionsSection

                    // Activité récente
                    recentActivitySection
                }
                .padding()
            }
            .refreshable {
                await syncManager.syncFromFirebase(modelContext: modelContext)
            }
            .navigationTitle("dashboard".localized())
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .overlay {
                if syncManager.isSyncing {
                    VStack {
                        ProgressView("synchronization".localized())
                            .padding()
                            .background(Color(.systemBackground).opacity(0.9))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                }
            }
            .alert("test_data_created".localized(), isPresented: $showTestDataSuccess) {
                Button("ok".localized(), role: .cancel) {}
            } message: {
                Text("test_data_message".localized())
            }
            .onAppear {
                // Rafraîchissement automatique à l'arrivée sur la page
                Task {
                    await syncManager.syncFromFirebaseIfNeeded(
                        modelContext: modelContext, forceRefresh: true)
                }
            }
        }
    }

    // MARK: - Test Data Function

    private func loadTestData() {
        isLoadingTestData = true
        
        Task {
            // Charger les données dans SwiftData
            SampleData.createSampleData(modelContext: modelContext)
            
            // Les données sont maintenant dans SwiftData
            // L'utilisateur peut les synchroniser manuellement vers Firebase si nécessaire
            
            await MainActor.run {
                isLoadingTestData = false
                showTestDataSuccess = true
            }
        }
    }
    
    // MARK: - Debug Function
    
    private func debugPermissions() {
        print("\n" + String(repeating: "=", count: 60))
        print("🔧 DEBUG PERMISSIONS - Dashboard")
        print(String(repeating: "=", count: 60))
        
        let permService = PermissionService.shared
        
        if let user = permService.currentUser {
            print("✅ Utilisateur connecté:")
            print("   📧 Email: \(user.email)")
            print("   👤 Nom: \(user.displayName)")
            print("   🏢 Type compte: \(user.accountType.displayName)")
            
            if let role = user.role {
                print("   👔 Rôle: \(role.displayName)")
                print("\n📋 Permissions du rôle \(role.displayName):")
                for permission in role.permissions {
                    let hasIt = permService.checkPermission(permission)
                    print("   \(hasIt ? "✅" : "❌") \(permission.displayName)")
                }
            } else {
                print("   ⚠️ Aucun rôle défini!")
            }
            
            print("\n🎯 Permissions critiques:")
            print("   writeEvents: \(permService.checkPermission(.writeEvents) ? "✅ OUI" : "❌ NON")")
            print("   manageTrucks: \(permService.checkPermission(.manageTrucks) ? "✅ OUI" : "❌ NON")")
            print("   manageMembers: \(permService.checkPermission(.manageMembers) ? "✅ OUI" : "❌ NON")")
            print("   editCompany: \(permService.checkPermission(.editCompany) ? "✅ OUI" : "❌ NON")")
            
        } else {
            print("❌ AUCUN UTILISATEUR CONNECTÉ")
            print("⚠️ PermissionService.shared.currentUser est nil")
            print("\n💡 Solutions:")
            print("   1. Se connecter via LoginView")
            print("   2. Vérifier que LoginView.swift appelle:")
            print("      PermissionService.shared.setCurrentUser(user)")
        }
        
        print(String(repeating: "=", count: 60) + "\n")
    }

    private func refreshData() async {
        print("🔄 [DashboardView] Pull-to-refresh déclenché")
        isRefreshing = true
        await syncManager.syncFromFirebase(modelContext: modelContext)
        isRefreshing = false
    }

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

    private var metricsGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16
        ) {
            MetricCard(
                title: "active_assets".localized(),
                value: "\(assetsOK)",
                change: nil,
                icon: "cube.box.fill",
                color: .blue
            )

            MetricCard(
                title: "stock_items".localized(),
                value: "\(stockItems.count)",
                change: nil,
                icon: "cube.box",
                color: .green
            )

            MetricCard(
                title: "total_stock".localized(),
                value: "\(stockItems.map(\.totalQuantity).reduce(0, +))",
                change: nil,
                icon: "square.stack.3d.up.fill",
                color: .orange
            )

            MetricCard(
                title: "movements_today".localized(),
                value: "\(todayMovementsCount)",
                change: nil,
                icon: "arrow.left.arrow.right.circle.fill",
                color: .purple
            )
        }
    }

    private var chartsSection: some View {
        VStack(spacing: 16) {
            // Graphique simple des catégories
            ChartCard(title: "stock_distribution".localized()) {
                if stockItems.isEmpty {
                    Text("empty_state".localized())
                        .foregroundColor(.secondary)
                        .frame(height: 150)
                } else {
                    let categoryData = Dictionary(grouping: stockItems, by: \.category)
                        .mapValues { $0.map(\.totalQuantity).reduce(0, +) }
                        .map { DistributionCategoryData(category: $0.key, count: $0.value) }

                    Chart(categoryData) { data in
                        SectorMark(
                            angle: .value("Count", data.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Category", data.category))
                    }
                    .frame(height: 150)
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("quick_actions".localized())
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12
            ) {
                // Bouton de test pour charger les données d'exemple
                QuickActionButton(
                    icon: "arrow.clockwise.circle.fill",
                    title: isLoadingTestData ? "loading_data".localized() : "load_test_data".localized(),
                    color: .gray,
                    action: {
                        loadTestData()
                    }
                )
                
                // 🔧 Bouton de debug temporaire pour tester les permissions
                QuickActionButton(
                    icon: "person.badge.key.fill",
                    title: "debug_permissions".localized(),
                    color: .orange,
                    action: {
                        debugPermissions()
                    }
                )

                QuickActionButton(
                    icon: "qrcode.viewfinder",
                    title: "scanner".localized(),
                    color: .blue,
                    action: {
                        // TODO: Navigation vers scanner
                    }
                )

                QuickActionButton(
                    icon: "plus.circle",
                    title: "new_order".localized(),
                    color: .green,
                    action: {
                        // TODO: Navigation vers nouvel ordre
                    }
                )

                QuickActionButton(
                    icon: "truck",
                    title: "trucks".localized(),
                    color: .orange,
                    action: {
                        // TODO: Navigation vers camions
                    }
                )

                QuickActionButton(
                    icon: "cube.box",
                    title: "stock".localized(),
                    color: .purple,
                    action: {
                        // TODO: Navigation vers stock
                    }
                )

                QuickActionButton(
                    icon: "calendar",
                    title: "events".localized(),
                    color: .red,
                    action: {
                        // TODO: Navigation vers événements
                    }
                )

                QuickActionButton(
                    icon: "chart.bar",
                    title: "reports".localized(),
                    color: .teal,
                    action: {
                        // TODO: Navigation vers rapports
                    }
                )
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("recent_activity".localized())
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button("view_all".localized()) {
                    // TODO: Navigation vers historique complet
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }

            LazyVStack(spacing: 12) {
                ForEach(recentMovements, id: \.movementId) { movement in
                    RecentActivityRow(movement: movement)
                }

                if recentMovements.isEmpty {
                    Text("no_recent_movements".localized())
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let change: Double?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)

                Spacer()

                if let change = change {
                    changeIndicator(change)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private func changeIndicator(_ change: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                .font(.caption)

            Text(String(format: "%.1f%%", abs(change)))
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(change >= 0 ? .green : .red)
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
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
    }
}

struct RecentActivityRow: View {
    let movement: Movement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: movement.type.icon)
                .foregroundColor(Color(movement.type.color))
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(movement.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let assetId = movement.assetId {
                    Text("Asset: \(assetId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(movement.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .fontWeight(.medium)

                Text(movement.timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

enum DashboardPeriod: String, CaseIterable {
    case today = "today"
    case week = "week"
    case month = "month"
    case quarter = "quarter"

    var displayName: String {
        switch self {
        case .today: return "Aujourd'hui"
        case .week: return "Cette semaine"
        case .month: return "Ce mois"
        case .quarter: return "Ce trimestre"
        }
    }
}

struct DistributionCategoryData: Identifiable {
    let id = UUID()
    let category: String
    let count: Int
}

#Preview {
    DashboardView()
}

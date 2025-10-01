//
//  DashboardView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stockItems: [StockItem]
    @Query private var movements: [Movement]
    @Query private var assets: [Asset]
    
    @State private var selectedPeriod: DashboardPeriod = .today
    
    var activeAssetsCount: Int {
        assets.filter { $0.status == .ok }.count
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
            .navigationTitle("Tableau de bord")
            .refreshable {
                // Refresh des données SwiftData automatique
            }
        }
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
                        .fill(selectedPeriod == period ? Color.accentColor : Color.gray.opacity(0.2))
                )
                .foregroundColor(selectedPeriod == period ? .white : .primary)
        }
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            MetricCard(
                title: "Assets actifs",
                value: "\(activeAssetsCount)",
                change: nil,
                icon: "cube.box.fill",
                color: .blue
            )
            
            MetricCard(
                title: "Articles en stock",
                value: "\(stockItems.count)",
                change: nil,
                icon: "cube.box",
                color: .green
            )
            
            MetricCard(
                title: "Stock total",
                value: "\(stockItems.map(\.totalQuantity).reduce(0, +))",
                change: nil,
                icon: "square.stack.3d.up.fill",
                color: .orange
            )
            
            MetricCard(
                title: "Mouvements aujourd'hui",
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
            ChartCard(title: "Répartition du stock par catégorie") {
                if stockItems.isEmpty {
                    Text("Aucune donnée disponible")
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
            Text("Actions rapides")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                QuickActionButton(
                    icon: "qrcode.viewfinder",
                    title: "Scanner",
                    color: .blue,
                    action: {
                        // TODO: Navigation vers scanner
                    }
                )
                
                QuickActionButton(
                    icon: "plus.circle",
                    title: "Nouvel ordre",
                    color: .green,
                    action: {
                        // TODO: Navigation vers nouvel ordre
                    }
                )
                
                QuickActionButton(
                    icon: "truck",
                    title: "Camions",
                    color: .orange,
                    action: {
                        // TODO: Navigation vers camions
                    }
                )
                
                QuickActionButton(
                    icon: "cube.box",
                    title: "Stock",
                    color: .purple,
                    action: {
                        // TODO: Navigation vers stock
                    }
                )
                
                QuickActionButton(
                    icon: "calendar",
                    title: "Événements",
                    color: .red,
                    action: {
                        // TODO: Navigation vers événements
                    }
                )
                
                QuickActionButton(
                    icon: "chart.bar",
                    title: "Rapports",
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
                Text("Activité récente")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Voir tout") {
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
                    Text("Aucun mouvement récent")
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

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
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedPeriod: DashboardPeriod = .today
    
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
                await viewModel.refreshData()
            }
        }
        .onAppear {
            Task {
                await viewModel.loadData(for: selectedPeriod)
            }
        }
        .onChange(of: selectedPeriod) { newPeriod in
            Task {
                await viewModel.loadData(for: newPeriod)
            }
        }
    }
    
    private var periodSelector: some View {
        HStack {
            ForEach(DashboardPeriod.allCases, id: \.self) { period in
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
                                .fill(selectedPeriod == period ? Color.accentColor : Color(.systemGray5))
                        )
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            MetricCard(
                title: "Assets actifs",
                value: "\(viewModel.activeAssets)",
                change: viewModel.activeAssetsChange,
                icon: "cube.box.fill",
                color: .blue
            )
            
            MetricCard(
                title: "Événements",
                value: "\(viewModel.activeEvents)",
                change: viewModel.activeEventsChange,
                icon: "calendar.circle.fill",
                color: .green
            )
            
            MetricCard(
                title: "Camions",
                value: "\(viewModel.activeTrucks)",
                change: viewModel.activeTrucksChange,
                icon: "truck.box.fill",
                color: .orange
            )
            
            MetricCard(
                title: "Mouvements",
                value: "\(viewModel.todayMovements)",
                change: viewModel.movementsChange,
                icon: "arrow.left.arrow.right.circle.fill",
                color: .purple
            )
        }
    }
    
    private var chartsSection: some View {
        VStack(spacing: 16) {
            // Graphique des mouvements par jour
            ChartCard(title: "Mouvements quotidiens") {
                Chart(viewModel.dailyMovements) { data in
                    BarMark(
                        x: .value("Date", data.date, unit: .day),
                        y: .value("Mouvements", data.count)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: 150)
            }
            
            // Graphique répartition par catégorie
            ChartCard(title: "Répartition par catégorie") {
                Chart(viewModel.categoryDistribution) { data in
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
                ForEach(viewModel.recentMovements.prefix(5), id: \.movementId) { movement in
                    RecentActivityRow(movement: movement)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
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
                .fill(Color(.systemGray6))
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
                .fill(Color(.systemGray6))
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
                    .fill(Color(.systemGray6))
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

#Preview {
    DashboardView()
}

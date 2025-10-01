//
//  DashboardViewModel.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var activeAssets: Int = 0
    @Published var activeEvents: Int = 0
    @Published var activeTrucks: Int = 0
    @Published var todayMovements: Int = 0
    
    @Published var activeAssetsChange: Double? = nil
    @Published var activeEventsChange: Double? = nil
    @Published var activeTrucksChange: Double? = nil
    @Published var movementsChange: Double? = nil
    
    @Published var dailyMovements: [DailyMovementData] = []
    @Published var categoryDistribution: [CategoryData] = []
    @Published var recentMovements: [Movement] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private var assetRepository: AssetRepositoryProtocol?
    private var movementRepository: MovementRepositoryProtocol?
    
    func configure(
        assetRepository: AssetRepositoryProtocol,
        movementRepository: MovementRepositoryProtocol
    ) {
        self.assetRepository = assetRepository
        self.movementRepository = movementRepository
    }
    
    func loadData(for period: DashboardPeriod) async {
        isLoading = true
        errorMessage = nil
        
        do {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadMetrics(for: period) }
                group.addTask { await self.loadChartData(for: period) }
                group.addTask { await self.loadRecentActivity() }
            }
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        await loadData(for: .today)
    }
    
    private func loadMetrics(for period: DashboardPeriod) async {
        do {
            // Charger les assets actifs
            if let assetRepo = assetRepository {
                let assets = try await assetRepo.getAllAssets()
                activeAssets = assets.filter { $0.status == .ok }.count
                
                // Simuler un changement (à remplacer par une vraie logique)
                activeAssetsChange = Double.random(in: -10...15)
            }
            
            // Charger les mouvements du jour
            if let movementRepo = movementRepository {
                let movements = try await movementRepo.getRecentMovements(limit: 100)
                let today = Calendar.current.startOfDay(for: Date())
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
                
                todayMovements = movements.filter { movement in
                    movement.timestamp >= today && movement.timestamp < tomorrow
                }.count
                
                movementsChange = Double.random(in: -20...30)
            }
            
            // Simuler d'autres métriques (à implémenter avec de vraies données)
            activeEvents = Int.random(in: 5...25)
            activeTrucks = Int.random(in: 8...15)
            activeEventsChange = Double.random(in: -5...10)
            activeTrucksChange = Double.random(in: -8...12)
            
        } catch {
            errorMessage = "Erreur lors du chargement des métriques: \(error.localizedDescription)"
        }
    }
    
    private func loadChartData(for period: DashboardPeriod) async {
        // Générer des données pour les graphiques
        dailyMovements = generateDailyMovementsData(for: period)
        categoryDistribution = generateCategoryData()
    }
    
    private func loadRecentActivity() async {
        do {
            if let movementRepo = movementRepository {
                recentMovements = try await movementRepo.getRecentMovements(limit: 10)
            }
        } catch {
            errorMessage = "Erreur lors du chargement de l'activité récente: \(error.localizedDescription)"
        }
    }
    
    private func generateDailyMovementsData(for period: DashboardPeriod) -> [DailyMovementData] {
        let calendar = Calendar.current
        let today = Date()
        let daysCount: Int
        
        switch period {
        case .today:
            daysCount = 1
        case .week:
            daysCount = 7
        case .month:
            daysCount = 30
        case .quarter:
            daysCount = 90
        }
        
        return (0..<daysCount).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return nil
            }
            
            return DailyMovementData(
                date: date,
                count: Int.random(in: 0...50)
            )
        }.reversed()
    }
    
    private func generateCategoryData() -> [CategoryData] {
        return [
            CategoryData(category: "Éclairage", count: 120),
            CategoryData(category: "Son", count: 85),
            CategoryData(category: "Structures", count: 60),
            CategoryData(category: "Mobilier", count: 45),
            CategoryData(category: "Divers", count: 30)
        ]
    }
}

struct DailyMovementData: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct CategoryData: Identifiable {
    let id = UUID()
    let category: String
    let count: Int
}

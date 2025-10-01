//
//  MainTabView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Repositories initialisés avec lazy loading
    private var assetRepository: AssetRepository {
        AssetRepository(modelContext: modelContext)
    }
    
    private var movementRepository: MovementRepository {
        MovementRepository(modelContext: modelContext)
    }
    
    var body: some View {
        TabView {
            // Dashboard
            DashboardView()
                .onAppear {
                    // Configuration du dashboard avec les repositories
                    // TODO: Passer les repositories au DashboardViewModel
                }
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Tableau de bord")
                }
            
            // Scanner QR
            ScannerMainView(
                assetRepository: assetRepository,
                movementRepository: movementRepository
            )
            .tabItem {
                Image(systemName: "qrcode.viewfinder")
                Text("Scanner")
            }
            
            // Stock
            StockListView()
                .tabItem {
                    Image(systemName: "cube.box.fill")
                    Text("Stock")
                }
            
            // Événements
            EventsListView()
                .tabItem {
                    Image(systemName: "calendar.circle.fill")
                    Text("Événements")
                }
            
            // Camions
            TrucksListView()
                .tabItem {
                    Image(systemName: "truck.box.fill")
                    Text("Camions")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Asset.self, Movement.self, StockItem.self, Event.self, Truck.self, Location.self, Order.self, OrderLine.self, OrderTimestamp.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    return MainTabView()
        .modelContainer(container)
}

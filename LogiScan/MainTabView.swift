//
//  MainTabView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // Dashboard
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Tableau de bord")
                }

            // Scanner QR - Version simplifiée sans repositories
            SimpleScannerView()
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
    MainTabView()
        .modelContainer(
            for: [StockItem.self, Asset.self, Movement.self, Event.self, Truck.self], inMemory: true
        )
}

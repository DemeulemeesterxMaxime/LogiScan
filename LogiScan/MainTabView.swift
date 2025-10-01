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
    @State private var isDataInitialized = false
    
    var body: some View {
        TabView {
            // Dashboard
            DashboardView()
                .onAppear {
                    initializeSampleDataIfNeeded()
                }
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
            
            // Événements - Version simplifiée
            Text("Événements - En cours de développement")
                .tabItem {
                    Image(systemName: "calendar.circle.fill")
                    Text("Événements")
                }
            
            // Camions - Version simplifiée
            Text("Camions - En cours de développement")
                .tabItem {
                    Image(systemName: "truck.box.fill")
                    Text("Camions")
                }
        }
        .accentColor(.blue)
    }
    
    private func initializeSampleDataIfNeeded() {
        guard !isDataInitialized else { return }
        
        print("🔄 Initialisation données d'exemple simplifiées...")
        
        Task {
            // Données ultra-simplifiées pour éviter tout conflit
            do {
                // Vérifier si des données existent déjà
                let existingItems = try modelContext.fetch(FetchDescriptor<StockItem>())
                
                if existingItems.isEmpty {
                    // Créer quelques items de base
                    let item1 = StockItem(
                        sku: "SPK-001",
                        name: "Enceinte Test",
                        category: "Audio",
                        totalQuantity: 5,
                        unitWeight: 10.0,
                        unitVolume: 0.1,
                        unitValue: 500.0
                    )
                    
                    let item2 = StockItem(
                        sku: "LED-001", 
                        name: "LED Test",
                        category: "Éclairage",
                        totalQuantity: 10,
                        unitWeight: 2.0,
                        unitVolume: 0.05,
                        unitValue: 100.0
                    )
                    
                    modelContext.insert(item1)
                    modelContext.insert(item2)
                    
                    try modelContext.save()
                    print("✅ Données d'exemple créées")
                } else {
                    print("✅ Données existantes trouvées (\(existingItems.count) items)")
                }
                
                isDataInitialized = true
                
            } catch {
                print("⚠️ Erreur création données d'exemple: \(error)")
                isDataInitialized = true // Marquer comme initialisé même en cas d'erreur
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: StockItem.self, Asset.self, Movement.self, Event.self, Truck.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    return MainTabView()
        .modelContainer(container)
}

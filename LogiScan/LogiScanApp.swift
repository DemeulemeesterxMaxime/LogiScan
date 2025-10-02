//
//  LogiScanApp.swift
//  LogiScan
//
//  Created by Demeulemeester on 24/09/2025.
//

import SwiftUI
import SwiftData

@main
struct LogiScanApp: App {
    let sharedModelContainer: ModelContainer
    
    init() {
        do {
            // Solution définitive: container en mémoire uniquement
            // Évite tous les problèmes de persistence SwiftData
            print("🔄 LogiScan - Initialisation ModelContainer...")
            
            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: true,  // Mode mémoire pour éviter les erreurs de persistence
                allowsSave: true
            )
            
            sharedModelContainer = try ModelContainer(
                for: StockItem.self,         // Modèle principal pour la gestion de stock
                     Asset.self,             // Assets sérialisés
                     Movement.self,          // Traçabilité des mouvements
                     Event.self,             // Gestion des événements
                     Truck.self,             // Gestion des camions
                     Order.self,             // Gestion des commandes
                     OrderLine.self,         // Lignes de commandes
                     OrderTimestamp.self,    // Historique des commandes
                     Location.self,          // Gestion des emplacements
                     QuoteItem.self,         // Articles du devis (nouveau)
                     AssetReservation.self,  // Réservations d'assets (nouveau)
                configurations: configuration
            )
            
            print("✅ ModelContainer créé avec succès (mode mémoire)")
            print("   - 11 modèles configurés")
            print("   - Persistence désactivée (développement)")
            
        } catch {
            print("❌ Erreur critique ModelContainer:")
            print("   \(error)")
            
            // Solution de dernier recours: aucune persistence
            fatalError("Impossible d'initialiser ModelContainer. Vérifiez les modèles SwiftData.")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}

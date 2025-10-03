//
//  LogiScanApp.swift
//  LogiScan
//
//  Created by Demeulemeester on 24/09/2025.
//

import FirebaseCore
import FirebaseFirestore
import SwiftData
import SwiftUI

@main
struct LogiScanApp: App {
    let sharedModelContainer: ModelContainer
    @StateObject private var authService = AuthService()

    init() {
        // 🔥 INITIALISATION FIREBASE
        FirebaseApp.configure()
        print("🔥 Firebase initialisé avec succès")
        print("📋 Project ID: logiscan-cf3fa")

        // Configuration Firestore pour mode hors ligne
        let settings = Firestore.firestore().settings
        settings.isPersistenceEnabled = true  // ✅ Cache local activé
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited  // Cache illimité
        Firestore.firestore().settings = settings
        print("💾 Firestore : Cache local activé (mode hors ligne supporté)")
        // Logs de diagnostic détaillés pour debugging
        print("=" + String(repeating: "=", count: 50))
        print("🚀 LOGISCAN DÉMARRAGE")
        print("📱 Device: \(UIDevice.current.model)")
        print("💾 iOS: \(UIDevice.current.systemVersion)")
        print("🆔 Bundle: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print(
            "📦 Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")"
        )
        print("🔢 Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")")
        print("=" + String(repeating: "=", count: 50))

        do {
            // Configuration avec persistence sur disque
            print("🔄 LogiScan - Initialisation ModelContainer...")

            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: false,  // ✅ Persistence activée sur disque
                allowsSave: true
            )

            sharedModelContainer = try ModelContainer(
                for: StockItem.self,  // Modèle principal pour la gestion de stock
                Asset.self,  // Assets sérialisés
                Movement.self,  // Traçabilité des mouvements
                Event.self,  // Gestion des événements
                Truck.self,  // Gestion des camions
                Order.self,  // Gestion des commandes
                OrderLine.self,  // Lignes de commandes
                OrderTimestamp.self,  // Historique des commandes
                Location.self,  // Gestion des emplacements
                QuoteItem.self,  // Articles du devis (nouveau)
                AssetReservation.self,  // Réservations d'assets (nouveau)
                configurations: configuration
            )

            print("✅ ModelContainer créé avec succès (persistence activée)")
            print("   - 11 modèles configurés")
            print("   - Données sauvegardées sur disque")

        } catch {
            print("❌ ERREUR CRITIQUE ModelContainer: \(error)")
            print("📝 Détails: \(error.localizedDescription)")

            // ⚠️ Fallback en mémoire pour éviter le crash complet
            do {
                print("⚠️ Tentative de fallback en mode mémoire...")
                let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                sharedModelContainer = try ModelContainer(
                    for: StockItem.self,
                    Asset.self,
                    Movement.self,
                    Event.self,
                    Truck.self,
                    Order.self,
                    OrderLine.self,
                    OrderTimestamp.self,
                    Location.self,
                    QuoteItem.self,
                    AssetReservation.self,
                    configurations: fallbackConfig
                )
                print("⚠️ Mode dégradé activé : persistence en mémoire uniquement")
                print("⚠️ Les données seront perdues à la fermeture de l'app")
            } catch let fallbackError {
                print("❌ ERREUR FATALE - Impossible d'initialiser même en mode mémoire")
                print("   Erreur: \(fallbackError)")
                // En dernier recours seulement
                fatalError(
                    "Impossible d'initialiser l'application: \(fallbackError.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                MainTabView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

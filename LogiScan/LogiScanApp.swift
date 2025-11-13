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
    @StateObject private var userSessionService = UserSessionService()
    @StateObject private var localizationManager = LocalizationManager.shared

    init() {
        // 🔥 INITIALISATION FIREBASE
        FirebaseApp.configure()
        print("🔥 Firebase initialisé avec succès")
        print("📋 Project ID: logiscan-cf3fa")

        // Configuration Firestore pour mode hors ligne
        let settings = Firestore.firestore().settings
        // ✅ Cache local activé (illimité) - NSNumber(value: -1) = cache illimité
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: -1))
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
                QuoteItem.self,  // Articles du devis
                QuoteVersion.self,  // Versions des devis (nouveau)
                AssetReservation.self,  // Réservations d'assets
                ScanList.self,  // Listes de préparation (nouveau)
                PreparationListItem.self,  // Items des listes de préparation (nouveau)
                TodoTask.self,  // Tâches (nouveau)
                TaskNotification.self,  // Notifications de tâches (nouveau)
                User.self,  // Utilisateurs (nouveau)
                configurations: configuration
            )

            print("✅ ModelContainer créé avec succès (persistence activée)")
            print("   - 18 modèles configurés")
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
                    QuoteVersion.self,
                    AssetReservation.self,
                    ScanList.self,
                    PreparationListItem.self,
                    TodoTask.self,
                    TaskNotification.self,
                    User.self,
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
                if userSessionService.isLoading {
                    // Écran de chargement pendant la récupération du profil
                    LoadingView()
                } else if userSessionService.currentUser != nil {
                    // Utilisateur chargé avec succès
                    MainTabView()
                        .environmentObject(authService)
                        .environmentObject(userSessionService)
                        .environmentObject(localizationManager)
                        .onAppear {
                            // Charger les données d'exemple au premier lancement
                            let context = sharedModelContainer.mainContext
                            SampleData.createSampleData(modelContext: context)
                            
                            // Synchroniser la langue avec celle de l'entreprise
                            Task {
                                if let companyId = userSessionService.currentUser?.companyId {
                                    do {
                                        let companyService = CompanyService()
                                        let company = try await companyService.fetchCompany(companyId: companyId)
                                        await MainActor.run {
                                            localizationManager.syncWithCompanyLanguage(company.language)
                                        }
                                    } catch {
                                        print("⚠️ Erreur chargement langue entreprise: \(error)")
                                    }
                                }
                            }
                        }
                } else if let error = userSessionService.error {
                    // Erreur de chargement du profil
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        
                        Text("Erreur de chargement")
                            .font(.headline)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Réessayer") {
                            Task {
                                await userSessionService.loadUserSession()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Se déconnecter") {
                            Task {
                                try? await authService.signOut()
                                userSessionService.clearSession()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    // État initial : chargement en cours
                    LoadingView()
                }
            } else {
                LoginView()
                    .environmentObject(authService)
                    .environmentObject(userSessionService)
                    .environmentObject(localizationManager)
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: authService.isAuthenticated) { oldValue, newValue in
            Task {
                if newValue {
                    // Utilisateur vient de se connecter → Charger la session
                    print("🔐 [App] Utilisateur connecté, chargement de la session...")
                    await userSessionService.loadUserSession()
                } else {
                    // Utilisateur vient de se déconnecter → Effacer la session
                    print("👋 [App] Utilisateur déconnecté, nettoyage de la session...")
                    userSessionService.clearSession()
                }
            }
        }
    }
}

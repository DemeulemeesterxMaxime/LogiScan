//
//  MainTabView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftData
import SwiftUI
import FirebaseFirestore

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var permissionService = PermissionService.shared
    @State private var authService = AuthService()
    @State private var userListener: ListenerRegistration?
    
    // Query pour les notifications non lues
    @Query(filter: #Predicate<TaskNotification> { !$0.isRead })
    private var allUnreadNotifications: [TaskNotification]
    
    // Nombre de notifications non lues pour l'utilisateur actuel
    private var unreadCount: Int {
        guard let currentUser = permissionService.currentUser else { return 0 }
        
        return allUnreadNotifications.filter { notification in
            notification.companyId == (currentUser.companyId ?? "") &&
            notification.isForUser(currentUser.userId, role: currentUser.role)
        }.count
    }
    
    init() {
        // Configuration de la TabBar pour qu'elle s'adapte au mode clair/sombre
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()  // Fond translucide adaptatif
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView {
            // 1. Stock
            StockListView()
                .tabItem {
                    Image(systemName: "cube.box.fill")
                    Text("Stock")
                }

            // 2. Camions
            TrucksListView()
                .tabItem {
                    Image(systemName: "truck.box.fill")
                    Text("Camions")
                }

            // 3. Scanner QR - CENTRE
            ScannerMainView(
                assetRepository: AssetRepository(modelContext: modelContext),
                movementRepository: MovementRepository(modelContext: modelContext)
            )
                .tabItem {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Scanner")
                }

            // 4. Événements
            EventsListView()
                .tabItem {
                    Image(systemName: "calendar.circle.fill")
                    Text("Événements")
                }

            // 5. Profil/Admin - Conditionnel selon le rôle
            if permissionService.isAdmin() {
                AdminDashboardView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Dashboard")
                    }
                    .badge(unreadCount > 0 ? unreadCount : 0)
            } else {
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.circle.fill")
                        Text("Profil")
                    }
                    .badge(unreadCount > 0 ? unreadCount : 0)
            }
        }
        .accentColor(.blue)
        .onAppear {
            startUserMonitoring()
        }
        .onDisappear {
            stopUserMonitoring()
        }
    }
    
    // MARK: - User Monitoring
    
    /// Surveiller l'utilisateur courant pour détecter les suppressions
    private func startUserMonitoring() {
        guard let userId = permissionService.currentUser?.userId else { return }
        
        let db = Firestore.firestore()
        userListener = db.collection("users")
            .document(userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ [MainTabView] Erreur listener utilisateur: \(error.localizedDescription)")
                    // Si erreur de permissions, l'utilisateur a probablement été supprimé
                    if error.localizedDescription.contains("permission") {
                        handleUserRemoved()
                    }
                    return
                }
                
                guard let document = snapshot, document.exists else {
                    // Le document n'existe plus, l'utilisateur a été supprimé
                    print("⚠️ [MainTabView] Document utilisateur supprimé")
                    handleUserRemoved()
                    return
                }
                
                // Vérifier si l'utilisateur a encore un companyId
                guard let data = document.data(),
                      data["companyId"] != nil else {
                    print("⚠️ [MainTabView] Utilisateur retiré de l'entreprise")
                    handleUserRemoved()
                    return
                }
                
                // Mettre à jour l'utilisateur si les données ont changé
                if let updatedUser = try? document.data(as: FirestoreUser.self).toSwiftData() {
                    permissionService.setCurrentUser(updatedUser)
                }
            }
        
        print("👀 [MainTabView] Surveillance utilisateur activée pour: \(userId)")
    }
    
    /// Arrêter la surveillance de l'utilisateur
    private func stopUserMonitoring() {
        userListener?.remove()
        userListener = nil
        print("👋 [MainTabView] Surveillance utilisateur désactivée")
    }
    
    /// Gérer le cas où l'utilisateur a été retiré/supprimé
    private func handleUserRemoved() {
        Task {
            print("🚪 [MainTabView] Déconnexion automatique (utilisateur retiré de l'entreprise)")
            try? await authService.signOut()
            permissionService.clearCurrentUser()
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(
            for: [StockItem.self, Asset.self, Movement.self, Event.self, Truck.self], inMemory: true
        )
}

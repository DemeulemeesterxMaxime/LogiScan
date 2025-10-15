# 🚨 Correctifs Urgents - 15 Octobre 2025

## 📋 PROBLÈMES IDENTIFIÉS

### 1. ❌ Perte du nom d'utilisateur et permissions au redémarrage
**Symptôme**: Après fermeture et réouverture de l'app, l'utilisateur reste connecté mais perd son displayName et ses permissions.

**Cause probable**:
- `AuthService` récupère uniquement `FirebaseAuth.User` (email, uid)
- Les informations complètes (displayName, companyId, role, permissions) sont dans Firestore collection `users`
- Pas de service de session qui persiste/restaure ces données au démarrage

**Solution à implémenter**:
1. Créer un `UserSessionService` qui charge les données Firestore au démarrage
2. Stocker les permissions dans `PermissionService` dès la connexion
3. Ajouter une logique de rechargement dans `LogiScanApp.swift`

---

### 2. ❌ Codes d'invitation ne fonctionnent pas
**Symptôme**: Lors de l'inscription avec un code d'invitation, validation échoue.

**Cause probable**:
- Code non trouvé dans Firestore
- Format du code incorrect (espaces, majuscules)
- Code mal créé lors de la génération
- Requête Firestore mal formée

**Solution à implémenter**:
1. Ajouter des logs détaillés dans `InvitationService.validateCode()`
2. Normaliser le code avant validation (trim, uppercase)
3. Vérifier que les codes sont bien créés dans Firestore
4. Ajouter un mode debug pour lister tous les codes disponibles

---

### 3. ⚠️ Listes de scan créées mais pas de sélection d'event dans le scanner
**Symptôme**: 4 listes créées (Stock→Camion, Camion→Event, Event→Camion, Camion→Stock) mais pas de mécanisme de sélection.

**Statut**: Partiellement implémenté
- ✅ `ScanList` model créé
- ✅ `PreparationListItem` model créé
- ✅ `ScanListService` pour génération
- ✅ `EventScanListView` pour affichage
- ❌ Pas de sélection d'event dans scanner
- ❌ Pas de détection automatique de la phase en cours
- ❌ Pas de gestion des 4 phases de transport

**Solution à implémenter**:
1. Créer `ScanPhase` enum (stockToTruck, truckToEvent, eventToTruck, truckToStock)
2. Ajouter un sélecteur d'event dans le scanner
3. Détecter automatiquement la phase en cours
4. Filtrer les listes de scan par event sélectionné
5. Afficher la progression par phase

---

## 🔧 PLAN DE CORRECTION

### PRIORITÉ 1: Restauration de session utilisateur (1-2h)

#### Étape 1.1: Créer UserSessionService
```swift
// Fichier: LogiScan/Data/Firebase/Services/UserSessionService.swift

import FirebaseAuth
import Foundation

@MainActor
class UserSessionService: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    
    private let firebaseService = FirebaseService()
    
    /// Charger les données utilisateur depuis Firestore
    func loadUserSession() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ [UserSession] Pas d'utilisateur connecté")
            return
        }
        
        isLoading = true
        print("🔄 [UserSession] Chargement session pour userId: \(userId)")
        
        do {
            let user = try await firebaseService.fetchUser(userId: userId)
            print("✅ [UserSession] Utilisateur chargé: \(user.displayName)")
            print("   📧 Email: \(user.email)")
            print("   🏢 Company: \(user.companyId)")
            print("   👤 Role: \(user.role.rawValue)")
            print("   🔑 Permissions: \(user.permissions.count)")
            
            currentUser = user
            PermissionService.shared.setCurrentUser(user)
            
        } catch {
            print("❌ [UserSession] Erreur chargement: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Effacer la session
    func clearSession() {
        currentUser = nil
        PermissionService.shared.setCurrentUser(nil)
        print("🧹 [UserSession] Session effacée")
    }
}
```

#### Étape 1.2: Modifier LogiScanApp.swift
```swift
// Dans LogiScanApp.swift

@StateObject private var authService = AuthService()
@StateObject private var userSessionService = UserSessionService()  // NOUVEAU

var body: some Scene {
    WindowGroup {
        if authService.isAuthenticated {
            if userSessionService.isLoading {
                // Écran de chargement
                LoadingView()
            } else if userSessionService.currentUser != nil {
                // App complète
                MainTabView()
                    .environmentObject(authService)
                    .environmentObject(userSessionService)  // NOUVEAU
                    .modelContainer(container)
            } else {
                // Erreur de chargement
                ErrorView(error: "Impossible de charger votre profil")
                    .environmentObject(authService)
            }
        } else {
            LoginView()
                .environmentObject(authService)
                .environmentObject(userSessionService)  // NOUVEAU
        }
    }
    .onChange(of: authService.isAuthenticated) { oldValue, newValue in
        Task {
            if newValue {
                // Charger la session quand l'utilisateur se connecte
                await userSessionService.loadUserSession()
            } else {
                // Effacer la session quand l'utilisateur se déconnecte
                userSessionService.clearSession()
            }
        }
    }
}
```

#### Étape 1.3: Créer LoadingView
```swift
// Fichier: LogiScan/UI/Common/LoadingView.swift

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Chargement de votre profil...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}
```

---

### PRIORITÉ 2: Correction codes d'invitation (30min-1h)

#### Étape 2.1: Améliorer InvitationService.validateCode()
```swift
// Dans InvitationService.swift, remplacer validateCode():

func validateCode(_ codeString: String) async throws -> InvitationCode {
    // Normaliser le code (trim + uppercase)
    let normalizedCode = codeString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    
    print("🔍 [InvitationService] Validation du code: '\(normalizedCode)'")
    
    let snapshot = try await db.collection("invitationCodes")
        .whereField("code", isEqualTo: normalizedCode)
        .whereField("isActive", isEqualTo: true)
        .limit(to: 1)
        .getDocuments()
    
    print("📊 [InvitationService] Résultats trouvés: \(snapshot.documents.count)")
    
    guard let document = snapshot.documents.first else {
        // Debug: Lister tous les codes actifs disponibles
        let allCodes = try await db.collection("invitationCodes")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        
        print("⚠️ [InvitationService] Code non trouvé!")
        print("📋 Codes actifs disponibles:")
        for doc in allCodes.documents {
            if let code = doc.data()["code"] as? String {
                print("   - \(code)")
            }
        }
        
        throw InvitationError.invalidCode
    }
    
    guard let firestoreCode = try? document.data(as: FirestoreInvitationCode.self) else {
        print("❌ [InvitationService] Erreur parsing du document")
        throw InvitationError.invalidCode
    }
    
    let code = firestoreCode.toSwiftData()
    print("✅ [InvitationService] Code valide trouvé:")
    print("   🏢 Entreprise: \(code.companyName)")
    print("   👤 Rôle: \(code.role.rawValue)")
    print("   📅 Expire le: \(code.expiresAt)")
    print("   📊 Utilisations: \(code.usedCount)/\(code.maxUses)")
    
    // Vérifier la validité
    guard code.isValid else {
        if code.expiresAt < Date() {
            print("❌ Code expiré!")
            throw InvitationError.expiredCode
        } else if code.usedCount >= code.maxUses {
            print("❌ Nombre max d'utilisations atteint!")
            throw InvitationError.maxUsesReached
        } else {
            print("❌ Code inactif!")
            throw InvitationError.inactiveCode
        }
    }
    
    return code
}
```

#### Étape 2.2: Normaliser le code dans SignUpView
```swift
// Dans SignUpView.swift, modifier joinCompanyWithCode():

private func joinCompanyWithCode() {
    // Normaliser le code avant validation
    let normalizedCode = invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    
    isLoading = true
    errorMessage = nil
    
    print("🔐 [SignUp] Tentative de connexion avec code: '\(normalizedCode)'")
    
    Task {
        do {
            // 1. Valider le code d'invitation
            let invitationService = InvitationService()
            let invitation = try await invitationService.validateCode(normalizedCode)
            
            print("✅ [SignUp] Code validé, création du compte...")
            
            // ... reste du code inchangé
```

#### Étape 2.3: Ajouter un bouton debug dans AdminView
```swift
// Dans AdminView.swift, ajouter:

Section("🐛 Debug Codes d'invitation") {
    Button("Lister tous les codes actifs") {
        Task {
            await listAllActiveCodes()
        }
    }
}

// Fonction helper:
private func listAllActiveCodes() async {
    let invitationService = InvitationService()
    do {
        guard let company = currentCompany else { return }
        let codes = try await invitationService.fetchInvitationCodes(companyId: company.companyId)
        print("📋 Codes disponibles pour \(company.name):")
        for code in codes where code.isActive {
            print("   ✅ \(code.code) - \(code.role.rawValue) - \(code.usedCount)/\(code.maxUses)")
        }
    } catch {
        print("❌ Erreur: \(error)")
    }
}
```

---

### PRIORITÉ 3: Scanner contextuel avec sélection d'event (2-3h)

#### Étape 3.1: Créer le modèle ScanPhase
```swift
// Fichier: LogiScan/Domain/Models/ScanPhase.swift

import Foundation

enum ScanPhase: String, CaseIterable, Codable {
    case stockToTruck = "stock_to_truck"
    case truckToEvent = "truck_to_event"
    case eventToTruck = "event_to_truck"
    case truckToStock = "truck_to_stock"
    
    var displayName: String {
        switch self {
        case .stockToTruck: return "Stock → Camion"
        case .truckToEvent: return "Camion → Événement"
        case .eventToTruck: return "Événement → Camion"
        case .truckToStock: return "Camion → Stock"
        }
    }
    
    var icon: String {
        switch self {
        case .stockToTruck: return "arrow.right.to.line"
        case .truckToEvent: return "truck.box.badge.clock"
        case .eventToTruck: return "arrow.left.to.line"
        case .truckToStock: return "truck.box"
        }
    }
    
    var description: String {
        switch self {
        case .stockToTruck:
            return "Chargement du matériel depuis le stock vers le camion"
        case .truckToEvent:
            return "Déchargement du matériel du camion vers le lieu de l'événement"
        case .eventToTruck:
            return "Rechargement du matériel depuis l'événement vers le camion"
        case .truckToStock:
            return "Déchargement du matériel du camion vers le stock"
        }
    }
}
```

#### Étape 3.2: Enrichir ScanList avec la phase
```swift
// Modifier LogiScan/Domain/Models/ScanList.swift

@Model
final class ScanList {
    @Attribute(.unique) var scanListId: String
    var eventId: String
    var eventName: String
    var phase: ScanPhase  // NOUVEAU
    var totalItems: Int
    var scannedItems: Int
    var createdAt: Date
    var completedAt: Date?
    var status: ScanListStatus
    
    @Relationship(deleteRule: .cascade, inverse: \PreparationListItem.scanList)
    var items: [PreparationListItem] = []
    
    init(
        scanListId: String = UUID().uuidString,
        eventId: String,
        eventName: String,
        phase: ScanPhase,  // NOUVEAU
        totalItems: Int = 0,
        scannedItems: Int = 0,
        status: ScanListStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.scanListId = scanListId
        self.eventId = eventId
        self.eventName = eventName
        self.phase = phase  // NOUVEAU
        self.totalItems = totalItems
        self.scannedItems = scannedItems
        self.status = status
        self.createdAt = createdAt
    }
    
    // Progression par phase
    var progressPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(scannedItems) / Double(totalItems)
    }
}
```

#### Étape 3.3: Modifier ScanListService pour générer 4 listes
```swift
// Dans ScanListService.swift

func generateScanListsForEvent(
    event: Event,
    quoteItems: [QuoteItem],
    modelContext: ModelContext
) throws -> [ScanList] {
    
    var scanLists: [ScanList] = []
    
    // Créer une liste pour chaque phase
    for phase in ScanPhase.allCases {
        let scanList = ScanList(
            eventId: event.eventId,
            eventName: event.name,
            phase: phase
        )
        
        // Ajouter les items du devis
        for quoteItem in quoteItems {
            let item = PreparationListItem(
                scanListId: scanList.scanListId,
                sku: quoteItem.sku,
                name: quoteItem.name,
                category: quoteItem.category,
                requiredQuantity: quoteItem.quantity,
                scannedQuantity: 0
            )
            scanList.items.append(item)
            modelContext.insert(item)
        }
        
        scanList.totalItems = scanList.items.reduce(0) { $0 + $1.requiredQuantity }
        modelContext.insert(scanList)
        scanLists.append(scanList)
        
        print("✅ [ScanList] Créé pour \(event.name) - Phase: \(phase.displayName)")
    }
    
    try modelContext.save()
    return scanLists
}
```

#### Étape 3.4: Créer ContextualScannerView avec sélection d'event
```swift
// Fichier: LogiScan/UI/Scanner/ContextualScannerView.swift

import SwiftUI
import SwiftData

struct ContextualScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEvents: [Event]
    @Query private var allScanLists: [ScanList]
    
    @State private var selectedEvent: Event?
    @State private var showingScanner = false
    @State private var selectedPhase: ScanPhase?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sélecteur d'événement
                eventSelectorSection
                
                if let event = selectedEvent {
                    // Phases de scan disponibles
                    phasesSection(for: event)
                } else {
                    // Message d'instruction
                    emptyStateView
                }
            }
            .navigationTitle("Scanner Contextuel")
            .sheet(isPresented: $showingScanner) {
                if let event = selectedEvent, let phase = selectedPhase {
                    ScanPhaseView(event: event, phase: phase)
                }
            }
        }
    }
    
    // MARK: - Event Selector
    
    private var eventSelectorSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Sélectionnez un événement")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(upcomingEvents) { event in
                        EventChip(
                            event: event,
                            isSelected: selectedEvent?.eventId == event.eventId,
                            onTap: { selectedEvent = event }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 80)
        }
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
    
    private var upcomingEvents: [Event] {
        allEvents
            .filter { $0.endDate >= Date() }  // Événements futurs ou en cours
            .sorted { $0.startDate < $1.startDate }
    }
    
    // MARK: - Phases Section
    
    private func phasesSection(for event: Event) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(ScanPhase.allCases, id: \.self) { phase in
                    PhaseCard(
                        event: event,
                        phase: phase,
                        scanList: scanList(for: event, phase: phase),
                        onTap: {
                            selectedPhase = phase
                            showingScanner = true
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private func scanList(for event: Event, phase: ScanPhase) -> ScanList? {
        allScanLists.first {
            $0.eventId == event.eventId && $0.phase == phase
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Sélectionnez un événement")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Choisissez un événement pour voir\nles phases de scan disponibles")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
}

// MARK: - Supporting Views

struct EventChip: View {
    let event: Event
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(event.startDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct PhaseCard: View {
    let event: Event
    let phase: ScanPhase
    let scanList: ScanList?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: phase.icon)
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phase.displayName)
                            .font(.headline)
                        
                        Text(phase.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                
                if let list = scanList {
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(list.scannedItems)/\(list.totalItems) articles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            StatusBadge(status: list.status)
                        }
                        
                        ProgressView(value: list.progressPercentage)
                            .tint(list.status == .completed ? .green : .blue)
                    }
                } else {
                    Text("Aucune liste créée")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct StatusBadge: View {
    let status: ScanListStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(status.color.opacity(0.2))
            )
            .foregroundColor(status.color)
    }
}

extension ScanListStatus {
    var displayName: String {
        switch self {
        case .pending: return "En attente"
        case .inProgress: return "En cours"
        case .completed: return "Terminé"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

#Preview {
    ContextualScannerView()
        .modelContainer(for: [Event.self, ScanList.self], inMemory: true)
}
```

#### Étape 3.5: Créer ScanPhaseView (scan réel)
```swift
// Fichier: LogiScan/UI/Scanner/ScanPhaseView.swift

import SwiftUI
import SwiftData

struct ScanPhaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let event: Event
    let phase: ScanPhase
    
    @Query private var allAssets: [Asset]
    @State private var scanList: ScanList?
    @State private var scannedCode: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Info header
                phaseInfoHeader
                
                // Scanner
                QRScannerView(scannedCode: $scannedCode)
                    .frame(height: 300)
                
                // Liste des items
                if let list = scanList {
                    itemsList(list: list)
                } else {
                    Text("Aucune liste trouvée")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(phase.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminer") {
                        dismiss()
                    }
                }
            }
            .alert("Information", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onChange(of: scannedCode) { _, newCode in
                if let code = newCode {
                    handleScannedCode(code)
                }
            }
            .task {
                loadScanList()
            }
        }
    }
    
    // MARK: - Header
    
    private var phaseInfoHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                    
                    Text(phase.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let list = scanList {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(list.scannedItems)/\(list.totalItems)")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("\(Int(list.progressPercentage * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let list = scanList {
                ProgressView(value: list.progressPercentage)
                    .tint(list.status == .completed ? .green : .blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Items List
    
    private func itemsList(list: ScanList) -> some View {
        List {
            ForEach(list.items) { item in
                PreparationListItemRow(item: item)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadScanList() {
        let descriptor = FetchDescriptor<ScanList>(
            predicate: #Predicate<ScanList> { list in
                list.eventId == event.eventId && list.phase == phase
            }
        )
        
        scanList = try? modelContext.fetch(descriptor).first
    }
    
    private func handleScannedCode(_ code: String) {
        guard let list = scanList else { return }
        
        // Trouver l'asset
        guard let asset = allAssets.first(where: { $0.qrCode == code }) else {
            alertMessage = "Asset non trouvé: \(code)"
            showAlert = true
            scannedCode = nil
            return
        }
        
        // Trouver l'item correspondant
        guard let item = list.items.first(where: { $0.sku == asset.sku }) else {
            alertMessage = "Cet asset n'est pas dans la liste"
            showAlert = true
            scannedCode = nil
            return
        }
        
        // Vérifier si déjà scanné
        if item.scannedAssetIds.contains(asset.assetId) {
            alertMessage = "Asset déjà scanné"
            showAlert = true
            scannedCode = nil
            return
        }
        
        // Marquer comme scanné
        item.scannedAssetIds.append(asset.assetId)
        item.scannedQuantity += 1
        item.lastScannedAt = Date()
        
        list.scannedItems += 1
        
        // Mettre à jour le statut
        if list.scannedItems >= list.totalItems {
            list.status = .completed
            list.completedAt = Date()
            alertMessage = "🎉 Phase terminée!"
            showAlert = true
        } else {
            list.status = .inProgress
        }
        
        try? modelContext.save()
        
        print("✅ Asset scanné: \(asset.assetId) - \(item.scannedQuantity)/\(item.requiredQuantity)")
        
        // Réinitialiser pour prochain scan
        scannedCode = nil
    }
}

struct PreparationListItemRow: View {
    let item: PreparationListItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if item.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                Text("\(item.scannedQuantity)/\(item.requiredQuantity)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(item.isComplete ? .green : .orange)
            }
        }
    }
}
```

---

## ✅ CHECKLIST DE VALIDATION

### Priorité 1: Session utilisateur
- [ ] `UserSessionService.swift` créé
- [ ] `LogiScanApp.swift` modifié avec onChange
- [ ] `LoadingView.swift` créé
- [ ] Tester: Fermer l'app → Réouvrir → Vérifier nom et permissions
- [ ] Tester: Console doit afficher "✅ [UserSession] Utilisateur chargé"

### Priorité 2: Codes d'invitation
- [ ] `InvitationService.validateCode()` amélioré avec logs
- [ ] `SignUpView.joinCompanyWithCode()` normalise le code
- [ ] Bouton debug dans `AdminView` ajouté
- [ ] Tester: Créer un code dans Admin
- [ ] Tester: Copier le code et l'utiliser dans SignUp
- [ ] Tester: Console doit afficher "✅ [InvitationService] Code valide trouvé"

### Priorité 3: Scanner contextuel
- [ ] `ScanPhase.swift` créé
- [ ] `ScanList.swift` modifié avec phase
- [ ] `ScanListService` génère 4 listes
- [ ] `ContextualScannerView.swift` créé
- [ ] `ScanPhaseView.swift` créé
- [ ] Modifier `QuoteBuilderView` pour générer 4 listes
- [ ] Ajouter dans `MainTabView` ou onglet Scanner
- [ ] Tester: Finaliser un devis → 4 listes créées
- [ ] Tester: Ouvrir scanner → Sélectionner event → Voir 4 phases
- [ ] Tester: Scanner un QR code → Vérifier progression

---

## 📦 ORDRE D'IMPLÉMENTATION RECOMMANDÉ

1. **JOUR 1 (2-3h)**:
   - ✅ P1: Session utilisateur (résout le pb urgent)
   - ✅ P2: Codes d'invitation (résout le pb urgent)
   - Test complet des 2 corrections

2. **JOUR 2 (3-4h)**:
   - ✅ P3: Scanner contextuel
   - Test complet du flux de scan

3. **JOUR 3 (1h)**:
   - Polissage UI
   - Tests finaux
   - Déploiement TestFlight

---

## 🚨 NOTES IMPORTANTES

### Session utilisateur
- **CRITIQUE**: Sans cette correction, les permissions ne fonctionnent pas
- Impact: Sécurité, UX, fonctionnalités admin bloquées

### Codes d'invitation
- Vérifier que les codes sont bien créés dans Firestore Console
- Format attendu: `COMPANY-2025-XXXX`
- Toujours normaliser (uppercase + trim)

### Scanner contextuel
- Utiliser les `ScanList` existantes
- Ne pas recréer si déjà générées
- Permettre annulation de scan (double confirmation)
- Gérer le cas où un event a plusieurs camions

---

**Date de création**: 15 octobre 2025
**Prochaine mise à jour**: Après implémentation P1 et P2

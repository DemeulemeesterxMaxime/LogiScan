# Plan Phase Multi-Utilisateurs - LogiScan

**Date de création** : 12 octobre 2025  
**Objectif** : Transformer LogiScan en application multi-utilisateurs avec gestion d'entreprise et système de permissions

---

## 📋 Vue d'ensemble

### Concept Principal
- **2 types de comptes** : Entreprise (Admin) et Employé
- **Système de permissions** : Rôles avec différents niveaux d'accès
- **Invitations** : L'admin peut inviter des membres à rejoindre son entreprise
- **Gestion centralisée** : Page d'administration pour gérer entreprise et membres

---

## 🎯 Fonctionnalités Clés

### 1. Inscription Multi-Type
- ✅ Choix lors de l'inscription : **Entreprise** ou **Employé**
- ✅ Si Entreprise → Devient automatiquement Admin
- ✅ Si Employé → Doit utiliser un code d'invitation

### 2. Système de Rôles & Permissions

#### Rôles Disponibles
1. **Admin** (Propriétaire)
   - Accès total à l'application
   - Gestion des membres et permissions
   - Modification des informations entreprise
   - Génération et envoi de codes d'invitation
   - Transfert du rôle admin à un autre membre

2. **Manager**
   - Création/modification/suppression d'événements
   - Création/modification de devis
   - Gestion du stock (ajout/modification)
   - Consultation de tous les événements
   - Gestion des camions

3. **Employé Standard**
   - Consultation des événements assignés
   - Scanner des QR codes
   - Mise à jour du statut des matériels
   - Consultation du stock (lecture seule)
   - Consultation des devis (lecture seule)

4. **Employé Limité**
   - Scanner des QR codes uniquement
   - Consultation du stock (lecture seule)
   - Consultation des événements assignés (lecture seule)

### 3. Système d'Invitation

#### Option A : Code d'Invitation (Recommandé)
**Avantages** :
- ✅ Simple à implémenter
- ✅ Fonctionne même si l'app n'est pas installée
- ✅ Pas de dépendance aux liens dynamiques
- ✅ Code court et mémorisable (ex: ACME-2024-X7K9)

**Workflow** :
1. Admin génère un code d'invitation dans l'app
2. Code est associé à : `companyId`, `role`, `expirationDate`, `maxUses`
3. Admin partage le code (SMS, email, WhatsApp, etc.)
4. Nouvel employé télécharge l'app
5. Lors de l'inscription, il choisit "Employé" et entre le code
6. Le code est validé et l'employé est ajouté à l'entreprise avec le rôle défini

**Structure du Code** :
```
[NOM_ENTREPRISE]-[ANNEE]-[CODE_ALEATOIRE]
Exemple : LOGISCAN-2025-A7X9
```

#### Option B : Lien Dynamique App Store
**Avantages** :
- ✅ Expérience utilisateur plus fluide
- ✅ Redirige directement vers l'App Store si l'app n'est pas installée

**Inconvénients** :
- ❌ Plus complexe à mettre en place (Firebase Dynamic Links)
- ❌ Nécessite configuration supplémentaire
- ❌ Dépendance à Firebase Dynamic Links

**Recommandation** : Commencer avec l'Option A (codes), puis ajouter l'Option B si nécessaire.

---

## 🏗️ Architecture Technique

### Modèles de Données

#### 1. Company (Entreprise)
```swift
@Model
final class Company {
    @Attribute(.unique) var companyId: String
    var name: String
    var logoURL: String?
    var address: String
    var phone: String
    var email: String
    var siret: String
    var createdAt: Date
    var ownerId: String // User ID de l'admin principal
    
    init(companyId: String = UUID().uuidString, ...) {
        // ...
    }
}
```

**Firebase Firestore** :
```
companies/{companyId}
  - name: String
  - logoURL: String?
  - address: String
  - phone: String
  - email: String
  - siret: String
  - createdAt: Timestamp
  - ownerId: String
```

#### 2. User (Utilisateur) - Extension
```swift
@Model
final class User {
    @Attribute(.unique) var userId: String
    var email: String
    var displayName: String
    var photoURL: String?
    var accountType: AccountType // .company ou .employee
    
    // Informations entreprise (si employé)
    var companyId: String?
    var role: UserRole?
    var joinedAt: Date?
    
    enum AccountType: String, Codable {
        case company    // Admin d'entreprise
        case employee   // Employé
    }
    
    enum UserRole: String, Codable {
        case admin           // Propriétaire
        case manager         // Manager
        case standardEmployee // Employé standard
        case limitedEmployee  // Employé limité
        
        var permissions: [Permission] {
            switch self {
            case .admin:
                return Permission.allCases
            case .manager:
                return [.readEvents, .writeEvents, .readStock, .writeStock, 
                        .readQuotes, .writeQuotes, .manageTrucks, .scanQR]
            case .standardEmployee:
                return [.readEvents, .readStock, .readQuotes, .scanQR, 
                        .updateAssetStatus]
            case .limitedEmployee:
                return [.scanQR, .readStock]
            }
        }
    }
    
    enum Permission: String, CaseIterable, Codable {
        case readEvents
        case writeEvents
        case readStock
        case writeStock
        case readQuotes
        case writeQuotes
        case manageTrucks
        case manageMembers
        case editCompany
        case scanQR
        case updateAssetStatus
    }
    
    func hasPermission(_ permission: Permission) -> Bool {
        guard let role = role else { return false }
        return role.permissions.contains(permission)
    }
}
```

**Firebase Firestore** :
```
users/{userId}
  - email: String
  - displayName: String
  - photoURL: String?
  - accountType: String
  - companyId: String?
  - role: String?
  - joinedAt: Timestamp?
```

#### 3. InvitationCode (Code d'Invitation)
```swift
@Model
final class InvitationCode {
    @Attribute(.unique) var codeId: String
    var code: String // Format: COMPANY-2025-X7K9
    var companyId: String
    var companyName: String
    var role: User.UserRole
    var createdBy: String // userId de l'admin
    var createdAt: Date
    var expiresAt: Date
    var maxUses: Int
    var usedCount: Int
    var isActive: Bool
    
    var isValid: Bool {
        return isActive && 
               usedCount < maxUses && 
               expiresAt > Date()
    }
    
    init(codeId: String = UUID().uuidString,
         companyId: String,
         companyName: String,
         role: User.UserRole,
         createdBy: String,
         validityDays: Int = 7,
         maxUses: Int = 10) {
        self.codeId = codeId
        self.code = Self.generateCode(companyName: companyName)
        self.companyId = companyId
        self.companyName = companyName
        self.role = role
        self.createdBy = createdBy
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(TimeInterval(validityDays * 86400))
        self.maxUses = maxUses
        self.usedCount = 0
        self.isActive = true
    }
    
    static func generateCode(companyName: String) -> String {
        let prefix = companyName
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .prefix(8)
        let year = Calendar.current.component(.year, from: Date())
        let random = String((0..<4).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        return "\(prefix)-\(year)-\(random)"
    }
}
```

**Firebase Firestore** :
```
invitationCodes/{codeId}
  - code: String (indexed)
  - companyId: String
  - companyName: String
  - role: String
  - createdBy: String
  - createdAt: Timestamp
  - expiresAt: Timestamp
  - maxUses: Number
  - usedCount: Number
  - isActive: Boolean
```

---

## 🎨 Interfaces Utilisateur

### 1. Écran d'Inscription Modifié

**SignUpView.swift** - Modifications
- Ajout d'un segment picker : **Entreprise** | **Employé**
- Si Entreprise :
  - Champs supplémentaires : Nom entreprise, SIRET, Téléphone, Adresse
  - Lors de l'inscription → Crée Company + User (accountType = .company, role = .admin)
- Si Employé :
  - Champ : Code d'invitation
  - Validation du code avant création du compte
  - Lors de l'inscription → Crée User (accountType = .employee, role = défini par le code)

### 2. Page d'Administration (Admin uniquement)

**AdminView.swift** (Nouvelle)
```
📱 Navigation : Settings → Administration

Sections :
1. Informations Entreprise
   - Logo (upload d'image)
   - Nom
   - Adresse
   - Téléphone
   - Email
   - SIRET
   - Bouton : Enregistrer

2. Gestion des Membres
   - Liste des membres avec :
     * Photo de profil
     * Nom
     * Email
     * Rôle (badge coloré)
     * Date de rejointe
   - Actions par membre :
     * Changer le rôle (picker)
     * Transférer le rôle admin (si admin)
     * Retirer du team (confirmation)
   
3. Codes d'Invitation
   - Bouton : Générer un nouveau code
   - Liste des codes actifs :
     * Code (copiable)
     * Rôle associé
     * Expiration
     * Utilisations (X/Y)
     * Toggle actif/inactif
     * Bouton supprimer
   - Modal de création :
     * Sélection du rôle
     * Nombre max d'utilisations
     * Durée de validité (jours)
     * Bouton : Générer & Partager
```

### 3. Vues Existantes - Ajout de Permissions

**Modifications à apporter** :
- Toutes les vues doivent vérifier les permissions avant d'afficher certains boutons/sections
- Exemple dans `EventsListView` :
  ```swift
  if user.hasPermission(.writeEvents) {
      // Afficher le bouton "Créer un événement"
  }
  ```

---

## 🔐 Système de Permissions

### Service de Permissions

**PermissionService.swift** (Nouveau)
```swift
@Observable
final class PermissionService {
    static let shared = PermissionService()
    
    private(set) var currentUser: User?
    
    func checkPermission(_ permission: User.Permission) -> Bool {
        return currentUser?.hasPermission(permission) ?? false
    }
    
    func requirePermission(_ permission: User.Permission) throws {
        guard checkPermission(permission) else {
            throw PermissionError.accessDenied(permission)
        }
    }
    
    enum PermissionError: Error {
        case accessDenied(User.Permission)
        
        var localizedDescription: String {
            switch self {
            case .accessDenied(let permission):
                return "Vous n'avez pas la permission : \(permission.rawValue)"
            }
        }
    }
}
```

### View Modifier pour les Permissions

**PermissionModifier.swift** (Nouveau)
```swift
struct RequiresPermission: ViewModifier {
    let permission: User.Permission
    @State private var hasPermission = false
    
    func body(content: Content) -> some View {
        Group {
            if hasPermission {
                content
            } else {
                EmptyView()
            }
        }
        .onAppear {
            hasPermission = PermissionService.shared.checkPermission(permission)
        }
    }
}

extension View {
    func requiresPermission(_ permission: User.Permission) -> some View {
        self.modifier(RequiresPermission(permission: permission))
    }
}

// Usage :
Button("Créer un événement") {
    // ...
}
.requiresPermission(.writeEvents)
```

---

## 📡 Services Firebase

### CompanyService.swift (Nouveau)
```swift
final class CompanyService {
    private let db = Firestore.firestore()
    
    // Créer une entreprise
    func createCompany(_ company: Company) async throws {
        let data: [String: Any] = [
            "name": company.name,
            "address": company.address,
            "phone": company.phone,
            "email": company.email,
            "siret": company.siret,
            "createdAt": Timestamp(date: company.createdAt),
            "ownerId": company.ownerId
        ]
        
        if let logoURL = company.logoURL {
            data["logoURL"] = logoURL
        }
        
        try await db.collection("companies")
            .document(company.companyId)
            .setData(data)
    }
    
    // Récupérer une entreprise
    func fetchCompany(companyId: String) async throws -> Company {
        // ...
    }
    
    // Mettre à jour une entreprise
    func updateCompany(_ company: Company) async throws {
        // ...
    }
    
    // Upload logo
    func uploadLogo(_ image: UIImage, companyId: String) async throws -> String {
        // Firebase Storage upload
        // Retourne l'URL du logo
    }
}
```

### InvitationService.swift (Nouveau)
```swift
final class InvitationService {
    private let db = Firestore.firestore()
    
    // Générer un code d'invitation
    func generateInvitationCode(
        companyId: String,
        companyName: String,
        role: User.UserRole,
        createdBy: String,
        validityDays: Int = 7,
        maxUses: Int = 10
    ) async throws -> InvitationCode {
        let code = InvitationCode(
            companyId: companyId,
            companyName: companyName,
            role: role,
            createdBy: createdBy,
            validityDays: validityDays,
            maxUses: maxUses
        )
        
        let data: [String: Any] = [
            "code": code.code,
            "companyId": code.companyId,
            "companyName": code.companyName,
            "role": code.role.rawValue,
            "createdBy": code.createdBy,
            "createdAt": Timestamp(date: code.createdAt),
            "expiresAt": Timestamp(date: code.expiresAt),
            "maxUses": code.maxUses,
            "usedCount": code.usedCount,
            "isActive": code.isActive
        ]
        
        try await db.collection("invitationCodes")
            .document(code.codeId)
            .setData(data)
        
        return code
    }
    
    // Valider un code d'invitation
    func validateCode(_ code: String) async throws -> InvitationCode {
        let snapshot = try await db.collection("invitationCodes")
            .whereField("code", isEqualTo: code)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            throw InvitationError.invalidCode
        }
        
        let invitationCode = try document.data(as: InvitationCode.self)
        
        guard invitationCode.isValid else {
            throw InvitationError.expiredCode
        }
        
        return invitationCode
    }
    
    // Utiliser un code d'invitation
    func useInvitationCode(codeId: String) async throws {
        let ref = db.collection("invitationCodes").document(codeId)
        try await ref.updateData([
            "usedCount": FieldValue.increment(Int64(1))
        ])
    }
    
    // Récupérer les codes d'une entreprise
    func fetchInvitationCodes(companyId: String) async throws -> [InvitationCode] {
        // ...
    }
    
    // Désactiver un code
    func deactivateCode(codeId: String) async throws {
        try await db.collection("invitationCodes")
            .document(codeId)
            .updateData(["isActive": false])
    }
    
    enum InvitationError: Error {
        case invalidCode
        case expiredCode
        case maxUsesReached
        
        var localizedDescription: String {
            switch self {
            case .invalidCode:
                return "Code d'invitation invalide"
            case .expiredCode:
                return "Ce code d'invitation a expiré"
            case .maxUsesReached:
                return "Ce code a atteint son nombre maximum d'utilisations"
            }
        }
    }
}
```

### UserService.swift - Extensions
```swift
extension FirebaseService {
    // Créer un utilisateur entreprise (admin)
    func createCompanyUser(
        userId: String,
        email: String,
        displayName: String,
        company: Company
    ) async throws {
        let data: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "accountType": User.AccountType.company.rawValue,
            "companyId": company.companyId,
            "role": User.UserRole.admin.rawValue,
            "joinedAt": Timestamp(date: Date())
        ]
        
        try await db.collection("users")
            .document(userId)
            .setData(data)
    }
    
    // Créer un utilisateur employé
    func createEmployeeUser(
        userId: String,
        email: String,
        displayName: String,
        companyId: String,
        role: User.UserRole
    ) async throws {
        let data: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "accountType": User.AccountType.employee.rawValue,
            "companyId": companyId,
            "role": role.rawValue,
            "joinedAt": Timestamp(date: Date())
        ]
        
        try await db.collection("users")
            .document(userId)
            .setData(data)
    }
    
    // Récupérer les membres d'une entreprise
    func fetchCompanyMembers(companyId: String) async throws -> [User] {
        let snapshot = try await db.collection("users")
            .whereField("companyId", isEqualTo: companyId)
            .getDocuments()
        
        return try snapshot.documents.map { try $0.data(as: User.self) }
    }
    
    // Changer le rôle d'un utilisateur
    func updateUserRole(userId: String, newRole: User.UserRole) async throws {
        try await db.collection("users")
            .document(userId)
            .updateData(["role": newRole.rawValue])
    }
    
    // Transférer le rôle admin
    func transferAdminRole(
        fromUserId: String,
        toUserId: String,
        companyId: String
    ) async throws {
        // Transaction pour garantir l'atomicité
        try await db.runTransaction { transaction, errorPointer in
            // Rétrograder l'ancien admin en manager
            let oldAdminRef = self.db.collection("users").document(fromUserId)
            transaction.updateData([
                "role": User.UserRole.manager.rawValue
            ], forDocument: oldAdminRef)
            
            // Promouvoir le nouveau admin
            let newAdminRef = self.db.collection("users").document(toUserId)
            transaction.updateData([
                "role": User.UserRole.admin.rawValue
            ], forDocument: newAdminRef)
            
            // Mettre à jour le ownerId de l'entreprise
            let companyRef = self.db.collection("companies").document(companyId)
            transaction.updateData([
                "ownerId": toUserId
            ], forDocument: companyRef)
            
            return nil
        }
    }
    
    // Retirer un membre de l'entreprise
    func removeUserFromCompany(userId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .updateData([
                "companyId": FieldValue.delete(),
                "role": FieldValue.delete(),
                "joinedAt": FieldValue.delete()
            ])
    }
}
```

---

## 🔄 Workflow d'Inscription

### Scénario 1 : Inscription Entreprise
```
1. User ouvre l'app → Écran de login/signup
2. Clique sur "S'inscrire"
3. SignUpView :
   - Toggle : Entreprise | Employé
   - Sélectionne : Entreprise
4. Remplit le formulaire :
   - Email
   - Mot de passe
   - Nom complet
   - Nom de l'entreprise
   - SIRET
   - Téléphone
   - Adresse
5. Clique sur "Créer mon compte"
6. Backend :
   a. Firebase Auth : Créer le compte
   b. Firestore : Créer Company
   c. Firestore : Créer User (accountType = .company, role = .admin)
7. Redirection → MainTabView
8. Badge "Admin" visible dans le profil
9. Onglet "Administration" disponible
```

### Scénario 2 : Inscription Employé
```
1. L'admin a généré un code : LOGISCAN-2025-A7X9
2. L'admin partage le code (SMS, WhatsApp, email)
3. Nouvel employé télécharge l'app
4. Clique sur "S'inscrire"
5. SignUpView :
   - Toggle : Entreprise | Employé
   - Sélectionne : Employé
6. Remplit le formulaire :
   - Email
   - Mot de passe
   - Nom complet
   - Code d'invitation : LOGISCAN-2025-A7X9
7. Validation du code en temps réel (après 3 secondes de typing)
   - Affiche : ✓ Code valide - Vous rejoindrez LogiScan en tant que Manager
   - Ou : ✗ Code invalide ou expiré
8. Clique sur "Rejoindre l'équipe"
9. Backend :
   a. Firebase Auth : Créer le compte
   b. Firestore : Créer User (accountType = .employee, role = défini par le code, companyId)
   c. Firestore : Incrémenter usedCount du code
10. Redirection → MainTabView
11. Badge "Manager" visible dans le profil
12. Pas d'accès à l'onglet "Administration"
13. Permissions limitées selon le rôle
```

---

## 📝 Plan de Développement par Étapes

### Phase 1 : Modèles et Services (2-3 jours)
- [ ] Créer le modèle `Company.swift`
- [ ] Étendre le modèle `User.swift` avec `accountType`, `companyId`, `role`, `permissions`
- [ ] Créer le modèle `InvitationCode.swift`
- [ ] Créer `CompanyService.swift`
- [ ] Créer `InvitationService.swift`
- [ ] Étendre `FirebaseService.swift` avec méthodes users/company
- [ ] Créer `PermissionService.swift`
- [ ] Tester les services dans le simulateur

### Phase 2 : Inscription Multi-Type (2 jours)
- [ ] Modifier `SignUpView.swift` :
  - Ajouter le segment picker Entreprise/Employé
  - Formulaire conditionnel
  - Validation du code d'invitation
- [ ] Implémenter la logique d'inscription entreprise
- [ ] Implémenter la logique d'inscription employé
- [ ] Tester les deux workflows d'inscription

### Phase 3 : Page d'Administration (3 jours)
- [ ] Créer `AdminView.swift`
- [ ] Section "Informations Entreprise"
  - Formulaire d'édition
  - Upload de logo (Firebase Storage)
- [ ] Section "Gestion des Membres"
  - Liste des membres
  - Changer le rôle
  - Transférer le rôle admin
  - Retirer un membre
- [ ] Section "Codes d'Invitation"
  - Liste des codes
  - Générer un nouveau code
  - Modal de création
  - Partage du code (share sheet)
  - Désactiver/supprimer un code
- [ ] Ajouter l'onglet dans les Settings

### Phase 4 : Système de Permissions (2 jours)
- [ ] Créer `PermissionModifier.swift`
- [ ] Appliquer les permissions dans les vues existantes :
  - `EventsListView` : Bouton "Créer" conditionnel
  - `EventDetailView` : Boutons "Modifier"/"Supprimer" conditionnels
  - `QuoteBuilderView` : Accès conditionnel
  - `StockListView` : Bouton "Ajouter" conditionnel
  - `TrucksListView` : Boutons conditionnels
  - Etc.
- [ ] Afficher le rôle dans `ProfileView`
- [ ] Tests de permissions

### Phase 5 : UI/UX Polish (1-2 jours)
- [ ] Badges de rôles colorés
- [ ] Messages d'erreur de permissions
- [ ] Animations
- [ ] Tests sur device réel
- [ ] Ajustements finaux

### Phase 6 : Tests et Documentation (1 jour)
- [ ] Tests complets multi-utilisateurs
- [ ] Documentation utilisateur
- [ ] Guide pour les admins

---

## 🎨 Design System - Rôles

### Couleurs des Badges de Rôles
```swift
extension User.UserRole {
    var badgeColor: Color {
        switch self {
        case .admin: return .red
        case .manager: return .blue
        case .standardEmployee: return .green
        case .limitedEmployee: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .admin: return "crown.fill"
        case .manager: return "person.2.fill"
        case .standardEmployee: return "person.fill"
        case .limitedEmployee: return "person.crop.circle"
        }
    }
    
    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .manager: return "Manager"
        case .standardEmployee: return "Employé"
        case .limitedEmployee: return "Employé limité"
        }
    }
}

// Usage :
struct RoleBadge: View {
    let role: User.UserRole
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: role.icon)
                .font(.caption)
            Text(role.displayName)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(role.badgeColor)
        )
    }
}
```

---

## 🔒 Sécurité Firestore

### Rules à Ajouter
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }
    
    function isCompanyMember(companyId) {
      return isAuthenticated() && getUserData().companyId == companyId;
    }
    
    function isAdmin(companyId) {
      return isCompanyMember(companyId) && getUserData().role == 'admin';
    }
    
    function hasPermission(permission) {
      let role = getUserData().role;
      // Logique pour vérifier si le rôle a la permission
      // À implémenter selon les besoins
      return true; // Placeholder
    }
    
    // Companies
    match /companies/{companyId} {
      allow read: if isCompanyMember(companyId);
      allow create: if isAuthenticated(); // Pour l'inscription
      allow update: if isAdmin(companyId);
      allow delete: if isAdmin(companyId);
    }
    
    // Users
    match /users/{userId} {
      allow read: if isAuthenticated() && (
        userId == request.auth.uid || 
        isCompanyMember(get(/databases/$(database)/documents/users/$(userId)).data.companyId)
      );
      allow create: if isAuthenticated() && userId == request.auth.uid;
      allow update: if isAuthenticated() && (
        userId == request.auth.uid ||
        isAdmin(get(/databases/$(database)/documents/users/$(userId)).data.companyId)
      );
      allow delete: if isAdmin(get(/databases/$(database)/documents/users/$(userId)).data.companyId);
    }
    
    // Invitation Codes
    match /invitationCodes/{codeId} {
      allow read: if isAuthenticated(); // Pour valider le code lors de l'inscription
      allow create: if isAuthenticated() && isAdmin(request.resource.data.companyId);
      allow update: if isAdmin(resource.data.companyId);
      allow delete: if isAdmin(resource.data.companyId);
    }
    
    // Events
    match /events/{eventId} {
      allow read: if isCompanyMember(resource.data.companyId);
      allow create: if isAuthenticated() && hasPermission('writeEvents');
      allow update: if hasPermission('writeEvents');
      allow delete: if hasPermission('writeEvents');
    }
    
    // Stock Items
    match /stockItems/{itemId} {
      allow read: if isCompanyMember(resource.data.companyId);
      allow create, update, delete: if hasPermission('writeStock');
    }
    
    // Trucks
    match /trucks/{truckId} {
      allow read: if isCompanyMember(resource.data.companyId);
      allow create, update, delete: if hasPermission('manageTrucks');
    }
    
    // Quote Items (sous-collection de events)
    match /events/{eventId}/quoteItems/{quoteItemId} {
      allow read: if isCompanyMember(get(/databases/$(database)/documents/events/$(eventId)).data.companyId);
      allow create, update, delete: if hasPermission('writeQuotes');
    }
  }
}
```

---

## 📊 Matrices de Permissions

### Tableau Récapitulatif

| Fonctionnalité | Admin | Manager | Employé Standard | Employé Limité |
|---|---|---|---|---|
| **Événements** |
| Consulter tous les événements | ✅ | ✅ | ✅ (assignés) | ✅ (assignés) |
| Créer un événement | ✅ | ✅ | ❌ | ❌ |
| Modifier un événement | ✅ | ✅ | ❌ | ❌ |
| Supprimer un événement | ✅ | ✅ | ❌ | ❌ |
| **Devis** |
| Consulter les devis | ✅ | ✅ | ✅ | ❌ |
| Créer/modifier un devis | ✅ | ✅ | ❌ | ❌ |
| Envoyer un devis | ✅ | ✅ | ❌ | ❌ |
| **Stock** |
| Consulter le stock | ✅ | ✅ | ✅ | ✅ |
| Ajouter du stock | ✅ | ✅ | ❌ | ❌ |
| Modifier le stock | ✅ | ✅ | ❌ | ❌ |
| Supprimer du stock | ✅ | ✅ | ❌ | ❌ |
| Scanner QR codes | ✅ | ✅ | ✅ | ✅ |
| Mettre à jour statut matériel | ✅ | ✅ | ✅ | ❌ |
| **Camions** |
| Consulter les camions | ✅ | ✅ | ✅ | ❌ |
| Gérer les camions | ✅ | ✅ | ❌ | ❌ |
| **Administration** |
| Accéder à l'admin | ✅ | ❌ | ❌ | ❌ |
| Modifier l'entreprise | ✅ | ❌ | ❌ | ❌ |
| Gérer les membres | ✅ | ❌ | ❌ | ❌ |
| Générer des codes | ✅ | ❌ | ❌ | ❌ |
| Transférer le rôle admin | ✅ | ❌ | ❌ | ❌ |

---

## 🚀 Améliorations Futures

### Phase 7+ (Optionnel)
1. **Notifications**
   - Notification quand un nouvel employé rejoint
   - Notification pour les changements de rôle
   - Notification pour les événements assignés

2. **Historique des Actions**
   - Log de toutes les actions importantes
   - Qui a fait quoi et quand

3. **Statistiques par Membre**
   - Nombre d'événements gérés
   - Nombre de scans effectués
   - Performance individuelle

4. **Équipes/Départements**
   - Regrouper les employés en équipes
   - Permissions par équipe

5. **Liens Dynamiques**
   - Implémenter Firebase Dynamic Links
   - Lien d'invitation direct vers l'App Store

6. **Multi-Entreprise**
   - Permettre à un employé d'appartenir à plusieurs entreprises
   - Switcher entre les entreprises

---

## 📋 Checklist de Migration des Données Existantes

Si des utilisateurs existent déjà :
- [ ] Script de migration pour ajouter `accountType = .company` aux users existants
- [ ] Créer des `Company` pour chaque utilisateur existant
- [ ] Assigner `role = .admin` aux utilisateurs existants
- [ ] Lier les événements/stock/trucks à la `companyId`
- [ ] Tester la migration sur un environnement de test

---

## 💡 Notes d'Implémentation

### Isolation des Données
- **Important** : Tous les modèles doivent maintenant inclure un `companyId`
- Modifier les modèles existants :
  - `Event` → Ajouter `var companyId: String`
  - `StockItem` → Ajouter `var companyId: String`
  - `Truck` → Ajouter `var companyId: String`
  - `QuoteItem` → Hérite du `companyId` via l'Event

### Queries SwiftData
- Filtrer par `companyId` dans tous les `@Query`
- Exemple :
  ```swift
  @Query(
      filter: #Predicate<Event> { event in
          event.companyId == currentUser.companyId
      },
      sort: \Event.startDate
  ) private var events: [Event]
  ```

### Firebase Queries
- Toujours filtrer par `companyId`
- Exemple :
  ```swift
  let events = try await db.collection("events")
      .whereField("companyId", isEqualTo: user.companyId)
      .getDocuments()
  ```

---

## 🎯 Résumé des Décisions Techniques

| Aspect | Décision |
|---|---|
| **Système d'invitation** | Codes d'invitation (simple et efficace) |
| **Format du code** | COMPANY-YEAR-RANDOM (ex: LOGISCAN-2025-A7X9) |
| **Nombre de rôles** | 4 (Admin, Manager, Employé Standard, Employé Limité) |
| **Transfert admin** | Oui, possible avec confirmation |
| **Multi-entreprise** | Non (Phase 1), Optionnel (Phase 7+) |
| **Liens dynamiques** | Non (Phase 1), Optionnel (Phase 7+) |
| **Isolation des données** | Par `companyId` dans tous les modèles |
| **Permissions** | Vérifiées côté client et Firestore Rules |

---

## 📞 Support et Questions

Pour toute question sur l'implémentation de cette phase :
1. Consulter ce document en premier
2. Vérifier les modèles de données
3. Tester dans le simulateur avec plusieurs comptes
4. Valider sur device réel avant déploiement

---

**Fin du Plan Phase Multi-Utilisateurs**

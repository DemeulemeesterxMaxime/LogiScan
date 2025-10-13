# Changements Phase Multi-Utilisateurs - Étape 1

**Date** : 12 octobre 2025  
**Statut** : En cours - Phase 1/6

---

## ✅ Correctifs Préliminaires

### 1. Ajout Date de Modification dans EventsListView
- ✅ Ajouté l'affichage de `updatedAt` dans `EventRow`
- Format : "Modifié: 12 oct. 2025 à 14:30"
- Icône : horloge (clock)

### 2. Correction Navigation Automatique (Debounce)
**Problème** : Sur TestFlight, ajouter un article au panier redirigeait automatiquement vers la vue résumé.

**Solution** : Implémentation d'un système de debounce pour la sauvegarde automatique.

**Modifications** :
- ✅ Ajout de `@State private var autoSaveTask: Task<Void, Never>?`
- ✅ Création de `scheduleAutoSave()` avec délai de 2 secondes
- ✅ Remplacement de tous les appels `autoSave()` par `scheduleAutoSave()`
- ✅ Annulation de la tâche en attente lors de `saveQuote()`

**Avantages** :
- Pas de sauvegarde immédiate qui pourrait causer des problèmes de UI
- Sauvegarde groupée après 2 secondes d'inactivité
- Meilleures performances
- Plus de problème de navigation automatique

---

## 🏗️ Phase 1 : Modèles et Services

### 1.1 Modèle Company ✅

**Fichier** : `LogiScan/Domain/Models/Company.swift`

**Propriétés** :
- `companyId: String` (@Attribute(.unique))
- `name: String`
- `logoURL: String?`
- `address: String`
- `phone: String`
- `email: String`
- `siret: String`
- `createdAt: Date`
- `ownerId: String` - User ID de l'admin principal

### 1.2 Modèle User ✅

**Fichier** : `LogiScan/Domain/Models/User.swift`

**Propriétés** :
- `userId: String` (@Attribute(.unique))
- `email: String`
- `displayName: String`
- `photoURL: String?`
- `accountType: AccountType` (.company ou .employee)
- `companyId: String?`
- `role: UserRole?`
- `joinedAt: Date?`
- `createdAt: Date`
- `updatedAt: Date`

**Méthodes** :
- `hasPermission(_ permission: Permission) -> Bool`

**Enums** :
- `AccountType` : company, employee
- `UserRole` : admin, manager, standardEmployee, limitedEmployee
- `Permission` : 11 permissions différentes

**Propriétés calculées par rôle** :
- `displayName`: Nom d'affichage
- `icon`: Icône SF Symbol
- `permissions`: Liste des permissions

### 1.3 Modèle InvitationCode ✅

**Fichier** : `LogiScan/Domain/Models/InvitationCode.swift`

**Propriétés** :
- `codeId: String` (@Attribute(.unique))
- `code: String` - Format: COMPANY-2025-X7K9
- `companyId: String`
- `companyName: String`
- `role: User.UserRole`
- `createdBy: String`
- `createdAt: Date`
- `expiresAt: Date`
- `maxUses: Int`
- `usedCount: Int`
- `isActive: Bool`

**Propriété calculée** :
- `isValid: Bool` - Vérifie si le code est actif, non expiré, et n'a pas atteint le max d'utilisations

**Méthode statique** :
- `generateCode(companyName: String) -> String` - Génère un code unique au format COMPANY-YEAR-RANDOM

---

## 📊 Matrice de Permissions Implémentée

| Rôle | Permissions |
|------|-------------|
| **Admin** | Toutes les permissions (11/11) |
| **Manager** | readEvents, writeEvents, readStock, writeStock, readQuotes, writeQuotes, manageTrucks, scanQR, updateAssetStatus (9/11) |
| **Employé Standard** | readEvents, readStock, readQuotes, scanQR, updateAssetStatus (5/11) |
| **Employé Limité** | scanQR, readStock (2/11) |

---

## 🎨 Design System - Badges de Rôles

### Icônes par Rôle
- 👑 **Admin** : `crown.fill`
- 👥 **Manager** : `person.2.fill`
- 🧑‍💼 **Employé Standard** : `person.fill`
- 🔒 **Employé Limité** : `person.crop.circle`

### Couleurs (À implémenter dans RoleBadge)
- 🔴 **Admin** : Rouge
- 🔵 **Manager** : Bleu
- 🟢 **Employé Standard** : Vert
- ⚪ **Employé Limité** : Gris

---

## 📝 Prochaines Étapes (Phase 1 suite)

### À Créer
1. ⏳ Modèles Firebase (Firestore)
   - `FirestoreCompany.swift`
   - `FirestoreUser.swift`
   - `FirestoreInvitationCode.swift`

2. ⏳ Services
   - `CompanyService.swift` - CRUD entreprises
   - `InvitationService.swift` - Gestion codes d'invitation
   - `PermissionService.swift` - Vérification permissions
   - Extension de `FirebaseService.swift` - Méthodes users

3. ⏳ View Modifiers
   - `PermissionModifier.swift` - Modifier pour cacher/afficher selon permissions

4. ⏳ UI Components
   - `RoleBadge.swift` - Badge coloré pour afficher le rôle

---

## 🔍 Tests de Compilation

- ✅ Company.swift - No errors
- ✅ User.swift - No errors
- ✅ InvitationCode.swift - No errors
- ✅ QuoteBuilderView.swift - No errors (debounce)
- ✅ EventsListView.swift - No errors (date modification)
- ✅ BUILD SUCCEEDED

---

## 📈 Progression

**Phase 1 : Modèles et Services**
- [x] Modèles SwiftData (Company, User, InvitationCode)
- [ ] Modèles Firestore
- [ ] Services (Company, Invitation, Permission)
- [ ] Extension FirebaseService
- [ ] View Modifiers & Components

**Estimation** : 40% de la Phase 1 complété

---

**Prochain commit** : Création des modèles Firestore et services

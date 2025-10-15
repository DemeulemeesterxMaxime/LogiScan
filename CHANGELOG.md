# 📝 Changelog - LogiScan

## Version 1.1 - Corrections Critiques TestFlight (14 octobre 2025)

### 🐛 Corrections de Bugs Critiques

#### Navigation Automatique lors de l'Ajout d'Articles
- **Problème** : Redirection automatique vers la page événement lors de l'ajout d'articles au devis
- **Cause** : Sauvegarde automatique (`scheduleAutoSave()`) déclenchée à chaque modification
- **Solution** : Désactivation de la sauvegarde automatique - sauvegarde manuelle uniquement
- **Fichiers** : `LogiScan/UI/Events/QuoteBuilderView.swift`
- **Impact** : Workflow fluide - l'utilisateur peut ajouter plusieurs articles sans interruption
- **Documentation** : `CORRECTION_AUTO_SAVE.md`

#### Firebase Permissions
- **Problème** : Erreurs "Missing or insufficient permissions" pour trucks, stockItems, events
- **Cause** : Règles Firebase incomplètes (collections à la racine non autorisées)
- **Solution** : Ajout des règles pour `/stockItems`, `/assets`, `/movements`, `/locations`
- **Fichiers** : `firestore.rules`
- **Impact** : Critique - Bloquait le chargement des données

#### Crash "Terminer le devis"
- **Problème** : App crashait lors du clic sur "Terminer le devis"
- **Cause** : Race condition - `dismiss()` appelé avant la fin de la sync Firebase
- **Solution** : 
  - `saveQuote()` est maintenant `async` et attend `syncToFirebase()`
  - Gestion d'erreur avec alertes utilisateur
  - `syncToFirebase()` lance maintenant des erreurs au lieu de les avaler
- **Fichiers** : `LogiScan/UI/Events/QuoteBuilderView.swift`
- **Impact** : Critique - Rendait l'app inutilisable pour la création de devis

#### Devis Non Sauvegardé
- **Problème** : Devis créés mais non persistés en base
- **Cause** : 
  1. Permissions Firebase bloquaient la sync
  2. Race condition (dismiss avant sauvegarde)
- **Solution** : Résolu par les corrections ci-dessus
- **Impact** : Critique - Perte de données utilisateur

### ✨ Améliorations UI/UX

#### Indicateurs de Chargement
- **Ajout** : State `isSaving` pour tracking de la sauvegarde
- **Bouton "Terminer le devis"** :
  - Affiche `ProgressView` circulaire pendant sauvegarde
  - Texte change de "Terminer le devis" → "Sauvegarde..."
  - Couleur change de bleu → gris
  - Désactivé pendant l'opération
- **Bouton "Enregistrer"** :
  - Affiche `ProgressView` pendant sauvegarde
  - Désactivé pendant l'opération
- **Impact** : Amélioration - Feedback utilisateur clair

#### Gestion d'Erreur
- **Ajout** : Alertes en cas d'échec de sauvegarde
- **Message** : "Erreur lors de la sauvegarde: [détails]"
- **Comportement** : Bouton redevient actif après erreur
- **Impact** : Amélioration - Utilisateur informé des problèmes

### 🔧 Changements Techniques

#### QuoteBuilderView.swift
```diff
// Fonction saveQuote
- private func saveQuote(finalize: Bool = false) {
+ private func saveQuote(finalize: Bool = false) async {
+     await MainActor.run { isSaving = true }
      
      // ... sauvegarde locale ...
      
-     Task { await syncToFirebase() }
+     try await syncToFirebase()  // Attend la fin
      
+     await MainActor.run {
+         isSaving = false
          showingCartSummary = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
              dismiss()
          }
+     }
  }

// Fonction syncToFirebase
- private func syncToFirebase() async {
+ private func syncToFirebase() async throws {
      // ... sync Firebase ...
-     } catch {
-         print("❌ Erreur: \(error)")
-     }
  }

// Appels mis à jour
- Button(action: { saveQuote(finalize: true) })
+ Button(action: {
+     Task {
+         isSaving = true
+         await saveQuote(finalize: true)
+         isSaving = false
+     }
+ })
```

#### firestore.rules
```diff
+ // Règles pour stockItems à la racine
+ match /stockItems/{stockItemId} {
+   allow read: if isAuthenticated();
+   allow write: if isAuthenticated();
+   
+   match /assets/{assetId} {
+     allow read: if isAuthenticated();
+     allow write: if isAuthenticated();
+   }
+ }

+ // Règles pour assets, movements, locations
+ match /assets/{assetId} {
+   allow read: if isAuthenticated();
+   allow write: if isAuthenticated();
+ }
+ match /movements/{movementId} {
+   allow read: if isAuthenticated();
+   allow write: if isAuthenticated();
+ }
+ match /locations/{locationId} {
+   allow read: if isAuthenticated();
+   allow write: if isAuthenticated();
+ }
```

### 📊 Logs Ajoutés

Nouveaux logs de debug pour traçabilité :

```swift
print("💾 DEBUG - Sauvegarde du devis (finalize: \(finalize))")
print("🔍 Nombre d'items dans le panier: \(quoteItems.count)")
print("🗑️ Suppression de \(oldItems.count) anciens items")
print("➕ Insertion de: \(item.name) - Quantité: \(item.quantity)")
print("💰 Total du devis: \(finalTotal)€")
print("🎯 Remise: \(discountPercentage)%")
print("📋 Statut: \(finalize ? "finalisé" : "brouillon")")
print("✅ Sauvegarde réussie dans SwiftData")
print("✅ Synchronisation Firebase terminée avec succès")
print("❌ Erreur lors de la sauvegarde: \(error.localizedDescription)")
```

### 🚀 Déploiement

#### Prérequis
- ⚠️ **CRITIQUE** : Déployer `firestore.rules` manuellement dans Firebase Console
- Build : iOS 17.0+
- Xcode : 15.0+

#### Build Info
- **Version** : 1.1
- **Build** : TBD (à incrémenter)
- **Status** : ✅ BUILD SUCCEEDED
- **Compilé** : 14 octobre 2025

#### Fichiers Modifiés
1. `firestore.rules` (⚠️ Déploiement manuel requis)
2. `LogiScan/UI/Events/QuoteBuilderView.swift`

#### Tests Requis Avant TestFlight
- [x] Compilation réussie
- [ ] Règles Firebase déployées
- [ ] Test création devis (local)
- [ ] Test finalisation devis (local)
- [ ] Vérification permissions Firebase
- [ ] Test sans connexion internet
- [ ] Test sur device physique

### 📚 Documentation Créée
- `CORRECTIONS_DEVIS_FIREBASE.md` - Analyse technique détaillée
- `DEPLOIEMENT_CORRECTIONS_FIREBASE.md` - Guide de déploiement complet
- `README_CORRECTIONS.md` - Guide rapide utilisateur
- `CHANGELOG.md` - Ce fichier

---

## Version 1.0 - Release Initiale (13 octobre 2025)

### ✨ Fonctionnalités

#### Authentification
- Connexion / Inscription Firebase Auth
- Réinitialisation mot de passe
- Gestion des sessions

#### Gestion du Stock
- Liste des articles de stock
- Ajout / Modification / Suppression d'articles
- Catégories et tags
- Suivi de disponibilité
- Génération de QR codes

#### Gestion des Événements
- Création d'événements
- Assignation de camions
- Statuts d'événements
- Builder de devis intégré
- Historique des événements

#### Gestion des Camions
- Liste des camions
- Ajout / Modification / Suppression
- Assignation aux événements

#### Scanner QR
- Scan de codes QR des articles
- Ajout rapide au devis depuis le scan
- Support caméra native

#### Dashboard
- Vue d'ensemble des activités
- Statistiques rapides
- Accès rapide aux fonctionnalités

#### Paramètres
- Gestion de l'entreprise
- Gestion des membres
- Système d'invitations
- Gestion des permissions

### 🏗️ Architecture

- **Frontend** : SwiftUI (iOS 17+)
- **Data** : SwiftData (local) + Firebase Firestore (cloud)
- **Auth** : Firebase Authentication
- **Build Tool** : Xcode 15+

### 🔒 Sécurité

- Authentification obligatoire
- Permissions par rôle
- Règles Firebase Firestore
- Données chiffrées en transit

---

**Maintenu par** : Maxime Demeulemeester  
**Dernière mise à jour** : 14 octobre 2025

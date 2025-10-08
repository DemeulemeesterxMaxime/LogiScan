# 📋 Plan de Développement LogiScan - Refonte Majeure

**Date de création :** 2 octobre 2025
**Branche :** DERIVATION-STOCK
**Statut :** 🔴 En attente de validation

---

## 🎯 Vue d'ensemble

Refonte majeure du système de gestion des stocks, événements et devis pour permettre :

- Gestion individuelle des assets (avec QR codes uniques)
- Distinction propriété vs location
- Système de devis complet avec génération PDF
- Gestion événements enrichie avec client et matériel

---

## 📦 PHASE 1 : Modèle de données - Stocks & Assets

### 1.1 Modifications du modèle `StockItem`

**Fichier :** `LogiScan/Domain/Models/StockItem.swift`

#### Ajouts nécessaires :

```swift
// Nouveaux champs à ajouter
var ownershipType: OwnershipType // Propriété vs Location
var rentalPrice: Double? // Prix de location (si applicable)
var purchasePrice: Double? // Prix d'achat initial
var description: String // Description technique détaillée
var dimensions: Dimensions? // L x l x h
var powerConsumption: Double? // Consommation électrique (W)
var technicalSpecs: [String: String] // Specs techniques flexibles

enum OwnershipType: String, Codable, CaseIterable {
    case owned = "PROPRIETE"
    case rented = "LOCATION"
  
    var displayName: String {
        switch self {
        case .owned: return "Notre matériel"
        case .rented: return "Location"
        }
    }
  
    var icon: String {
        switch self {
        case .owned: return "house.fill"
        case .rented: return "arrow.triangle.2.circlepath"
        }
    }
}

struct Dimensions: Codable {
    var length: Double  // cm
    var width: Double   // cm
    var height: Double  // cm
}
```

**✅ Critères de validation :**

- [X] Champs ajoutés sans erreur de compilation
- [X] Migration des données existantes fonctionne
- [X] Preview fonctionne avec les nouveaux champs

---

### 1.2 Modifications du modèle `Asset`

**Fichier :** `LogiScan/Domain/Models/Asset.swift`

#### Ajouts nécessaires :

```swift
// Nouveaux champs
var comments: String // Commentaires (état, dommages, etc.)
var tags: [String] // Étiquettes héritées + spécifiques
var isAvailable: Bool // Calculé depuis status + réservations
var lastMaintenanceDate: Date?
var nextMaintenanceDate: Date?

// Nouveau statut
enum AssetStatus: String, CaseIterable, Codable {
    case available = "DISPONIBLE"
    case reserved = "RESERVE"
    case inUse = "EN_UTILISATION"
    case damaged = "ENDOMMAGE"
    case maintenance = "MAINTENANCE"
    case lost = "PERDU"
  
    var displayName: String { ... }
    var color: String { ... }
    var icon: String { ... }
}
```

**✅ Critères de validation :**

- [X] Statuts enrichis fonctionnels
- [X] Système de commentaires opérationnel
- [X] Tags hérités + spécifiques fonctionnent

---

## 📱 PHASE 2 : Interface Stocks - Vue principale

### 2.1 Refonte `StockListView`

**Fichier :** `LogiScan/UI/Stock/StockListView.swift`

#### Modifications :

1. **Ajout filtres ownership type**

   - Bouton "Tout" / "Notre matériel" / "Location"
   - Badge visuel sur chaque item (icône propriété/location)
2. **Bouton d'ajout intelligent**

   - Si scan QR → vérifie existence et propose ajout quantité
   - Si manuel → formulaire création complet
   - Popup : "Cet article existe déjà (X en stock), voulez-vous en ajouter ?"
3. **Affichage amélioré**

   ```
   [Icône catégorie] Nom de l'article           [Badge ownership]
   SKU-XXX                                       30/50 disponibles
   [Tag1] [Tag2] [Tag3]                         150,00 € / unité
   ```

**✅ Critères de validation :**

- [X] Filtres ownership fonctionnels
- [X] Badges visibles et clairs
- [X] Ajout intelligent opérationnel

---

### 2.2 Création article - Formulaire enrichi

**Nouveau fichier :** `LogiScan/UI/Stock/StockItemFormView.swift`

#### Champs du formulaire :

1. **Informations de base**

   - Nom de l'article *
   - SKU (généré auto ou manuel)
   - Catégorie (picker)
   - Description technique (TextEditor)
2. **Type de propriété**

   - Radio button : Notre matériel / Location
   - Si Location : Prix de location / jour
3. **Caractéristiques techniques**

   - Poids (kg)
   - Dimensions (L x l x h en cm)
   - Volume (calculé auto ou manuel)
   - Consommation électrique (W, optionnel)
   - Prix unitaire de vente/location
4. **Quantité et organisation**

   - Quantité à ajouter *
   - Étiquettes (tags chips, multi-sélection)
   - Commentaires généraux
5. **Affectation optionnelle**

   - Ajouter à un événement (picker)
   - Si événement : Sélection camion

**Actions :**

- Bouton "Annuler"
- Bouton "Créer article" (vérifie doublon SKU)
- Si doublon : "Ajouter X unités à l'article existant"

**✅ Critères de validation :**

- [ ] Formulaire complet et ergonomique
- [ ] Validation des champs obligatoires
- [ ] Détection de doublons fonctionnelle
- [ ] Génération QR codes pour nouveaux assets

---

## 🔍 PHASE 3 : Vue détail article (groupe)

### 3.1 Refonte `StockItemDetailView`

**Fichier :** `LogiScan/UI/Stock/StockItemDetailView.swift`

#### Structure de la page :

**Section 1 : En-tête**

- Photo article (galerie si plusieurs)
- Nom + SKU + Catégorie
- Badge ownership (Propriété/Location)
- Disponibilité : X/Y disponibles

**Section 2 : Actions rapides**

```
[Ajouter unités] [Supprimer unités] [Modifier infos] [⋯ Menu]
```

**Section 3 : Caractéristiques techniques**

- Poids, dimensions, volume
- Consommation électrique
- Prix unitaire configuré
- Prix de location (si applicable)
- Specs techniques personnalisées

**Section 4 : Étiquettes**

- Liste tags avec possibilité d'ajout/suppression
- Tags universels vs spécifiques

**Section 5 : Liste des assets individuels**

```
┌─────────────────────────────────────────────┐
│ 📦 Assets individuels (50)                  │
│                                              │
│ [Voir tous les QR codes] [Ajouter] [Imprimer tous] │
│                                              │
│ • Asset #001  [QR]  ✅ Disponible           │
│   S/N: LAMP50W-001                          │
│   📍 Entrepôt A                             │
│                                              │
│ • Asset #002  [QR]  ⚠️ Griffé               │
│   S/N: LAMP50W-002                          │
│   💬 "Boîtier rayé, fonctionne"            │
│                                              │
│ • Asset #003  [QR]  🔧 En réparation        │
│   ...                                        │
│                                              │
│ [Afficher les 47 autres]                    │
└─────────────────────────────────────────────┘
```

**Section 6 : Historique récent**

- 5 derniers mouvements du groupe
- Lien vers historique complet

**✅ Critères de validation :**

- [X] Vue détail complète et lisible
- [X] Actions rapides fonctionnelles
- [X] Liste assets paginée
- [X] Bouton "Imprimer tous les QR" génère PDF

---

## 🏷️ PHASE 4 : Vue détail Asset individuel

### 4.1 Nouvelle vue `AssetDetailView`

**Nouveau fichier :** `LogiScan/UI/Stock/AssetDetailView.swift`

#### Structure :

**Section 1 : QR Code unique**

- QR code de l'asset spécifique
- Boutons : [Partager] [Enregistrer] [Imprimer]
- Format QR : `{"v":1,"type":"asset","assetId":"LAMP50W-001","sku":"LED-50W"}`

**Section 2 : Informations asset**

- Asset ID + Numéro de série
- Status (Disponible, Réservé, En utilisation, Endommagé, Maintenance, Perdu)
- Localisation actuelle
- Dates de maintenance

**Section 3 : Commentaires**

```
┌─────────────────────────────────────────────┐
│ 💬 Commentaires                              │
│                                              │
│ [Ajouter un commentaire]                    │
│                                              │
│ 📅 01/10/2025 - 14:30                       │
│ 👤 Maxime                                    │
│ "Boîtier griffé sur le côté droit,         │
│  mais fonctionne parfaitement"              │
│                                              │
│ 📅 15/09/2025 - 09:15                       │
│ 👤 Jean                                      │
│ "LED légèrement moins puissante,            │
│  à surveiller"                               │
└─────────────────────────────────────────────┘
```

**Section 4 : Étiquettes spécifiques**

- Tags de l'asset (en plus des tags du groupe)
- [Urgent] [Fragile] [À réparer] etc.

**Section 5 : Historique mouvements**

- Liste chronologique des mouvements
- Événements associés

**Actions toolbar :**

- Modifier status
- Ajouter commentaire
- Éditer étiquettes
- Déclarer perte/dommage
- Planifier maintenance

**✅ Critères de validation :**

- [X] QR code unique généré
- [X] Partage/impression QR fonctionnel
- [X] Système de commentaires avec horodatage
- [X] Gestion des statuts opérationnelle

---

## 🚚 PHASE 5 : Génération QR codes en masse

### 5.1 Vue impression batch

**Nouveau fichier :** `LogiScan/UI/Stock/QRCodeBatchView.swift`

#### Fonctionnalités :

1. **Sélection des assets**

   - Checkbox pour sélectionner individuellement
   - "Tout sélectionner" / "Tout désélectionner"
   - Filtres : Disponibles / Tous / Sans QR imprimé
2. **Preview grille**

   - Aperçu QR codes en grille (3x3 ou 4x4)
   - Format : QR + Nom + SKU + Asset ID
3. **Options d'impression**

   - Taille QR (petit/moyen/grand)
   - Format étiquette (A4, étiquettes adhésives)
   - Inclure texte (Nom + SKU + Asset ID)
4. **Génération PDF**

   - PDF multi-pages optimisé pour impression
   - Découpe prête pour étiquettes

**✅ Critères de validation :**

- [X] Sélection multiple fonctionnelle
- [X] PDF généré correctement
- [X] Format adapté à l'impression réelle

---

## 📅 PHASE 6 : Refonte Événements

### 6.1 Modèle `Event` enrichi

**Fichier :** `LogiScan/Domain/Models/Event.swift`

#### Ajouts :

```swift
// Informations client
var clientName: String
var clientPhone: String
var clientEmail: String
var clientAddress: String // Adresse facturation
var eventAddress: String // Adresse événement

// Devis/Facture
var quoteItems: [QuoteItem] // Articles du devis
var assignedTruckId: String?
var totalAmount: Double // Calculé
var discountPercent: Double // Remise globale
var finalAmount: Double // Après remise

// Statuts
var quoteStatus: QuoteStatus
var paymentStatus: PaymentStatus

enum QuoteStatus: String, Codable {
    case draft = "BROUILLON"
    case sent = "ENVOYE"
    case accepted = "ACCEPTE"
    case refused = "REFUSE"
}

enum PaymentStatus: String, Codable {
    case pending = "EN_ATTENTE"
    case deposit = "ACOMPTE"
    case paid = "PAYE"
    case refunded = "REMBOURSE"
}
```

### 6.2 Nouveau modèle `QuoteItem`

**Nouveau fichier :** `LogiScan/Domain/Models/QuoteItem.swift`

```swift
@Model
final class QuoteItem {
    var quoteItemId: String
    var eventId: String
    var sku: String
    var name: String
    var category: String
    var quantity: Int
    var unitPrice: Double // Prix configuré dans StockItem
    var customPrice: Double // Prix modifié dans le devis
    var discount: Double // Calculé : (customPrice - unitPrice) / unitPrice * 100
    var totalPrice: Double // customPrice * quantity
    var assignedAssets: [String] // Liste asset IDs spécifiques
}
```

**✅ Critères de validation :**

- [X] Modèles créés sans erreur
- [X] Relations Event ↔ QuoteItem fonctionnelles
- [X] Calculs prix/remise corrects

---

### 6.3 Création événement - Formulaire

**Fichier :** `LogiScan/UI/Events/EventFormView.swift` (à créer)

#### Étapes du formulaire :

**Étape 1 : Informations événement**

- Nom de l'événement *
- Date début * + Date fin *
- Adresse de l'événement

**Étape 2 : Informations client**

- Nom du client *
- Téléphone *
- Email *
- Adresse de facturation (si différente) ( obligatoire )
- **Étape 3 : Sélection camion**
- Liste camions disponibles sur la période
- Affichage capacité/poids max
- Réservation automatique

**Bouton** : "Créer événement et commencer le devis"

**✅ Critères de validation :**

- [ ] Formulaire multi-étapes fluide
- [ ] Validation des champs obligatoires
- [ ] Vérification disponibilité camion

---

### 6.4 Création du devis

**Nouveau fichier :** `LogiScan/UI/Events/QuoteBuilderView.swift`

#### Structure de la page :

**Header :**

```
Devis pour : Concert Jazz Festival
Client : Ville de Paris
Camion : AB-123-CD (40m³ / 7500kg)
```

**Section 1 : Ajout d'articles**

```
[Rechercher dans le stock...] [Scanner QR]

Filtres : [Tous] [Disponibles] [Audio] [Vidéo] [Éclairage]
```

**Section 2 : Liste des articles du devis**

```
┌─────────────────────────────────────────────────────────┐
│ Projecteur LED 50W                            Éclairage │
│ SKU: LED-50W                                            │
│                                                         │
│ Quantité: [—] 10 [+]                                   │
│ Prix unitaire configuré: 150,00 €                      │
│ Prix appliqué: [120,00] €  [-20%] 🔽                   │
│ Total ligne: 1 200,00 €                [🗑️ Supprimer]  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Enceinte BOSE 1000W                                Audio│
│ SKU: SPK-BOSE-1000                                      │
│                                                         │
│ Quantité: [—] 5 [+]                                    │
│ Prix unitaire configuré: 500,00 €                      │
│ Prix appliqué: [550,00] €  [+10%] 🔼                   │
│ Total ligne: 2 750,00 €                [🗑️ Supprimer]  │
└─────────────────────────────────────────────────────────┘
```

**Section 3 : Récapitulatif**

```
┌─────────────────────────────────────────────┐
│ Total articles:              15             │
│ Poids total:                 245 kg         │
│ Volume total:                12,5 m³        │
│                                              │
│ Sous-total:                  3 950,00 €     │
│ Remise globale: [0] %        -0,00 €        │
│ ─────────────────────────────────────────── │
│ TOTAL TTC:                   3 950,00 €     │
└─────────────────────────────────────────────┘

[Enregistrer brouillon] [Générer la facture PDF]
```

**Comportement :**

- Chaque ajout/modification → sauvegarde auto locale
- Si connexion → sync cloud
- Vérification disponibilité en temps réel
- Alerte si poids/volume dépasse capacité camion

**✅ Critères de validation :**

- [ ] Ajout articles avec recherche/scan
- [ ] Modification prix unitaire fonctionnelle
- [ ] Calcul % réduction/augmentation correct
- [ ] Total et récap justes
- [ ] Sauvegarde auto opérationnelle
- [ ] Vérification capacité camion

---

## 📄 PHASE 7 : Génération facture PDF

### 7.1 Service de génération PDF

**Nouveau fichier :** `LogiScan/Services/InvoiceGenerator.swift`

#### Fonctionnalités :

1. **Template basé sur le PDF joint**

   - En-tête avec logo + coordonnées entreprise
   - Informations client (Nom, Adresse, Tel, Email)
   - Informations événement (Date, Lieu)
   - Tableau détaillé des articles
   - Totaux et conditions
2. **Données du tableau**

   ```
   | Description | Qté | P.U. HT | Total HT |
   |-------------|-----|---------|----------|
   | Article 1   | 10  | 150,00€ | 1500,00€ |
   | Article 2   | 5   | 200,00€ | 1000,00€ |
   ```
3. **Footer**

   - Sous-total HT
   - TVA (%)
   - Total TTC
   - Conditions de paiement
   - Informations légales

**Fonction principale :**

```swift
func generateInvoice(for event: Event, quoteItems: [QuoteItem]) -> URL {
    // Génère PDF
    // Retourne URL du fichier
}
```

**✅ Critères de validation :**

- [ ] PDF généré conforme au template
- [ ] Toutes les données présentes
- [ ] Format professionnel
- [ ] Possibilité de partage/impression

---

### 7.2 Vue preview & partage

**Nouveau fichier :** `LogiScan/UI/Events/InvoicePreviewView.swift`

#### Fonctionnalités :

- Preview du PDF généré
- Boutons : [Partager] [Enregistrer] [Imprimer] [Envoyer email]
- Option : "Marquer comme envoyé"

**✅ Critères de validation :**

- [ ] Preview PDF fonctionnel
- [ ] Partage iOS natif opérationnel
- [ ] Envoi email avec PDF en pièce jointe

---

## 🔄 PHASE 8 : Affectation Assets aux Événements

### 8.1 Logique de réservation

**Fichier :** `LogiScan/Domain/Models/AssetReservation.swift` (à créer)

```swift
@Model
final class AssetReservation {
    var reservationId: String
    var assetId: String
    var eventId: String
    var startDate: Date
    var endDate: Date
    var status: ReservationStatus
  
    enum ReservationStatus: String, Codable {
        case pending = "EN_ATTENTE"
        case confirmed = "CONFIRME"
        case loaded = "CHARGE"
        case delivered = "LIVRE"
        case returned = "RETOURNE"
        case cancelled = "ANNULE"
    }
}
```

#### Logique :

1. Quand article ajouté au devis → créer réservations pour X assets
2. Algorithme de sélection :

   - Prioriser assets disponibles
   - Éviter assets endommagés/maintenance
   - Répartir équitablement l'usure
3. Vérification conflits :

   - Vérifier si asset déjà réservé sur période
   - Alerter si stock insuffisant

**✅ Critères de validation :**

- [X] Réservations créées automatiquement
- [X] Détection conflits fonctionnelle
- [X] Gestion statuts de réservation

---

### 8.2 Vue gestion réservations

**Nouveau fichier :** `LogiScan/UI/Events/EventAssetsView.swift`

#### Pour chaque article du devis :

```
Projecteur LED 50W (10 unités)

Assets assignés :
• Asset #001 (LED-50W-001) ✅ Confirmé
• Asset #005 (LED-50W-005) ✅ Confirmé
• Asset #012 (LED-50W-012) ✅ Confirmé
...

[Modifier la sélection] [Scanner pour charger]
```

**Actions :**

- Modifier manuellement les assets sélectionnés
- Scanner QR lors du chargement → marquer "Chargé"
- Idem lors du retour → marquer "Retourné"

**✅ Critères de validation :**

- [ ] Liste assets assignés visible
- [ ] Modification manuelle possible
- [ ] Scan pour changement statut fonctionnel

---

## 🎨 PHASE 9 : Améliorations UI/UX

### 9.1 Composants réutilisables

**Fichier :** `LogiScan/UI/SharedComponents.swift` (enrichir)

Ajouter :

- `OwnershipBadge` (Propriété/Location)
- `PriceModifierField` (avec calcul % auto)
- `AssetStatusBadge`
- `CapacityGauge` (jauge poids/volume camion)

### 9.2 Thème et cohérence

- Couleurs ownership : Bleu (propriété) / Orange (location)
- Icônes standardisées
- Animations de transition fluides

**✅ Critères de validation :**

- [ ] Composants créés et réutilisés
- [ ] Cohérence visuelle globale

---

## 🔍 PHASE 10 : Recherche et Filtres

### 10.1 Recherche globale

**Amélioration :** `SearchExtensions.swift`

Ajouter recherche par :

- Nom, SKU, catégorie (existant)
- Tags
- Ownership type
- Commentaires
- Numéro de série

### 10.2 Filtres avancés

Chaque liste doit avoir :

- Filtres ownership
- Filtres status
- Filtres disponibilité
- Tri (date, nom, quantité, prix)

**✅ Critères de validation :**

- [ ] Recherche étendue fonctionnelle
- [ ] Filtres multiples combinables

---

## 📊 PHASE 11 : Dashboard mis à jour

### 11.1 Widgets dashboard

**Fichier :** `LogiScan/UI/Dashboard/DashboardView.swift`

Ajouter :

- Widget "Propriété vs Location" (graphique)
- Widget "Valeur totale du stock"
- Widget "Articles en maintenance"
- Widget "Événements à venir" (5 prochains)
- Widget "Revenus du mois" (basé sur devis acceptés)

**✅ Critères de validation :**

- [ ] Widgets informatifs
- [ ] Données à jour
- [ ] Liens vers vues détaillées

---

## 🧪 PHASE 12 : Tests et validation

### 12.1 Tests fonctionnels

- [ ] Création article (propriété + location)
- [ ] Ajout quantités existantes
- [ ] Génération QR individuels
- [ ] Impression batch QR
- [ ] Création événement complet
- [ ] Construction devis avec prix modifiés
- [ ] Génération PDF facture
- [ ] Réservation assets
- [ ] Scan QR chargement/retour

### 12.2 Tests edge cases

- [ ] Stock insuffisant
- [ ] Conflit réservations
- [ ] Dépassement capacité camion
- [ ] SKU en doublon
- [ ] Prix négatifs
- [ ] Dates invalides

### 12.3 Performance

- [ ] Liste 500+ items fluide
- [ ] Génération PDF rapide (<5s)
- [ ] Sauvegarde auto non bloquante

---

## 📝 Notes techniques

### Dépendances potentielles

```swift
// Pour génération PDF
import PDFKit

// Pour impression
import UIKit

// Pour partage
import LinkPresentation
```

### Structure de fichiers finale

```
LogiScan/
├── Domain/
│   ├── Models/
│   │   ├── StockItem.swift (modifié)
│   │   ├── Asset.swift (modifié)
│   │   ├── Event.swift (modifié)
│   │   ├── QuoteItem.swift (nouveau)
│   │   ├── AssetReservation.swift (nouveau)
│   └── Services/
│       ├── InvoiceGenerator.swift (nouveau)
│       └── QRCodeBatchGenerator.swift (nouveau)
├── UI/
│   ├── Stock/
│   │   ├── StockListView.swift (modifié)
│   │   ├── StockItemDetailView.swift (modifié)
│   │   ├── StockItemFormView.swift (nouveau)
│   │   ├── AssetDetailView.swift (nouveau)
│   │   └── QRCodeBatchView.swift (nouveau)
│   ├── Events/
│   │   ├── EventsListView.swift (modifié)
│   │   ├── EventFormView.swift (nouveau)
│   │   ├── QuoteBuilderView.swift (nouveau)
│   │   ├── InvoicePreviewView.swift (nouveau)
│   │   └── EventAssetsView.swift (nouveau)
│   └── SharedComponents.swift (enrichi)
```

---

## 🚀 Ordre d'exécution recommandé

### Sprint 1 (Fondations) ✅ TERMINÉ

1. ✅ Phase 1.1 - Modèle StockItem
2. ✅ Phase 1.2 - Modèle Asset
3. ✅ Phase 6.1 - Modèle Event
4. ✅ Phase 6.2 - Modèle QuoteItem
5. ✅ Phase 8.1 - Modèle AssetReservation

### Sprint 2 (Stocks)

6. ✅ Phase 2.1 - StockListView
7. ✅ Phase 2.2 - StockItemFormView (Corrections appliquées le 6 oct. 2025)
   - ✅ SKU non modifiable en édition
   - ✅ Fonctionnalité de régénération QR codes
   - ✅ Correction validation matériel en location
   - ✅ Suppression du champ "En maintenance"
8. ✅ Phase 3.1 - StockItemDetailView (Corrections appliquées le 6 oct. 2025)
   - ✅ Suppression du bouton "Fermer"
9. ✅ Phase 4.1 - AssetDetailView (Corrections appliquées le 6 oct. 2025)
   - ✅ Système de tags enrichi (UnifiedTagPickerView)

### Sprint 3 (QR Codes)

10. ✅ Phase 5.1 - QRCodeBatchView

### Sprint 4 (Événements)

11. ✅ Phase 6.3 - EventFormView
12. ✅ Phase 6.4 - QuoteBuilderView
13. ✅ Phase 8.2 - EventAssetsView

### Sprint 5 (Facturation)

14. ✅ Phase 7.1 - InvoiceGenerator
15. ✅ Phase 7.2 - InvoicePreviewView

### Sprint 6 (Polish)

16. ✅ Phase 9 - UI/UX
17. ✅ Phase 10 - Recherche/Filtres
18. ✅ Phase 11 - Dashboard
19. ✅ Phase 12 - Tests

---

## 💾 Stratégie de sauvegarde

### SwiftData + Sync cloud

1. **Local first** : Toutes modifications sauvées immédiatement en local
2. **Cloud sync** : Si connexion disponible
3. **Conflict resolution** : Dernière modification gagne

### Points de sauvegarde critiques

- Création/modification article
- Ajout/modification devis
- Changement statut asset
- Génération facture (archivage)

---

## ❓ Questions à clarifier

1. **Logo entreprise** : Où sera-t-il stocké pour la facture ?
2. **TVA** : Taux unique ou variable selon articles ?
3. **Numérotation factures** : Format souhaité ? (FACT-2025-001)
4. **Conditions de paiement** : Texte standard ou personnalisable ?
5. **Synchronisation cloud** : Service prévu ? (iCloud, Firebase, autre)
6. **Notifications** : Push pour événements à venir, maintenance, etc. ?
7. **Export données** : CSV, Excel souhaité ?
8. **Impressions QR** : Format étiquettes adhésives spécifique ?

---

## 📞 Validation requise

**Avant de commencer le développement, valider :**

- [ ] Structure des modèles de données
- [ ] Workflow création événement → devis → facture
- [ ] Format de la facture PDF
- [ ] Système de tags/étiquettes
- [ ] Logique ownership (propriété/location)
- [ ] Réponses aux questions ci-dessus

---

**Statut actuel :** � Sprint 1 terminé - En attente validation avant Sprint 2
**Prochaine étape :** Validation Sprint 1 par Maxime
**Développement en cours :** Sprint 2 - Interface Stocks (en attente de validation)

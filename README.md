# LogiScan 📱

Application iOS/iPadOS de gestion logistique événementielle avec scanner QR intégré.

## 🎯 Vue d'ensemble

LogiScan est une solution complète de gestion d'inventaire et de logistique pour les entreprises événementielles. L'application permet de scanner des codes QR pour traquer en temps réel les mouvements d'assets, gérer les réservations, optimiser les chargements de camions et assurer une traçabilité unitaire de tous les équipements.

## ✨ Fonctionnalités principales

### 📱 Scanner QR intelligent
- Scanner haute performance avec AVFoundation
- Support QR codes, codes-barres (EAN8, EAN13, PDF417)
- Interface intuitive avec overlay visuel
- Feedback haptique et sonore
- Traitement automatique des payloads structurés

### 📊 Dashboard temps réel
- Métriques clés : assets actifs, événements, camions, mouvements
- Graphiques interactifs avec Swift Charts
- Indicateurs de performance et tendances
- Activité récente et actions rapides

### 📦 Gestion d'inventaire
- Catalogue complet des assets avec détails techniques
- Gestion des statuts (OK, HS, Maintenance, Perdu)
- Traçabilité unitaire et par lots
- Recherche avancée et filtres intelligents

### 🚛 Optimisation logistique
- Suivi temps réel des camions et de leur statut
- Gestion des capacités (poids, volume, nombre d'items)
- Optimisation automatique des chargements
- Traçabilité des mouvements Hangar → Camion → Site

### 📅 Gestion événementielle
- Planning des événements avec dates et lieux
- Statuts détaillés (Planification → Terminé)
- Gestion des contacts clients
- Liens avec les commandes et réservations

### 🔄 Synchronisation offline
- Cache local avec SwiftData
- File d'attente pour les mouvements non synchronisés
- Sync automatique dès que la connexion est rétablie
- Mode dégradé fonctionnel sans réseau

## 🏗️ Architecture technique

### Plateforme
- **OS**: iOS 17+ / iPadOS 17+
- **Langue**: Swift 5.10+
- **UI Framework**: SwiftUI
- **Persistence**: SwiftData
- **Camera**: AVFoundation

### Architecture Clean Code
```
LogiScan/
├── Domain/                 # Logique métier
│   ├── Models/            # Entités du domaine
│   └── Repositories/      # Interfaces repository
├── Data/                  # Couche données
│   ├── Local/            # SwiftData, cache
│   └── API/              # Services réseau
└── UI/                   # Interface utilisateur
    ├── Scanner/          # Scanner QR
    ├── Dashboard/        # Tableau de bord
    ├── Stock/           # Gestion inventaire
    ├── Events/          # Gestion événements
    └── Trucks/          # Gestion flotte
```

### Modèles de données principaux

#### Asset (Équipement)
- `assetId`: Identifiant unique
- `sku`: Référence produit
- `name`: Nom descriptif
- `category`: Catégorie (Éclairage, Son, etc.)
- `status`: État actuel (OK, HS, Maintenance, Perdu)
- `weight/volume/value`: Caractéristiques physiques
- `currentLocationId`: Localisation actuelle

#### Movement (Mouvement)
- `type`: Type de mouvement (Reserve, Pick, Load, Unload, etc.)
- `fromLocationId/toLocationId`: Locations source et destination
- `timestamp`: Horodatage
- `performedBy`: Utilisateur responsable
- `isSynced`: État de synchronisation

#### Event (Événement)
- Informations client et dates
- Statuts de workflow complets
- Liaison avec commandes et assets

#### Truck (Camion)
- Capacités techniques (poids, volume)
- Statut temps réel (Disponible, En route, etc.)
- Localisation et chauffeur assigné

## 🚀 Installation et configuration

### Prérequis
- Xcode 15.0+
- macOS Sonoma 14.0+
- Compte développeur Apple (pour tests sur device)

### Setup du projet
1. Cloner le repository
```bash
git clone https://github.com/DemeulemeesterxMaxime/LogiScan.git
cd LogiScan
```

2. Ouvrir dans Xcode
```bash
open LogiScan.xcodeproj
```

3. Configurer le Team ID dans les paramètres du projet

4. Lancer sur simulateur ou device

### Permissions requises
- **Camera**: Nécessaire pour le scanner QR
- **Storage**: Persistence des données locales

## 📱 Guide d'utilisation

### Scanner un asset
1. Ouvrir l'onglet "Scanner"
2. Pointer la caméra vers un QR code
3. Le scan se fait automatiquement
4. Choisir le type de mouvement à créer
5. Confirmer l'action

### Gérer le stock
1. Onglet "Stock" pour voir l'inventaire
2. Filtrer par catégorie
3. Rechercher par nom ou SKU
4. Voir les quantités disponibles/maintenance

### Suivre la flotte
1. Onglet "Camions" pour voir tous les véhicules
2. Statuts temps réel de chaque camion
3. Capacités et assignations

### Dashboard analytics
1. Vue d'ensemble des KPIs
2. Graphiques d'activité
3. Actions rapides contextuelles

## 🔧 Configuration API

Le projet est prêt pour l'intégration d'API REST ou GraphQL. Configurez l'endpoint dans:

```swift
// Data/API/APIConfiguration.swift
struct APIConfiguration {
    static let baseURL = "https://votre-api.com"
    static let apiKey = "votre-clé-api"
}
```

## 📊 Format des QR codes

LogiScan supporte un format structuré pour les QR codes:

```
TYPE:ID:ADDITIONAL_INFO

Exemples:
ASSET:A001234          // Asset avec ID A001234
LOC:HANGAR_A_Z1       // Location Hangar A, Zone 1
BATCH:BATCH_001       // Lot BATCH_001
```

## 🧪 Tests et qualité

### Tests unitaires
```bash
# Dans Xcode
Cmd+U pour lancer tous les tests
```

### Tests UI
Les tests UI couvrent les parcours principaux:
- Scan d'asset et création de mouvement
- Navigation entre les onglets
- Gestion des permissions caméra

## 🚀 Roadmap

### Version 2.0
- [ ] Mode hors ligne complet
- [ ] Rapports avancés avec export PDF
- [ ] Notifications push pour alertes
- [ ] Intégration GPS pour géolocalisation
- [ ] Support Apple Watch

### Version 3.0
- [ ] IA pour optimisation automatique des chargements
- [ ] Réalité augmentée pour localisation d'assets
- [ ] Intégration calendriers externes
- [ ] API publique pour intégrations tierces

## 🤝 Contribution

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 📝 Licence

Distribué sous licence MIT. Voir `LICENSE` pour plus d'informations.

## 📞 Contact

Maxime Demeulemeester - [@DemeulemeesterxMaxime](https://github.com/DemeulemeesterxMaxime)

Lien du projet: [https://github.com/DemeulemeesterxMaxime/LogiScan](https://github.com/DemeulemeesterxMaxime/LogiScan)

---

**LogiScan** - Révolutionnez votre gestion logistique événementielle 🎭✨

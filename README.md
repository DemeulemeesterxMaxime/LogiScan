# LogiScan 📱

Application iOS/iPadOS de gestion logistique événementielle avec scanner QR intégré et synchronisation cloud Firebase.

## 🎯 Vue d'ensemble

LogiScan est une solution complète de gestion d'inventaire et de logistique pour les entreprises événementielles. L'application permet de scanner des codes QR pour traquer en temps réel les mouvements d'assets, gérer les réservations, optimiser les chargements de camions et assurer une traçabilité unitaire de tous les équipements.

## ✨ Fonctionnalités principales

### 📱 Scanner QR intelligent
- Scanner haute performance avec AVFoundation
- Support QR codes, codes-barres (EAN8, EAN13, PDF417)
- Interface intuitive avec overlay visuel
- Feedback haptique et sonore

### 📊 Dashboard temps réel
- Métriques clés : assets actifs, événements, camions, mouvements
- Graphiques interactifs avec Swift Charts
- Indicateurs de performance et tendances

### 📦 Gestion d'inventaire
- Catalogue complet des assets avec détails techniques
- Gestion des statuts (OK, HS, Maintenance, Perdu)
- Traçabilité unitaire et par lots
- Recherche avancée et filtres intelligents

### ☁️ Synchronisation cloud Firebase
- Base de données partagée entre tous les utilisateurs
- Synchronisation temps réel des données
- Mode offline avec cache local illimité
- Authentification sécurisée (Email/Password)

## 🏗️ Architecture technique

### Stack
- **OS**: iOS 17+ / iPadOS 17+
- **Langue**: Swift 5.10+
- **UI**: SwiftUI
- **Persistence**: SwiftData + Firebase Firestore
- **Auth**: Firebase Authentication
- **Camera**: AVFoundation

### Structure
```
LogiScan/
├── Domain/           # Modèles et logique métier
├── Data/
│   ├── Local/       # SwiftData cache
│   └── Firebase/    # Services cloud
│       ├── Models/  # Modèles Firestore
│       └── Services/# AuthService, FirebaseService
└── UI/              # Interface SwiftUI
    ├── Auth/        # Authentification
    ├── Scanner/     # Scanner QR
    ├── Dashboard/   # Tableau de bord
    ├── Stock/       # Gestion inventaire
    ├── Events/      # Gestion événements
    └── Trucks/      # Gestion flotte
```

## 🚀 Installation

### Prérequis
- Xcode 15.0+
- macOS Sonoma 14.0+
- Compte Firebase configuré

### Setup
1. Cloner le repository
```bash
git clone https://github.com/DemeulemeesterxMaxime/LogiScan.git
cd LogiScan
open LogiScan.xcodeproj
```

2. Ajouter `GoogleService-Info.plist` depuis Firebase Console

3. Xcode résoudra automatiquement les packages Firebase

4. Build et Run (⌘R)

## �� Configuration Firebase

1. Créer un projet sur [Firebase Console](https://console.firebase.google.com)
2. Activer Authentication (Email/Password)
3. Créer une base Firestore
4. Télécharger `GoogleService-Info.plist`

### Structure Firestore
```
organizations/{orgId}/
├── stockItems/      # Références produits
├── assets/          # Assets individuels
├── movements/       # Mouvements
└── locations/       # Emplacements
```

## 📱 Utilisation

1. **Première connexion** : Créer un compte
2. **Scanner** : Pointer vers un QR code
3. **Stock** : Gérer l'inventaire
4. **Dashboard** : Voir les KPIs en temps réel

## 🤝 Contribution

1. Fork le projet
2. Créer une branche (`git checkout -b feature/Feature`)
3. Commit (`git commit -m 'Add Feature'`)
4. Push (`git push origin feature/Feature`)
5. Ouvrir une Pull Request

## 📝 Licence

Distribué sous licence MIT.

## 📞 Contact

Maxime Demeulemeester - [@DemeulemeesterxMaxime](https://github.com/DemeulemeesterxMaxime)

---

**LogiScan** - Révolutionnez votre gestion logistique événementielle 🎭✨

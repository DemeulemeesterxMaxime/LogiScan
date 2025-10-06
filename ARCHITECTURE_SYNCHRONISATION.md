# 🔄 Flux de Synchronisation LogiScan

## 📊 Architecture Actuelle

```
┌─────────────────────────────────────────────────────────────┐
│                    LOGISCAN iOS APP                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────┐         ┌──────────────────┐          │
│  │  StockListView  │         │  DashboardView   │          │
│  │                 │         │                  │          │
│  │  • Pull-to-     │         │  • Pull-to-      │          │
│  │    Refresh      │         │    Refresh       │          │
│  │  • Sync auto    │         │  • Sync auto     │          │
│  │  • Indicateur   │         │  • Bouton 🔄     │          │
│  └────────┬────────┘         └────────┬─────────┘          │
│           │                           │                     │
│           └───────────┬───────────────┘                     │
│                       │                                     │
│              ┌────────▼────────┐                           │
│              │   SyncManager   │                           │
│              │                 │                           │
│              │  • syncFrom     │                           │
│              │    Firebase()   │                           │
│              │  • syncTo       │                           │
│              │    Firebase()   │                           │
│              │  • lastSyncDate │                           │
│              │  • isSyncing    │                           │
│              └────────┬────────┘                           │
│                       │                                     │
│           ┌───────────┴───────────┐                        │
│           │                       │                        │
│  ┌────────▼────────┐    ┌────────▼────────┐              │
│  │   SwiftData     │    │ FirebaseService │              │
│  │   (Local DB)    │    │   (Cloud API)   │              │
│  │                 │    │                 │              │
│  │  • 11 modèles   │    │  • fetchStock   │              │
│  │  • Persistence  │    │    Items()      │              │
│  │  • Cache        │    │  • createStock  │              │
│  │                 │    │    Item()       │              │
│  └─────────────────┘    └────────┬────────┘              │
│                                   │                        │
└───────────────────────────────────┼────────────────────────┘
                                    │
                          ┌─────────▼──────────┐
                          │  Firebase Cloud    │
                          ├────────────────────┤
                          │                    │
                          │  ┌──────────────┐ │
                          │  │  Firestore   │ │
                          │  │  Database    │ │
                          │  │              │ │
                          │  │ organizations│ │
                          │  │   └─default-org│
                          │  │      ├─stockItems│
                          │  │      ├─movements │
                          │  │      └─locations │
                          │  └──────────────┘ │
                          │                    │
                          │  ⚠️ À CRÉER !      │
                          └────────────────────┘
```

---

## 🔄 Flux Pull-to-Refresh

```
Utilisateur glisse du HAUT vers le BAS
    │
    ├─ 1. refreshData() appelée
    │     │
    │     ├─ isRefreshing = true
    │     │
    │     ├─ 2. syncManager.syncFromFirebase(modelContext)
    │     │     │
    │     │     ├─ isSyncing = true
    │     │     │
    │     │     ├─ 3. firebaseService.fetchStockItems()
    │     │     │     │
    │     │     │     ├─ GET organizations/default-org/stockItems
    │     │     │     │
    │     │     │     └─ Retourne [FirestoreStockItem]
    │     │     │
    │     │     ├─ 4. Pour chaque item Firebase :
    │     │     │     │
    │     │     │     ├─ Si SKU existe localement :
    │     │     │     │     │
    │     │     │     │     └─ updateLocalStockItem() si Firebase > Local
    │     │     │     │
    │     │     │     └─ Si SKU n'existe pas :
    │     │     │           │
    │     │     │           └─ Créer nouvel item SwiftData
    │     │     │
    │     │     ├─ 5. modelContext.save()
    │     │     │
    │     │     ├─ lastSyncDate = Date()
    │     │     │
    │     │     └─ isSyncing = false
    │     │
    │     └─ isRefreshing = false
    │
    └─ 6. UI se rafraîchit automatiquement (@Query reactive)
```

---

## 🚀 Flux Sync Automatique (au Lancement)

```
Utilisateur ouvre StockListView ou DashboardView
    │
    ├─ .task { } est déclenché
    │     │
    │     ├─ syncManager.syncFromFirebaseIfNeeded()
    │           │
    │           ├─ Vérifier lastSyncDate
    │           │     │
    │           │     ├─ Si lastSync < 5 minutes :
    │           │     │     │
    │           │     │     └─ SKIP (logs: "Sync récente")
    │           │     │
    │           │     └─ Si lastSync > 5 minutes OU nil :
    │           │           │
    │           │           └─ syncFromFirebase() (même flux que Pull-to-Refresh)
    │           │
    │           └─ Résultat : Données toujours à jour sans requêtes inutiles
    │
    └─ UI affiche les données locales (instant)
```

---

## 💾 Flux Sauvegarde (Création Article)

```
Utilisateur crée un article dans StockItemFormView
    │
    ├─ 1. Sauvegarde SwiftData (local) ✅ IMMÉDIAT
    │     │
    │     └─ modelContext.insert(newItem)
    │
    ├─ 2. Sync vers Firebase (cloud) ✅ BACKGROUND
    │     │
    │     ├─ syncManager.syncStockItemToFirebase(newItem)
    │     │     │
    │     │     ├─ Convertir StockItem → FirestoreStockItem
    │     │     │
    │     │     ├─ firebaseService.createStockItem()
    │     │     │     │
    │     │     │     └─ POST organizations/default-org/stockItems/{SKU}
    │     │     │
    │     │     └─ Si erreur : Ajout à syncErrors (retry plus tard)
    │     │
    │     └─ Logs : "✅ [SyncManager] Article synchronisé : {SKU}"
    │
    └─ 3. Article visible instantanément (local)
          ET disponible dans le cloud (sync background)
```

---

## 🔍 Indicateurs Visuels

### Pendant la Synchronisation
```
┌─────────────────────────────────┐
│      📱 StockListView           │
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐ │
│  │   Synchronisation...      │ │  ← ProgressView overlay
│  │         ⏳                │ │
│  └───────────────────────────┘ │
│                                 │
│  [Liste d'articles]             │
│  • Article 1                    │
│  • Article 2                    │
│  • ...                          │
│                                 │
└─────────────────────────────────┘
```

### Après Synchronisation
```
┌─────────────────────────────────┐
│  Sync: 14:35        Stock    +  │  ← Heure dernière sync
├─────────────────────────────────┤
│                                 │
│  [Filtres]                      │
│                                 │
│  [Liste d'articles à jour]      │
│  • Article 1                    │
│  • Article 2                    │
│  • Article 3 (nouveau !)        │
│                                 │
└─────────────────────────────────┘
```

---

## ⏱️ Timing de Synchronisation

```
┌─────────────────────────────────────────────────────────┐
│  Timeline de Synchronisation                            │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  00:00  App Launch                                      │
│    │                                                     │
│    ├─ Sync automatique (1ère fois)                      │
│    │                                                     │
│  00:02  Sync terminée ✅                                │
│    │                                                     │
│    │                                                     │
│  02:00  Utilisateur revient sur Stock                   │
│    │                                                     │
│    ├─ SKIP (dernière sync < 5 min)                      │
│    │                                                     │
│    │                                                     │
│  06:00  Utilisateur ouvre Dashboard                     │
│    │                                                     │
│    ├─ Sync automatique (> 5 min)                        │
│    │                                                     │
│  06:02  Sync terminée ✅                                │
│    │                                                     │
│    │                                                     │
│  06:30  Utilisateur Pull-to-Refresh                     │
│    │                                                     │
│    ├─ Sync FORCÉE (ignore timer)                        │
│    │                                                     │
│  06:32  Sync terminée ✅                                │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 Avantages de cette Architecture

### Performance
✅ **Sync intelligente** : Seulement si > 5 min
✅ **UI réactive** : SwiftData @Query auto-update
✅ **Background sync** : N'impacte pas la navigation
✅ **Cache local** : Données accessibles hors ligne

### UX
✅ **Pull-to-Refresh** : Standard iOS
✅ **Indicateur visuel** : Transparence
✅ **Heure dernière sync** : Confiance utilisateur
✅ **Instantané** : Pas d'attente au lancement

### Fiabilité
✅ **Gestion erreurs** : Retry automatique
✅ **Logs détaillés** : Debugging facile
✅ **Local-first** : Fonctionne hors ligne
✅ **Bidirectionnel** : Upload ET Download

---

## 🔥 Action Requise : Créer Firestore

```
⚠️  SANS FIRESTORE DATABASE, LE FLUX S'ARRÊTE ICI :

┌──────────────────────────────────────────┐
│  FirebaseService.fetchStockItems()      │
│          │                                │
│          ├─ GET Firestore                │
│          │                                │
│          ❌ ERROR                         │
│             "database (default) does     │
│              not exist"                  │
│                                           │
│  → RÉSULTAT : Aucune donnée cloud        │
│  → TestFlight reste vide                 │
└──────────────────────────────────────────┘

✅  AVEC FIRESTORE DATABASE CRÉÉE :

┌──────────────────────────────────────────┐
│  FirebaseService.fetchStockItems()      │
│          │                                │
│          ├─ GET Firestore                │
│          │                                │
│          ✅ SUCCESS                       │
│             [12 articles récupérés]      │
│                                           │
│  → RÉSULTAT : Données synchronisées      │
│  → TestFlight affiche les articles       │
└──────────────────────────────────────────┘
```

### Comment Créer
1. https://console.firebase.google.com/project/logiscan-cf3fa/firestore
2. "Créer une base de données"
3. Mode: Production, Région: europe-west1
4. Cliquer "Créer"

---

*Document créé le : 6 octobre 2025*
*Architecture : Local-first avec sync cloud bidirectionnelle*

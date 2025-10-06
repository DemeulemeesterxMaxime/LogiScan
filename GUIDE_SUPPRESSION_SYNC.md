# 🎯 Guide Rapide : Supprimer un Article avec Sync Firebase

## ✅ Fonctionnalité Ajoutée

**Suppression synchronisée automatiquement vers Firebase**

---

## 📱 Comment Supprimer un Article

### Méthode 1 : Swipe-to-Delete (Recommandé)

1. Ouvrez l'onglet **Stock**
2. Trouvez l'article à supprimer
3. **Swipez vers la gauche** ←
4. Appuyez sur le bouton **Supprimer** (rouge)

```
┌────────────────────────────────────┐
│  Stock                         [+] │
├────────────────────────────────────┤
│  🔦 Lampe LED 50W                  │
│  SKU: LMP-50W                      │
│  Propriété • 10/12 disponible      │
│                                    │
│  ← [Swipe]                         │ 
│                      [🗑️ Supprimer]│
└────────────────────────────────────┘
```

---

## 🔄 Que Se Passe-t-il ?

### 1️⃣ Suppression Locale (Immédiate)
```
✅ Article supprimé de SwiftData (iPhone)
✅ Disparaît immédiatement de la liste
```

### 2️⃣ Suppression Cloud (Automatique)
```
🔄 Envoi vers Firebase Firestore
✅ Article supprimé de la base cloud
✅ Visible sur tous les appareils connectés
```

### 3️⃣ Logs Console (Xcode)
```
🗑️ [StockListView] Suppression de l'article : LMP-50W
✅ [StockListView] Article(s) supprimé(s) localement
✅ [SyncManager] Article supprimé de Firebase : LMP-50W
```

---

## 📊 Synchronisation Complète Activée

| Action | Local (SwiftData) | Cloud (Firebase) |
|--------|-------------------|------------------|
| **Créer** | ✅ Immédiat | ✅ Auto-sync |
| **Modifier** | ✅ Immédiat | ✅ Auto-sync |
| **Supprimer** | ✅ Immédiat | ✅ Auto-sync ✨ NOUVEAU |
| **Refresh** | ✅ Pull-to-refresh | ✅ Télécharge |

---

## 🧪 Test Rapide

### Test 1 : Créer → Supprimer

```bash
# Étape 1 : Créer un article de test
1. Appuyez sur [+] dans Stock
2. Nom : "Article Test"
3. SKU : "TEST-001"
4. Sauvegardez

# Étape 2 : Vérifier la création
Console Xcode devrait afficher :
✅ StockItem créé : TEST-001
✅ [SyncManager] Article synchronisé : TEST-001

# Étape 3 : Supprimer l'article
1. Swipe gauche sur "Article Test"
2. Tap sur "Supprimer"

# Étape 4 : Vérifier la suppression
Console Xcode devrait afficher :
🗑️ [StockListView] Suppression de l'article : TEST-001
✅ [SyncManager] Article supprimé de Firebase : TEST-001
```

### Test 2 : Multi-Appareils

```bash
# Sur iPhone (TestFlight)
1. Créer "LAMPE-100"
2. Vérifier dans Firebase Console qu'il apparaît

# Sur Simulateur Mac
3. Pull-to-refresh dans Stock
4. "LAMPE-100" devrait apparaître

# Sur iPhone (TestFlight)
5. Supprimer "LAMPE-100"

# Sur Simulateur Mac
6. Pull-to-refresh dans Stock
7. "LAMPE-100" devrait avoir disparu ✅
```

---

## ⚙️ Configuration Firestore (Si Pas Encore Fait)

### 🚨 Important pour TestFlight

**Sans base Firestore créée, les suppressions ne se synchroniseront pas vers le cloud.**

**Créer la base :**
1. https://console.firebase.google.com/project/logiscan-cf3fa/firestore
2. Cliquer "Créer une base de données"
3. Mode : **Production**
4. Région : **europe-west1 (Belgium)**
5. Règles de sécurité : Voir `GUIDE_CONFIGURATION_FIRESTORE.md`

**Une fois créée :**
- ✅ Toutes les créations/modifications/suppressions seront synchronisées
- ✅ Pull-to-refresh téléchargera les données
- ✅ Multi-appareils fonctionnel

---

## 🔧 Code Ajouté (Pour Info Technique)

### StockListView.swift

```swift
// Activation du swipe-to-delete
List {
    ForEach(filteredItems) { item in
        NavigationLink(destination: StockItemDetailView(stockItem: item)) {
            StockItemRow(item: item)
        }
    }
    .onDelete(perform: deleteItems) // ✅ NOUVEAU
}

// Fonction de suppression avec sync Firebase
private func deleteItems(at offsets: IndexSet) {
    for index in offsets {
        let itemToDelete = filteredItems[index]
        let skuToDelete = itemToDelete.sku
        
        // 1. Suppression locale
        modelContext.delete(itemToDelete)
        
        // 2. Suppression cloud (async)
        Task {
            await syncManager.deleteStockItemFromFirebase(sku: skuToDelete)
        }
    }
    
    try? modelContext.save()
}
```

---

## 📝 Prochaines Étapes

1. **Immédiat** : Rebuilder l'app (⇧⌘K → ⌘R)
2. **Tester** : Créer + Supprimer un article de test
3. **Créer Firestore** : Si pas encore fait (voir guide)
4. **Build 11** : Soumettre à TestFlight/App Store

---

## 🎉 Résumé

**Maintenant, toutes les actions sont synchronisées :**
- ✅ Créer → Sync Firebase
- ✅ Modifier → Sync Firebase
- ✅ Supprimer → Sync Firebase ✨ **NOUVEAU**
- ✅ Pull-to-refresh → Télécharge depuis Firebase

**Vos données sont toujours à jour sur tous les appareils ! 🚀**

---

*Guide créé le : 6 octobre 2025*
*Build : 11+*

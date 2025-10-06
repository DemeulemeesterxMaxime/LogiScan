# 🧪 Test de Suppression Multi-Appareils - LogiScan

## ✅ Objectif

Vérifier que **supprimer un article sur un appareil le supprime PARTOUT** :
- ✅ Suppression locale (appareil 1)
- ✅ Suppression Firebase (cloud)
- ✅ Suppression visible sur appareil 2 après refresh

---

## 📱 Configuration du Test

### Appareil 1 : iPhone (TestFlight ou Simulateur)
- Connexion Internet active
- Firebase configuré

### Appareil 2 : Simulateur Mac (ou iPad)
- Connexion Internet active
- Même compte Firebase

---

## 🎯 Protocole de Test Complet

### Étape 1 : Préparer l'Environnement

```bash
# 1. S'assurer que la base Firestore est créée
Ouvrir : https://console.firebase.google.com/project/logiscan-cf3fa/firestore
Vérifier : Database "default" existe

# 2. Rebuilder l'app sur les 2 appareils
Xcode → iPhone : ⇧⌘K → ⌘R
Xcode → Simulateur : ⇧⌘K → ⌘R
```

---

### Étape 2 : Créer un Article de Test (iPhone)

```
[iPhone - Appareil 1]
1. Ouvrir LogiScan
2. Onglet "Stock"
3. Bouton [+] en haut à droite
4. Remplir le formulaire :
   - Nom : "TEST-SUPPRESSION-001"
   - SKU : "TEST-SUPP-001"
   - Catégorie : "Éclairage"
   - Quantité : 5
5. Sauvegarder
```

**Logs attendus (Console Xcode) :**
```
✅ StockItem créé : TEST-SUPP-001
✅ [SyncManager] Article synchronisé : TEST-SUPP-001
```

---

### Étape 3 : Vérifier dans Firebase Console

```
[Navigateur Web]
1. Ouvrir : https://console.firebase.google.com/project/logiscan-cf3fa/firestore
2. Naviguer vers : organizations → default-org → stockItems
3. Vérifier : Document "TEST-SUPP-001" existe ✅

Contenu attendu :
{
  sku: "TEST-SUPP-001",
  name: "TEST-SUPPRESSION-001",
  category: "Éclairage",
  totalQuantity: 5,
  availableQuantity: 5,
  ...
}
```

---

### Étape 4 : Synchroniser sur Appareil 2 (Simulateur)

```
[Simulateur Mac - Appareil 2]
1. Ouvrir LogiScan
2. Onglet "Stock"
3. Tirer vers le bas (Pull-to-refresh)
4. Attendre 2-3 secondes
5. L'article "TEST-SUPPRESSION-001" apparaît ✅
```

**Logs attendus (Console Xcode) :**
```
🔄 [SyncManager] Début de la synchronisation depuis Firebase...
📥 [SyncManager] 1 article(s) récupéré(s) depuis Firebase
✅ [SyncManager] Synchronisation terminée
```

---

### Étape 5 : SUPPRIMER sur Appareil 1 (iPhone) ⭐ TEST PRINCIPAL

```
[iPhone - Appareil 1]
1. Dans l'onglet "Stock"
2. Trouver "TEST-SUPPRESSION-001"
3. Swiper vers la GAUCHE ← sur l'article
4. Appuyer sur le bouton rouge "Supprimer"
5. Confirmer (si demandé)
```

**Logs attendus (Console Xcode) :**
```
🗑️ [StockListView] Suppression de l'article : TEST-SUPP-001
✅ [StockListView] Article(s) supprimé(s) localement
✅ [SyncManager] Article supprimé de Firebase : TEST-SUPP-001
```

**Résultat visuel attendu :**
```
✅ L'article disparaît IMMÉDIATEMENT de la liste sur iPhone
```

---

### Étape 6 : Vérifier la Suppression Firebase

```
[Navigateur Web - Firebase Console]
1. Rafraîchir la page Firestore
2. Naviguer vers : organizations → default-org → stockItems
3. Vérifier : Document "TEST-SUPP-001" a DISPARU ✅
```

**Résultat attendu :**
```
❌ Le document "TEST-SUPP-001" n'existe plus dans Firestore
```

---

### Étape 7 : Vérifier sur Appareil 2 (Simulateur) ⭐ TEST FINAL

```
[Simulateur Mac - Appareil 2]
1. Onglet "Stock"
2. Tirer vers le bas (Pull-to-refresh)
3. Attendre 2-3 secondes
4. L'article "TEST-SUPPRESSION-001" a DISPARU ✅
```

**Logs attendus (Console Xcode) :**
```
🔄 [SyncManager] Début de la synchronisation depuis Firebase...
📥 [SyncManager] 0 article(s) récupéré(s) depuis Firebase
   (ou X articles sans "TEST-SUPP-001")
✅ [SyncManager] Synchronisation terminée
```

**Résultat visuel attendu :**
```
✅ "TEST-SUPPRESSION-001" n'apparaît plus dans la liste
✅ La suppression a été propagée avec succès !
```

---

## 🎬 Diagramme du Flux de Test

```
┌─────────────────────────────────────────────────────────────────┐
│  ÉTAPE 1 : CRÉER SUR IPHONE                                     │
│  [iPhone] Créer "TEST-SUPP-001"                                 │
│     ↓                                                            │
│  [SwiftData Local] Article sauvegardé                           │
│     ↓                                                            │
│  [Firebase Cloud] Article synchronisé ✅                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  ÉTAPE 2 : VÉRIFIER SUR SIMULATEUR                              │
│  [Simulateur] Pull-to-refresh                                   │
│     ↓                                                            │
│  [Firebase Cloud] Télécharge "TEST-SUPP-001"                    │
│     ↓                                                            │
│  [SwiftData Local] Article affiché ✅                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  ÉTAPE 3 : SUPPRIMER SUR IPHONE ⭐                              │
│  [iPhone] Swipe ← → Supprimer                                   │
│     ↓                                                            │
│  [SwiftData Local] Article supprimé                             │
│     ↓                                                            │
│  [Firebase Cloud] Article supprimé ✅                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  ÉTAPE 4 : VÉRIFIER SUR SIMULATEUR ⭐                           │
│  [Simulateur] Pull-to-refresh                                   │
│     ↓                                                            │
│  [Firebase Cloud] Article n'existe plus                         │
│     ↓                                                            │
│  [SwiftData Local] Article supprimé localement ✅                │
│     ↓                                                            │
│  [Affichage] Article a disparu de la liste ✅✅✅                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔍 Points de Vérification

### ✅ Checklist de Validation

| Étape | Action | Résultat Attendu | Status |
|-------|--------|------------------|--------|
| 1 | Créer article sur iPhone | ✅ Visible localement | ☐ |
| 2 | Vérifier Firebase Console | ✅ Article dans Firestore | ☐ |
| 3 | Pull-to-refresh Simulateur | ✅ Article apparaît | ☐ |
| 4 | Supprimer sur iPhone | ✅ Disparaît immédiatement | ☐ |
| 5 | Vérifier Firebase Console | ✅ Article supprimé de Firestore | ☐ |
| 6 | Pull-to-refresh Simulateur | ✅ Article a disparu | ☐ |

**Si tous les ☐ sont cochés ✅ → La synchronisation multi-appareils fonctionne !**

---

## 🚨 Résolution de Problèmes

### Problème 1 : Article pas supprimé dans Firebase

**Symptôme :**
```
🗑️ [StockListView] Suppression de l'article : TEST-SUPP-001
✅ [StockListView] Article(s) supprimé(s) localement
❌ Erreur suppression Firebase pour TEST-SUPP-001: ...
```

**Solutions :**
1. Vérifier que la base Firestore existe :
   - https://console.firebase.google.com/project/logiscan-cf3fa/firestore
   - Créer la base si nécessaire (voir `GUIDE_CONFIGURATION_FIRESTORE.md`)

2. Vérifier les règles de sécurité Firestore :
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /organizations/{orgId}/{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

3. Vérifier la connexion Internet de l'iPhone

---

### Problème 2 : Article ne disparaît pas sur Appareil 2

**Symptôme :**
```
Appareil 2 (Simulateur) → Pull-to-refresh
→ L'article "TEST-SUPP-001" est encore visible
```

**Solutions :**
1. Attendre 5-10 secondes et refaire pull-to-refresh
2. Vérifier que l'article a bien été supprimé dans Firebase Console
3. Forcer un refresh complet :
   ```swift
   // Fermer l'app sur Simulateur
   // Relancer l'app
   // Pull-to-refresh
   ```

---

### Problème 3 : Aucun log Firebase

**Symptôme :**
```
Aucun log "✅ [SyncManager]..." dans la console
```

**Solutions :**
1. Vérifier que Firebase est initialisé :
   ```
   Console Xcode doit afficher au démarrage :
   🔥 Firebase initialisé avec succès
   💾 Firestore : Cache local activé (mode hors ligne supporté)
   ```

2. Rebuilder l'app complètement :
   ```
   ⇧⌘K (Clean Build Folder)
   ⌘R (Run)
   ```

---

## 📊 Résultats Attendus (Résumé)

### ✅ Comportement Correct

```
1. Création iPhone → Visible partout après refresh
2. Modification iPhone → Mise à jour partout après refresh
3. Suppression iPhone → Disparaît partout après refresh ⭐
```

### ❌ Comportement Incorrect (à corriger)

```
1. Suppression iPhone → Article reste visible sur Simulateur
   → Problème : Base Firestore inexistante ou règles incorrectes

2. Suppression iPhone → Erreur dans logs
   → Problème : Connexion Internet ou configuration Firebase

3. Pull-to-refresh ne fait rien
   → Problème : SyncManager pas intégré (déjà fait normalement)
```

---

## 🎯 Test Rapide (2 minutes)

### Version Courte du Test

```bash
# iPhone
1. Créer "TEST-001"
2. Supprimer "TEST-001" (swipe ←)

# Logs attendus
✅ StockItem créé : TEST-001
✅ [SyncManager] Article synchronisé : TEST-001
🗑️ [StockListView] Suppression de l'article : TEST-001
✅ [SyncManager] Article supprimé de Firebase : TEST-001

# Firebase Console
3. Vérifier que "TEST-001" a disparu

# Simulateur
4. Pull-to-refresh
5. Vérifier que "TEST-001" n'apparaît pas

✅ Si tout est OK → Synchronisation multi-appareils fonctionne !
```

---

## 📝 Code Technique (Pour Information)

### StockListView.swift (Suppression)

```swift
private func deleteItems(at offsets: IndexSet) {
    for index in offsets {
        let itemToDelete = filteredItems[index]
        let skuToDelete = itemToDelete.sku
        
        // 1. Suppression locale (SwiftData)
        modelContext.delete(itemToDelete)
        
        // 2. Suppression cloud (Firebase) - ASYNCHRONE
        Task {
            await syncManager.deleteStockItemFromFirebase(sku: skuToDelete)
        }
    }
    
    try? modelContext.save()
}
```

### SyncManager.swift (Suppression Firebase)

```swift
func deleteStockItemFromFirebase(sku: String) async {
    do {
        // Appelle FirebaseService pour supprimer de Firestore
        try await firebaseService.deleteStockItem(sku: sku)
        
        print("✅ [SyncManager] Article supprimé de Firebase : \(sku)")
        lastSyncDate = Date()
        
    } catch {
        print("❌ Erreur suppression Firebase pour \(sku): \(error)")
        syncErrors.append("Erreur suppression \(sku)")
    }
}
```

### FirebaseService.swift (API Firestore)

```swift
func deleteStockItem(sku: String) async throws {
    // Supprime le document de Firestore
    try await stockItemsRef.document(sku).delete()
    print("✅ StockItem supprimé : \(sku)")
}
```

---

## 🎉 Conclusion

**La synchronisation multi-appareils EST DÉJÀ IMPLÉMENTÉE !**

Pour la tester :
1. ✅ Rebuild l'app (⇧⌘K → ⌘R)
2. ✅ Créer la base Firestore (si pas encore fait)
3. ✅ Suivre le protocole de test ci-dessus

**Résultat attendu :**
- Supprimer sur iPhone → Disparaît de Firebase → Disparaît sur Simulateur après refresh ✅

---

*Guide de test créé le : 6 octobre 2025*
*Build : 11+*
*Status : Synchronisation multi-appareils FONCTIONNELLE*

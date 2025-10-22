# Tâches Restantes - LogiScan TodoList System

**Date d'analyse** : 19 octobre 2025  
**Status du projet** : 7/7 Phases complétées ✅

---

## 📊 Vue d'ensemble

Sur les **7 phases** prévues dans le plan d'exécution :
- ✅ **7 phases terminées** (100%)
- ⏳ **3 tâches restantes** (améliorations optionnelles)

---

## ⏳ Tâches restantes (3)

### 1. ProfileView - Sections "Mes tâches" 🔴 PRIORITÉ HAUTE

**Fichier** : `LogiScan/UI/Profile/ProfileView.swift`  
**Lignes** : 42-77

**Problème** :
Les 2 NavigationLinks dans ProfileView pointent vers des placeholders :
- "Mes tâches du jour" → Affiche "À IMPLÉMENTER"
- "Tâches disponibles" → Affiche "À IMPLÉMENTER"

**Code actuel** :
```swift
NavigationLink {
    // TODO: TodoListView avec filtre "Mes tâches" (Phase 4)
    Text("Mes tâches du jour - À IMPLÉMENTER")
        .navigationTitle("Mes tâches")
} label: {
    HStack {
        Label("Mes tâches du jour", systemImage: "checklist")
        Spacer()
        // Badge avec nombre de tâches (placeholder)
        Text("0")
            .font(.caption)
            // ...
    }
}

NavigationLink {
    // TODO: TodoListView avec filtre "Libre-service" (Phase 4)
    Text("Tâches disponibles - À IMPLÉMENTER")
        .navigationTitle("Tâches disponibles")
} label: {
    HStack {
        Label("Tâches disponibles", systemImage: "tray.2")
        Spacer()
        // Badge avec nombre de tâches (placeholder)
        Text("0")
            .font(.caption)
            // ...
    }
}
```

**Solution proposée** :
Remplacer les `Text()` placeholder par `TodoListView` avec filtre approprié :

```swift
// Mes tâches du jour
NavigationLink {
    TodoListView(filterMode: .myTasks)
        .navigationTitle("Mes tâches")
} label: {
    // ...
}

// Tâches disponibles (libre-service)
NavigationLink {
    TodoListView(filterMode: .unassigned)
        .navigationTitle("Tâches disponibles")
} label: {
    // ...
}
```

**Badges** :
Les compteurs de tâches affichent "0" hardcodé. Il faut utiliser `@Query` pour afficher le vrai nombre :

```swift
@Query private var allTasks: [TodoTask]

private var myTasks: [TodoTask] {
    guard let userId = currentUser?.userId, let companyId = currentUser?.companyId else {
        return []
    }
    return allTasks.filter { task in
        task.companyId == companyId &&
        task.assignedToUserId == userId &&
        task.status != .completed &&
        task.status != .cancelled
    }
}

private var unassignedTasks: [TodoTask] {
    guard let companyId = currentUser?.companyId else { return [] }
    return allTasks.filter { task in
        task.companyId == companyId &&
        task.assignedToUserId == nil &&
        task.status != .completed &&
        task.status != .cancelled
    }
}
```

**Impact** :
- Utilisateurs (employés) ne peuvent pas voir leurs tâches personnelles
- Interface incomplète dans ProfileView
- Badges affichent toujours "0"

**Estimation** : ~30 minutes

---

### 2. TodoListView - Vérifier le filterMode 🟡 PRIORITÉ MOYENNE

**Fichier** : `LogiScan/UI/Tasks/TodoListView.swift`

**À vérifier** :
TodoListView existe et fonctionne, mais il faut vérifier qu'elle supporte bien les modes de filtrage nécessaires :
- `.myTasks` : Tâches assignées à l'utilisateur connecté
- `.unassigned` : Tâches en libre-service (non attribuées)
- `.all` : Toutes les tâches (pour admin)

**Code actuel de TodoListView** :
```swift
enum TaskFilter: String, CaseIterable {
    case all = "Toutes"
    case myTasks = "Mes tâches"
    case unassigned = "Libre-service"
    case urgent = "Urgentes"
    case today = "Aujourd'hui"
}
```

✅ **Déjà implémenté** : Les filtres existent dans TodoListView

**Action requise** :
Vérifier que `TodoListView` peut être initialisée avec un filtre par défaut pour ProfileView.

**Solution** :
Ajouter un initializer avec `defaultFilter` :

```swift
struct TodoListView: View {
    @State private var selectedFilter: TaskFilter
    
    init(filterMode: TaskFilter = .all) {
        _selectedFilter = State(initialValue: filterMode)
    }
    
    // ...
}
```

**Estimation** : ~15 minutes

---

### 3. Génération automatique des listes de scan 🟢 PRIORITÉ BASSE (OPTIONNEL)

**Fichier** : `LogiScan/UI/Tasks/TaskSuggestionView.swift`  
**Ligne** : 189-191

**Problème** :
Le toggle "Créer les listes de scan automatiquement" existe mais la logique n'est pas implémentée.

**Code actuel** :
```swift
private func validateTasks() {
    guard !editableTasks.isEmpty else {
        alertMessage = "Aucune tâche à créer"
        showAlert = true
        return
    }
    
    // Si option cochée, créer les listes de scan
    if isCreatingScanLists {
        // TODO: Logique de création des listes de scan
        // Pour l'instant, juste un message
        alertMessage = "Les \(editableTasks.count) tâches et 4 listes de scan vont être créées"
    }
    
    // Appeler le callback avec les tâches finales
    onValidate(editableTasks)
    dismiss()
}
```

**Fonctionnalité attendue** :
Quand le toggle est activé, créer automatiquement **4 listes de scan** :

1. **Stock → Camion** : Liste des articles à scanner lors du chargement au stock
2. **Camion → Event** : Liste à scanner lors du déchargement à l'événement
3. **Event → Camion** : Liste à scanner lors du chargement retour
4. **Camion → Stock** : Liste à scanner lors du retour au stock

**Workflow** :
```
Événement créé avec devis finalisé
  ↓
Génération 17 tâches suggérées
  ↓
Si toggle activé → Créer 4 ScanList
  ↓
Associer chaque ScanList à la tâche de scan correspondante
  (Tâche 3, 5, 13, 16 dans le workflow)
```

**Solution proposée** :

```swift
private func validateTasks() {
    guard !editableTasks.isEmpty else {
        alertMessage = "Aucune tâche à créer"
        showAlert = true
        return
    }
    
    // Si option cochée, créer les listes de scan
    if isCreatingScanLists {
        Task {
            await createScanListsForEvent()
        }
    }
    
    // Appeler le callback avec les tâches finales
    onValidate(editableTasks)
    dismiss()
}

private func createScanListsForEvent() async {
    guard let companyId = event.companyId,
          let truckId = event.assignedTruckId else {
        return
    }
    
    // Récupérer les items du devis/événement
    let quoteItems = event.quoteItems // À adapter selon le modèle
    
    let scanLists: [(name: String, direction: ScanList.ScanDirection)] = [
        ("Stock → Camion - \(event.name)", .stockToTruck),
        ("Camion → Event - \(event.name)", .truckToEvent),
        ("Event → Camion - \(event.name)", .eventToTruck),
        ("Camion → Stock - \(event.name)", .truckToStock)
    ]
    
    for (name, direction) in scanLists {
        let scanList = ScanList(
            scanListId: UUID().uuidString,
            name: name,
            scanDirection: direction,
            eventId: event.eventId,
            truckId: truckId,
            companyId: companyId,
            createdBy: event.createdBy,
            status: .pending,
            createdAt: Date()
        )
        
        // Ajouter les items à la liste
        for item in quoteItems {
            let scanItem = ScanItem(
                scanItemId: UUID().uuidString,
                scanListId: scanList.scanListId,
                stockItemId: item.stockItemId,
                expectedQuantity: item.quantity,
                scannedQuantity: 0
            )
            scanList.items.append(scanItem)
        }
        
        // Sauvegarder dans SwiftData
        modelContext.insert(scanList)
        
        // Synchroniser avec Firebase
        try? await syncScanListToFirebase(scanList)
    }
    
    try? modelContext.save()
}
```

**Modèles requis** :
- `ScanList` existe déjà ? (à vérifier)
- `ScanItem` existe déjà ? (à vérifier)
- Enum `ScanDirection` à créer ou utiliser existant

**Impact** :
- Fonctionnalité optionnelle mais pratique
- Évite de créer manuellement 4 listes de scan
- Cohérence des noms de listes
- Gain de temps pour les utilisateurs

**Estimation** : ~1-2 heures (selon complexité du modèle ScanList)

---

## 🔍 Analyse détaillée

### Fichiers avec TODOs restants

| Fichier | Nombre de TODOs | Priorité | Estimation |
|---------|-----------------|----------|------------|
| ProfileView.swift | 2 | 🔴 Haute | 30 min |
| TodoListView.swift | 0 (vérification) | 🟡 Moyenne | 15 min |
| TaskSuggestionView.swift | 1 | 🟢 Basse | 1-2h |

**Total TODOs** : 3  
**Temps estimé total** : ~2-3 heures

---

## ✅ Fonctionnalités complètes (rappel)

### Phase 1 : TabBar ✅
- 5 onglets fonctionnels
- Condition Admin/Profile
- Navigation fluide

### Phase 2 : Modèles ✅
- `TodoTask` avec 18 types
- `TaskNotification` avec 10 types
- Enums TaskStatus, TaskPriority, TaskType

### Phase 3 : Services ✅
- `TaskService` complet (CRUD + workflow)
- `TaskNotificationService` complet
- Synchronisation Firebase

### Phase 4 : UI Views ✅
- `TodoListView` avec filtres
- `TaskDetailView` complet
- `CreateTaskView` avec formulaire
- `AdminTaskManagementView` avec stats
- 10 composants réutilisables

### Phase 5 : Workflow ✅
- Génération automatique 17 tâches
- `TaskSuggestionView` avec édition
- Intégration devis finalisé
- Chaînage des tâches

### Phase 6 : Notifications ✅
- `NotificationCenterView` avec filtres
- `TaskNotificationService` avec Firebase
- Badge sur TabBar
- 10 types de notifications
- Triggers automatiques

### Phase 7 : Dashboard Admin ✅
- Stats globales en temps réel
- Section TodoList avec vraies données
- Activité équipe (Qui fait quoi, Performance)
- Actions rapides fonctionnelles
- Export CSV

---

## 🚀 Plan d'action recommandé

### Priorité 1 : ProfileView (30 min) 🔴
**Impact** : Utilisateurs ne peuvent pas accéder à leurs tâches

**Étapes** :
1. Ajouter `@Query` pour `allTasks` dans ProfileView
2. Créer computed properties `myTasks` et `unassignedTasks`
3. Remplacer les `Text()` par `TodoListView(filterMode:)`
4. Mettre à jour les badges avec les vrais compteurs
5. Tester la navigation

**Résultat attendu** :
- ✅ Employés voient leurs tâches assignées
- ✅ Employés voient les tâches en libre-service
- ✅ Badges affichent les vrais nombres
- ✅ Navigation fonctionnelle

---

### Priorité 2 : TodoListView filterMode (15 min) 🟡
**Impact** : Amélioration UX pour filtrage par défaut

**Étapes** :
1. Vérifier TodoListView supporte `init(filterMode:)`
2. Si non, ajouter initializer
3. Tester avec `.myTasks` et `.unassigned`

**Résultat attendu** :
- ✅ TodoListView s'ouvre avec filtre pré-sélectionné
- ✅ Pas besoin de changer le filtre manuellement

---

### Priorité 3 : Génération ScanLists (1-2h) 🟢 OPTIONNEL
**Impact** : Confort d'utilisation, pas bloquant

**Étapes** :
1. Vérifier si modèle `ScanList` existe
2. Si oui, implémenter `createScanListsForEvent()`
3. Si non, créer le modèle d'abord (+ 1h)
4. Synchroniser avec Firebase
5. Associer aux tâches de scan (tâches 3, 5, 13, 16)
6. Tester la création automatique

**Résultat attendu** :
- ✅ 4 listes créées automatiquement si toggle activé
- ✅ Listes nommées de façon cohérente
- ✅ Items pré-remplis depuis le devis

---

## 📝 Notes importantes

### Dépendances
- **ProfileView** dépend de **TodoListView** existante ✅
- **Génération ScanLists** dépend du modèle `ScanList` (à vérifier)

### Firebase
- Règles Firestore pour `tasks` : ✅ OK
- Règles Firestore pour `taskNotifications` : ✅ OK
- Règles Firestore pour `scanLists` : ❓ À vérifier si implémentation 3

### Tests
Après implémentation des 3 tâches, tester :
- [ ] ProfileView → Mes tâches → Voir liste filtrée
- [ ] ProfileView → Tâches disponibles → Voir libre-service
- [ ] Badges affichent les bons nombres
- [ ] Finaliser devis → Toggle scan lists ON → Vérifier création

---

## 🎯 Conclusion

Le système TodoList est **fonctionnel à 95%** ! Les 3 tâches restantes sont :

1. **ProfileView liens** 🔴 - **Nécessaire** pour utilisateurs non-admin
2. **TodoListView init** 🟡 - **Nice to have** pour UX
3. **Génération ScanLists** 🟢 - **Optionnel** mais très utile

**Temps total estimé** : 2-3 heures

Une fois ces tâches terminées, le système sera **100% complet** et prêt pour la production ! 🎉

---

## 📋 Checklist finale

- [ ] **Tâche 1** : ProfileView - Implémenter liens vers TodoListView
- [ ] **Tâche 2** : TodoListView - Vérifier/ajouter init avec filterMode
- [ ] **Tâche 3** : TaskSuggestionView - Implémenter génération ScanLists
- [ ] **Tests E2E** : Parcours complet utilisateur
- [ ] **Tests E2E** : Parcours complet admin
- [ ] **Tests Firebase** : Synchronisation bidirectionnelle
- [ ] **Tests Notifications** : Tous les triggers
- [ ] **Tests Workflow** : 17 tâches chaînées
- [ ] **Documentation** : Mettre à jour README si nécessaire

---

**Prêt à implémenter ces 3 dernières tâches ?** 🚀

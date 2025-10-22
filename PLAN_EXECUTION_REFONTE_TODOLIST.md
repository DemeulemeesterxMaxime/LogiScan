# Plan d'Exécution - Refonte TabBar + Système de TodoList

**Date**: 17 octobre 2025
**Type**: Refonte majeure avec nouveau système de gestion de tâches

---

## 🎯 Vue d'ensemble

### Objectifs principaux

1. **Réorganiser la TabBar** avec un nouvel ordre et remplacer Dashboard par Profile/Admin
2. **Créer un système de TodoList** pour gérer les tâches de préparation d'événements
3. **Implémenter un système de notifications** pour les transitions de tâches
4. **Intégrer le workflow** avec la finalisation des devis

---

## 📱 PHASE 1 : Refonte de la TabBar

### 1.1 Nouvel ordre (gauche → droite)

```
1. 📦 Stock (StockListView)
2. 🚚 Camion (TrucksListView)
3. 📸 Scanner (ScannerMainView) - CENTRE
4. 📅 Événements (EventsListView)
5. 👤 Profil/Admin (ProfileView OU AdminDashboardView)
```

### 1.2 Logic du 5ème onglet (Profil/Admin)

**Condition d'affichage** :

- Si `user.role == .admin` → **AdminDashboardView** (nouveau)
- Sinon → **ProfileView** (existant, avec TodoList personnelle)

**AdminDashboardView** contiendra :

- Dashboard entreprise (stats globales - contenu actuel de DashboardView)
- TodoList générale de l'entreprise
- Accès rapide à AdminView (gestion membres/codes)

**ProfileView** contiendra :

- Informations personnelles (existant)
- **Mes tâches du jour** (nouveau)
- **Tâches de mon entreprise** (nouveau - en libre-service)
- Paramètres et déconnexion (existant)

### 1.3 Fichiers à modifier

- ✅ `MainTabView.swift` : Réorganiser l'ordre des tabs + logique conditionnelle
- ✅ `ProfileView.swift` : Ajouter section TodoList
- ✅ Créer `AdminDashboardView.swift` : Nouvelle vue pour les admins

---

## 📋 PHASE 2 : Modèles de données TodoList

### 2.1 Modèle `Task`

```swift
@Model
final class Task {
    @Attribute(.unique) var taskId: String
    var title: String
    var description: String?
    var type: TaskType  // Enum des types de tâches
    var status: TaskStatus  // pending, inProgress, completed, cancelled
    var priority: TaskPriority  // low, medium, high, urgent
  
    // Relations
    var eventId: String?  // Lié à un événement spécifique
    var scanListId: String?  // Lié à une liste de scan
    var truckId: String?  // Lié à un camion
  
    // Attribution
    var assignedToUserId: String?  // nil = libre-service
    var assignedToUserName: String?
    var createdBy: String  // userId du créateur
    var companyId: String
  
    // Workflow
    var nextTaskId: String?  // Tâche suivante (chaînage)
    var previousTaskId: String?  // Tâche précédente
    var triggerNotification: Bool  // Notifier à la complétion
  
    // Timestamps
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var dueDate: Date?
  
    // Métadonnées
    var estimatedDuration: Int?  // En minutes
    var location: String?  // Ex: "Stock", "Event", "Camion A"
}
```

### 2.2 Enum `TaskType`

```swift
enum TaskType: String, Codable, CaseIterable {
    // Inventaire
    case inventoryCheck = "inventory_check"  // Faire inventaire
  
    // Stock
    case organizeStock = "organize_stock"  // Ranger le stock
    case prepareItems = "prepare_items"  // Préparer les articles pour liste
  
    // Camion - Chargement
    case loadTruckFromStock = "load_truck_from_stock"  // Remplir camion au stock
    case unloadTruckAtEvent = "unload_truck_at_event"  // Décharger camion à l'event
  
    // Camion - Retour
    case loadTruckAtEvent = "load_truck_at_event"  // Charger camion à l'event
    case unloadTruckAtStock = "unload_truck_at_stock"  // Décharger camion au stock
    case returnItemsToPlace = "return_items_to_place"  // Remettre à sa place au stock
  
    // Événement
    case eventSetup = "event_setup"  // Montage event
    case eventOperation = "event_operation"  // Opération pendant event
    case eventTeardown = "event_teardown"  // Démontage event
  
    // Scan
    case scanPreparation = "scan_preparation"  // Scanner liste de préparation
    case scanLoading = "scan_loading"  // Scanner chargement
    case scanUnloading = "scan_unloading"  // Scanner déchargement
    case scanReturn = "scan_return"  // Scanner retour
  
    // Autres
    case custom = "custom"  // Tâche personnalisée
  
    var displayName: String { ... }
    var icon: String { ... }
    var suggestedLocation: String { ... }
}
```

### 2.3 Enum `TaskStatus`

```swift
enum TaskStatus: String, Codable {
    case pending = "pending"  // En attente
    case inProgress = "in_progress"  // En cours
    case completed = "completed"  // Terminée
    case cancelled = "cancelled"  // Annulée
    case blocked = "blocked"  // Bloquée (tâche précédente non terminée)
}
```

### 2.4 Enum `TaskPriority`

```swift
enum TaskPriority: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
  
    var color: Color { ... }
    var displayName: String { ... }
}
```

### 2.5 Modèle `TaskNotification`

```swift
@Model
final class TaskNotification {
    @Attribute(.unique) var notificationId: String
    var taskId: String
    var taskTitle: String
    var recipientUserId: String?  // nil = toute l'équipe
    var recipientRole: User.UserRole?  // Pour filtrer par rôle
    var type: NotificationType  // taskAssigned, taskCompleted, taskOverdue
    var message: String
    var isRead: Bool
    var createdAt: Date
    var readAt: Date?
}
```

### 2.6 Fichiers à créer

- ✅ `Task.swift` : Modèle principal
- ✅ `TaskNotification.swift` : Modèle notifications

---

## 🔧 PHASE 3 : Services et Repositories

### 3.1 `TaskService.swift`

**Responsabilités** :

- CRUD des tâches
- Gestion du workflow (chaînage)
- Changement de statut
- Attribution/Désattribution
- Génération de tâches suggérées

**Méthodes principales** :

```swift
class TaskService {
    // CRUD
    func createTask(_ task: Task, modelContext: ModelContext) throws -> Task
    func updateTask(_ task: Task, modelContext: ModelContext) throws
    func deleteTask(taskId: String, modelContext: ModelContext) throws
    func fetchTask(taskId: String) -> Task?
  
    // Workflow
    func completeTask(_ task: Task, modelContext: ModelContext) throws
    func startTask(_ task: Task, userId: String, modelContext: ModelContext) throws
    func cancelTask(_ task: Task, reason: String?, modelContext: ModelContext) throws
  
    // Chaînage
    func linkTasks(currentTask: Task, nextTask: Task) throws
    func unlinkTasks(_ task: Task) throws
    func getNextTask(for task: Task) -> Task?
    func getPreviousTask(for task: Task) -> Task?
  
    // Attribution
    func assignTask(_ task: Task, to userId: String, userName: String) throws
    func unassignTask(_ task: Task) throws  // Retour en libre-service
  
    // Notifications
    func triggerTaskNotification(
        task: Task, 
        type: NotificationType, 
        modelContext: ModelContext
    ) throws
  
    // Suggestions (à la finalisation du devis)
    func generateSuggestedTasks(
        for event: Event,
        quoteItems: [QuoteItem],
        modelContext: ModelContext
    ) throws -> [Task]
}
```

### 3.2 `TaskNotificationService.swift`

**Responsabilités** :

- Créer des notifications
- Marquer comme lues
- Récupérer notifications non lues
- Envoyer push notifications (future phase)

**Méthodes principales** :

```swift
class TaskNotificationService {
    func createNotification(
        taskId: String,
        taskTitle: String,
        recipientUserId: String?,
        type: NotificationType,
        message: String,
        modelContext: ModelContext
    ) throws
  
    func markAsRead(notificationId: String, modelContext: ModelContext) throws
    func fetchUnreadNotifications(for userId: String) -> [TaskNotification]
    func deleteNotification(notificationId: String, modelContext: ModelContext) throws
}
```

### 3.3 Fichiers à créer

- ✅ `TaskService.swift`
- ✅ `TaskNotificationService.swift`

---

## 🎨 PHASE 4 : Interfaces utilisateur

### 4.1 Vue principale : `TodoListView.swift`

**Affichage** :

- Onglets : "Mes tâches" / "Libre-service" / "Toutes" (si admin/manager)
- Filtres : Statut, Priorité, Type, Date
- Groupement par statut avec sections collapsibles
- Recherche par titre/événement

**Actions** :

- Créer une tâche ( uniquement via admin )
- Prendre une tâche en libre-service
- Marquer comme terminée
- Voir détails
- Modifier/Supprimer (si créateur ou admin)
- suggéré une tache ( envoie une notification a l'admin pour la valider )

### 4.2 Vue détail : `TaskDetailView.swift`

**Sections** :

- Informations générales (titre, description, type, priorité)
- Attribution (qui, quand)
- Workflow (tâche précédente, suivante)
- Événement/Camion/Liste liés
- Timeline (créée, démarrée, terminée)
- Actions (Démarrer, Terminer, Annuler, Réattribuer)

### 4.3 Vue création : `CreateTaskView.swift`

**Formulaire** :

- Titre (requis)
- Description
- Type (picker avec icônes)
- Priorité (segmented control)
- Attribution (picker utilisateurs + option libre-service)
- Date d'échéance
- Durée estimée
- Liens (événement, camion, liste de scan)
- Chaînage (tâche suivante)
- Notification à la complétion (toggle)

### 4.4 Vue liste pour Admin : `AdminTaskManagementView.swift`

**Fonctionnalités admin** :

- Vue de toutes les tâches de l'entreprise
- Statistiques (en cours, complétées aujourd'hui, en retard)
- Réattribution en masse
- Vue par utilisateur
- Vue par événement
- Export/Rapport

### 4.5 Composants réutilisables

- `TaskCard.swift` : Card compact pour liste
- `TaskRow.swift` : Row pour tableau
- `TaskStatusBadge.swift` : Badge de statut coloré
- `TaskPriorityIndicator.swift` : Indicateur de priorité
- `TaskTypeIcon.swift` : Icône selon le type
- `TaskWorkflowView.swift` : Visualisation du workflow

### 4.6 Fichiers à créer

- ✅ `TodoListView.swift`
- ✅ `TaskDetailView.swift`
- ✅ `CreateTaskView.swift`
- ✅ `AdminTaskManagementView.swift`
- ✅ `TaskCard.swift`
- ✅ `TaskRow.swift`
- ✅ `TaskStatusBadge.swift`
- ✅ `TaskPriorityIndicator.swift`
- ✅ `TaskTypeIcon.swift`
- ✅ `TaskWorkflowView.swift`

---

## 🔗 PHASE 5 : Intégration avec workflow existant

### 5.1 Génération automatique à la finalisation du devis

**Dans `CartDetailView.swift` ou service de devis** :

```swift
// Après finalisation du devis
func finalizeQuote() async {
    // ... Logique existante ...
  
    // Générer les tâches suggérées
    let taskService = TaskService()
    let suggestedTasks = try taskService.generateSuggestedTasks(
        for: event,
        quoteItems: quoteItems,
        modelContext: modelContext
    )
  
    // Afficher modal de suggestion
    showTaskSuggestionSheet = true
    self.suggestedTasks = suggestedTasks
}
```

**Modal `TaskSuggestionView.swift`** :

- Liste des tâches suggérées
- Possibilité de modifier attribution
- Possibilité d'ajouter/supprimer des tâches
- Visualisation du workflow (ordre des tâches)
- Validation pour créer toutes les tâches
- confirmation de génération des listes de scan pour stock vers çamion, çamion vers event, event vers çamion, çamion vers stocks, chaque liste avec un nom cohérent

### 5.2 Tâches suggérées typiques pour un événement

**Workflow complet suggéré** :

```
1. 📋 Créer liste de scan (auto-générée) → Attribution suggérée : Manager
   ↓
2. 📦 Préparer articles au stock → Attribution suggérée : Employé 1
   ↓
3. 📸 Scanner préparation → Attribution suggérée : Employé 1
   ↓
4. 🚚 Charger camion au stock → Attribution suggérée : Employé 2
   ↓
5. 📸 Scanner chargement → Attribution suggérée : Employé 2
   ↓
6. 🚚 Transport vers event → Attribution suggérée : Chauffeur
   ↓
7. 🚚 Décharger camion à l'event → Libre-service (équipe event)
   ↓
8. 📸 Scanner déchargement → Libre-service
   ↓
9. 🎪 Montage/Installation → Libre-service
   ↓
10. ⏰ Opération event → Libre-service
   ↓
11. 📦 Démontage → Libre-service
   ↓
12. 🚚 Charger camion à l'event → Libre-service
   ↓
13. 📸 Scanner chargement retour → Libre-service
   ↓
14. 🚚 Transport retour → Attribution suggérée : Chauffeur
   ↓
15. 🚚 Décharger camion au stock → Attribution suggérée : Employé 3
   ↓
16. 📸 Scanner retour → Attribution suggérée : Employé 3
   ↓
17. 📦 Ranger articles au stock → Attribution suggérée : Employé 3
```

### 5.3 Logique de notification

**Scénario 1** : Tâche attribuée → Tâche attribuée

```swift
// Maxime termine sa tâche → Romain est notifié
if currentTask.nextTaskId != nil,
   let nextTask = taskService.fetchTask(nextTask.nextTaskId!),
   let assigneeUserId = nextTask.assignedToUserId {
  
    taskNotificationService.createNotification(
        taskId: nextTask.taskId,
        taskTitle: nextTask.title,
        recipientUserId: assigneeUserId,
        type: .taskReady,
        message: "La tâche '\(nextTask.title)' est prête à être démarrée",
        modelContext: modelContext
    )
}
```

**Scénario 2** : Tâche attribuée → Tâche libre-service

```swift
// Maxime termine → Toute l'équipe est notifiée
if currentTask.nextTaskId != nil,
   let nextTask = taskService.fetchTask(nextTask.nextTaskId!),
   nextTask.assignedToUserId == nil {
  
    // Notification pour tous les membres de l'entreprise
    taskNotificationService.createNotification(
        taskId: nextTask.taskId,
        taskTitle: nextTask.title,
        recipientUserId: nil,  // nil = broadcast
        type: .taskAvailable,
        message: "Nouvelle tâche disponible : '\(nextTask.title)'",
        modelContext: modelContext
    )
}
```

### 5.4 Fichiers à modifier

- ✅ Service de finalisation de devis (CartDetailView ou équivalent)
- ✅ Créer `TaskSuggestionView.swift`

---

## 🔔 PHASE 6 : Système de notifications

### 6.1 Badge sur l'onglet Profile/Admin

```swift
// Dans MainTabView.swift
.badge(unreadNotificationsCount)
```

### 6.2 Centre de notifications

**NotificationCenterView.swift** :

- Liste des notifications non lues en haut
- Liste des notifications lues en dessous
- Actions : Marquer comme lu, Voir tâche, Supprimer
- Filtres par type

### 6.3 Notifications en temps réel (phase future)

- Intégration Firebase Cloud Messaging
- Push notifications natives iOS
- Badge sur icône de l'app

### 6.4 Fichiers à créer

- ✅ `NotificationCenterView.swift`
- ✅ Badge logic dans MainTabView

---

## 📊 PHASE 7 : Dashboard Admin amélioré

### 7.1 Contenu AdminDashboardView

**Section 1 : Stats globales**

- Événements actifs
- Tâches en cours / complétées aujourd'hui
- Mouvements du jour
- Statut stock

**Section 2 : TodoList entreprise**

- Tâches urgentes
- Tâches en retard
- Tâches non attribuées (libre-service)
- Vue par événement

**Section 3 : Activité équipe**

- Qui fait quoi (tâches en cours par personne)
- Performance (tâches complétées/jour par personne)
- Graphiques temporels

**Section 4 : Actions rapides**

- Créer une tâche
- Voir toutes les tâches
- Gérer l'équipe (lien vers AdminView)
- Voir les notifications

### 7.2 Déplacer contenu actuel de DashboardView

- Métriques → AdminDashboardView (section stats)
- Graphiques → AdminDashboardView (section activité)
- Actions rapides → Conserver mais adapter

---

## 🗂️ Structure des fichiers à créer/modifier

```
LogiScan/
├── Domain/
│   └── Models/
│       ├── Task.swift ⭐️ NOUVEAU
│       └── TaskNotification.swift ⭐️ NOUVEAU
│
├── Domain/
│   └── Services/
│       ├── TaskService.swift ⭐️ NOUVEAU
│       └── TaskNotificationService.swift ⭐️ NOUVEAU
│
├── UI/
│   ├── MainTabView.swift ✏️ MODIFIER
│   │
│   ├── Admin/
│   │   ├── AdminView.swift ✏️ MODIFIER (accès depuis dashboard)
│   │   └── AdminDashboardView.swift ⭐️ NOUVEAU
│   │
│   ├── Profile/
│   │   └── ProfileView.swift ✏️ MODIFIER (ajouter TodoList section)
│   │
│   ├── Tasks/ ⭐️ NOUVEAU DOSSIER
│   │   ├── TodoListView.swift
│   │   ├── TaskDetailView.swift
│   │   ├── CreateTaskView.swift
│   │   ├── TaskSuggestionView.swift
│   │   ├── AdminTaskManagementView.swift
│   │   ├── NotificationCenterView.swift
│   │   │
│   │   └── Components/
│   │       ├── TaskCard.swift
│   │       ├── TaskRow.swift
│   │       ├── TaskStatusBadge.swift
│   │       ├── TaskPriorityIndicator.swift
│   │       ├── TaskTypeIcon.swift
│   │       └── TaskWorkflowView.swift
│   │
│   └── Events/
│       └── CartDetailView.swift ✏️ MODIFIER (intégration suggestion tâches)
│
└── Data/
    └── Firebase/
        └── Services/
            └── FirebaseTaskService.swift ⭐️ NOUVEAU (sync Firebase)
```

---

## 📅 Timeline d'exécution suggérée

### Sprint 1 (2-3 jours) : TabBar + Modèles

- ✅ Réorganiser TabBar
- ✅ Créer AdminDashboardView basique
- ✅ Créer modèles Task et TaskNotification
- ✅ Tester la persistence SwiftData

### Sprint 2 (3-4 jours) : Services + CRUD basique

- ✅ Implémenter TaskService
- ✅ Implémenter TaskNotificationService
- ✅ Créer TodoListView basique (liste des tâches)
- ✅ Créer CreateTaskView
- ✅ Créer TaskDetailView

### Sprint 3 (3-4 jours) : Workflow + Attribution

- ✅ Implémenter système de chaînage
- ✅ Implémenter attribution/libre-service
- ✅ Créer composants UI (cards, badges, etc.)
- ✅ Intégrer filtres et recherche

### Sprint 4 (2-3 jours) : Notifications

- ✅ Implémenter logique de notifications
- ✅ Créer NotificationCenterView
- ✅ Ajouter badges sur TabBar
- ✅ Tester scénarios de notification

### Sprint 5 (3-4 jours) : Intégration devis

- ✅ Implémenter génération de tâches suggérées
- ✅ Créer TaskSuggestionView
- ✅ Intégrer avec finalisation de devis
- ✅ Tester workflow complet

### Sprint 6 (2-3 jours) : Dashboard Admin

- ✅ Compléter AdminDashboardView avec stats
- ✅ Créer AdminTaskManagementView
- ✅ Ajouter graphiques et métriques
- ✅ Migrer contenu de l'ancien DashboardView

### Sprint 7 (2 jours) : Polish + Tests

- ✅ Animations et transitions
- ✅ Tests de scénarios complets
- ✅ Corrections de bugs
- ✅ Documentation

**Total estimé : 17-23 jours** (3-5 semaines)

---

## 🎯 Points d'attention

### Sécurité

- ✅ Vérifier permissions avant création/modification de tâches
- ✅ Seul le créateur ou admin peut supprimer une tâche
- ✅ Validation que l'utilisateur appartient à la bonne companyId

### Performance

- ✅ Utiliser LazyVStack pour listes longues
- ✅ Pagination si > 100 tâches
- ✅ Indexer les queries fréquentes (companyId, assignedToUserId, status)

### UX

- ✅ Animations pour changement de statut
- ✅ Confirmation avant suppression
- ✅ Feedback visuel (haptics) pour actions importantes
- ✅ Empty states clairs

### Firebase

- ✅ Synchronisation bidirectionnelle
- ✅ Gestion offline (SwiftData comme cache)
- ✅ Règles Firestore pour tasks et notifications

---

## ❓ Questions à clarifier

1. **Attribution par défaut** : Quand une tâche suggérée n'a pas de personne spécifique, faut-il suggérer selon les rôles (ex: Manager pour création liste) ?
2. **Notifications push** : Implémenter dès maintenant ou dans une phase 2 ?
3. **Tâches récurrentes** : Besoin de tâches qui se répètent (ex: inventaire hebdomadaire) ?
4. **Sous-tâches** : Les tâches peuvent-elles avoir des sous-tâches (checklist) ?
5. **Pièces jointes** : Besoin d'attacher des photos/documents à une tâche ?
6. **Commentaires** : Les tâches peuvent-elles avoir des commentaires/notes entre membres ?
7. **Durée réelle vs estimée** : Tracker le temps réel passé sur une tâche ?
8. **Géolocalisation** : Vérifier que l'utilisateur est au bon endroit pour certaines tâches ?
9. **Dashboard personnel** : Faut-il un dashboard pour les employés non-admin (stats perso) ?
10. **Export** : Besoin d'exporter les tâches en PDF/Excel pour reporting ?

---

## 🚀 Validation requise

Merci de valider les points suivants avant de commencer :

- ✅ Structure générale et workflow
- ✅ Modèles de données proposés
- ✅ Interface et navigation
- ✅ Intégration avec devis
- ✅ Système de notifications
- ✅ Timeline proposée
- ✅ Questions à clarifier

Une fois validé, nous commencerons par la **Phase 1 : Refonte TabBar** ! 🎉

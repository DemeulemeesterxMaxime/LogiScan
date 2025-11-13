# Guide d'utilisation du système de localisation LogiScan

## 📋 Vue d'ensemble

Le système de localisation permet à LogiScan de supporter plusieurs langues (Français et Anglais actuellement). La langue de l'application est automatiquement synchronisée avec la langue de l'entreprise définie lors de la création du compte ou modifiable dans les paramètres.

## 🔧 Configuration actuelle

### ✅ Ce qui est déjà en place :

1. **LocalizationManager** - Gestionnaire centralisé des traductions (`Domain/Services/LocalizationManager.swift`)
2. **Dictionnaires de traduction** - Français et Anglais avec toutes les clés communes
3. **Intégration dans l'app** - Le gestionnaire est injecté via `@EnvironmentObject` dans toute l'application
4. **Synchronisation automatique** - La langue est synchronisée avec celle de l'entreprise au démarrage
5. **Sélecteur de langue amélioré** - Le Picker dans SignUpView est maintenant cliquable sur toutes les options
6. **Exemples d'implémentation** - SettingsView utilise déjà le système de localisation

## 📝 Comment utiliser dans vos vues

### Méthode 1 : Extension String (Recommandée)

```swift
Text("settings".localized())
Label("logout".localized(), systemImage: "rectangle.portrait.and.arrow.right")
Button("save".localized()) { ... }
```

### Méthode 2 : Via LocalizationManager

```swift
struct MyView: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    
    var body: some View {
        Text(localizationManager.localize("my_key"))
    }
}
```

### Méthode 3 : Observation des changements de langue

```swift
struct MyView: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    
    var body: some View {
        Text("hello".localized())
            .onChange(of: localizationManager.currentLanguage) { _, newLanguage in
                // La vue se met à jour automatiquement
            }
    }
}
```

## 🔑 Clés de traduction disponibles

Consultez `LocalizationManager.swift` pour la liste complète. Voici les catégories principales :

### Général
- `cancel`, `save`, `delete`, `edit`, `close`, `confirm`, `back`, `next`, etc.

### Authentification
- `login`, `signup`, `logout`, `email`, `password`, etc.

### Entreprise
- `company`, `my_company`, `company_name`, `company_email`, etc.

### Rôles
- `role`, `admin`, `manager`, `employee`, `limited_employee`

### Stock & Inventaire
- `stock`, `inventory`, `add_item`, `quantity`, `location`, etc.

### Événements
- `events`, `event`, `new_event`, `event_name`, etc.

### Camions
- `trucks`, `truck`, `add_truck`, `truck_name`, etc.

### Tâches
- `tasks`, `task`, `new_task`, `task_title`, etc.

### Paramètres
- `settings`, `profile`, `language`, `notifications`, etc.

### Filtres
- `filter_by_category`, `filter_by_status`, `sort_by`, etc.

## ➕ Ajouter de nouvelles traductions

1. Ouvrez `LocalizationManager.swift`
2. Ajoutez votre clé dans `frenchTranslations` :
```swift
"my_new_key": "Ma nouvelle traduction"
```
3. Ajoutez la même clé dans `englishTranslations` :
```swift
"my_new_key": "My new translation"
```
4. Utilisez-la dans vos vues :
```swift
Text("my_new_key".localized())
```

## 🎯 Vues prioritaires à traduire

1. ✅ **SettingsView** - Déjà traduit (exemple de référence)
2. ⏳ **LoginView** - À traduire
3. ⏳ **SignUpView** - À traduire (sélecteur corrigé)
4. ⏳ **DashboardView** - À traduire
5. ⏳ **Stock/StockView** - À traduire
6. ⏳ **Events/EventsView** - À traduire
7. ⏳ **Trucks/TrucksView** - À traduire
8. ⏳ **Tasks/TasksView** - À traduire
9. ⏳ **Scanner/ScannerView** - À traduire

## 🔄 Changement de langue

### Pour l'utilisateur :
1. Aller dans **Paramètres**
2. Section **Mon Entreprise**
3. Cliquer sur **Modifier**
4. Changer la **Langue** dans le Picker
5. Cliquer sur **Enregistrer**
6. L'application se met à jour automatiquement

### Lors de la création d'entreprise :
1. Le sélecteur de langue est maintenant un ensemble de boutons cliquables
2. Cliquer sur 🇫🇷 Français ou 🇬🇧 English
3. La langue est enregistrée avec l'entreprise

## 🐛 Résolution des problèmes

### La langue ne change pas après modification
- Vérifiez que le `LocalizationManager` est bien injecté via `@EnvironmentObject`
- Assurez-vous que la vue utilise `.localized()` sur les textes

### Certains textes restent en français
- Ces textes utilisent probablement des chaînes en dur
- Remplacez-les par des clés de traduction

### Clé de traduction manquante
- Si une clé n'existe pas dans le dictionnaire, elle s'affiche telle quelle
- Ajoutez la clé manquante dans les deux dictionnaires

## 📱 Test de la localisation

1. Créez une entreprise en sélectionnant l'anglais
2. Naviguez dans l'app pour vérifier les traductions
3. Changez la langue dans les paramètres
4. Vérifiez que toute l'interface change de langue

## 🎨 Bonnes pratiques

1. **Toujours utiliser des clés de traduction** plutôt que du texte en dur
2. **Nommer les clés de manière descriptive** : `company_name` plutôt que `cn`
3. **Grouper les clés par contexte** : `stock_`, `event_`, `task_`, etc.
4. **Tester dans les deux langues** avant de valider
5. **Garder les traductions cohérentes** entre les vues similaires

## 🚀 Prochaines étapes

1. Traduire toutes les vues principales
2. Ajouter d'autres langues (Espagnol, Allemand, etc.)
3. Traduire les messages d'erreur
4. Traduire les notifications push
5. Implémenter la détection automatique de la langue du système

---

**Note importante** : Le système est conçu pour être extensible. Pour ajouter une nouvelle langue, il suffit de :
1. Ajouter un nouveau cas dans `AppLanguage` enum
2. Créer un nouveau dictionnaire de traductions
3. Mettre à jour la fonction `translate()` dans `Translations`

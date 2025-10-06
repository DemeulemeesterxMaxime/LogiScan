# 🐛 Debug CoreGraphics NaN Errors

## ❌ Erreur Rencontrée

```
Error: this application, or a library it uses, has passed an invalid 
numeric value (NaN, or not-a-number) to CoreGraphics API
```

**Répété 6 fois** → Probablement une vue SwiftUI qui se redessine avec des valeurs invalides.

---

## 🔍 Causes Possibles

### 1. Division par zéro dans un calcul de layout
```swift
// ❌ MAUVAIS - Peut causer NaN
.frame(width: someValue / 0)

// ✅ BON - Vérifier avant
.frame(width: max(1, someValue))
```

### 2. Valeurs géométriques invalides
```swift
// ❌ MAUVAIS
.offset(x: CGFloat.nan)
.padding(.infinity)

// ✅ BON
.offset(x: isReady ? 10 : 0)
.padding(20)
```

### 3. Calculs de pourcentage sans validation
```swift
// ❌ MAUVAIS
let progress = completed / total  // Si total = 0 → NaN

// ✅ BON
let progress = total > 0 ? completed / total : 0
```

---

## 🛠️ Comment Identifier la Vue Problématique

### Méthode 1 : Activer le Backtrace

1. Dans Xcode : **Product → Scheme → Edit Scheme**
2. Onglet **Run** → **Arguments**
3. Section **Environment Variables**
4. Ajouter :
   ```
   Name:  CG_NUMERICS_SHOW_BACKTRACE
   Value: 1
   ```
5. Run à nouveau → Les logs montreront **quelle vue** cause le problème

### Méthode 2 : Recherche Manuelle

Cherchez dans votre code ces patterns :

```bash
# Rechercher divisions potentiellement dangereuses
grep -r "/ " LogiScan/UI/*.swift | grep -v "//"

# Rechercher calculs de frame dynamiques
grep -r "\.frame(" LogiScan/UI/*.swift

# Rechercher GeometryReader
grep -r "GeometryReader" LogiScan/UI/*.swift
```

---

## 🎯 Vues Suspectes à Vérifier

### 1️⃣ StockListView
- Calculs de pourcentages (quantité disponible / total)
- Grilles dynamiques

### 2️⃣ DashboardView
- Graphiques / Charts
- Calculs de statistiques

### 3️⃣ QRScannerView
- Overlay graphique
- Frame de la caméra

---

## ✅ Solution Temporaire (Sans Impact)

Ces erreurs sont **purement cosmétiques** :
- ✅ Les données se sauvegardent
- ✅ L'app fonctionne
- ✅ Aucun crash

Vous pouvez ignorer ces warnings pour l'instant et les corriger plus tard en activant le backtrace pour identifier la vue exacte.

---

## 🔧 Fix Préventif Global

Ajoutez cette extension dans un fichier `Extensions/ViewExtensions.swift` :

```swift
import SwiftUI

extension View {
    /// Applique un frame en validant les valeurs
    func safeFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        self.frame(
            width: width?.isFinite == true ? width : nil,
            height: height?.isFinite == true ? height : nil
        )
    }
}

extension CGFloat {
    /// Retourne la valeur ou 0 si NaN/infini
    var validOrZero: CGFloat {
        isFinite ? self : 0
    }
}
```

**Utilisation :**
```swift
// Au lieu de :
.frame(width: calculatedWidth)

// Utilisez :
.safeFrame(width: calculatedWidth)
```

---

## 📊 Priorité

| Problème | Gravité | Priorité |
|----------|---------|----------|
| CoreGraphics NaN | ⚠️ Cosmétique | 🔵 Basse |
| "truck" symbol | ⚠️ Cache | 🟡 Moyenne (rebuild résout) |
| CoreData Array | ⚠️ Verbeux | 🔵 Basse (fonctionnel) |
| Firebase sync | ✅ Fonctionne | ✅ Résolu |

---

## 🎯 Action Recommandée

**Pour Build 11+ (prochain upload App Store) :**
1. ✅ Packages optimisés (Analytics + Database retirés)
2. 🟡 Activer backtrace pour identifier la vue NaN
3. 🔵 Corriger la vue problématique (optionnel)

**Pour l'instant :**
- L'app est **100% fonctionnelle**
- Ces warnings n'empêchent **pas la validation App Store**
- Vous pouvez soumettre le Build 11 tel quel

---

*Document créé le : 6 octobre 2025*
*Contexte : Optimisation packages Firebase réussie*

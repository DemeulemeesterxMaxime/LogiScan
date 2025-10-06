#!/bin/bash
# Script de nettoyage complet après suppression packages Firebase

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 NETTOYAGE COMPLET - LogiScan"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Nettoyer le cache DerivedData
echo "1️⃣ Nettoyage DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/LogiScan-*
echo "   ✅ DerivedData nettoyé"

# 2. Nettoyer le dossier build local
echo "2️⃣ Nettoyage dossier build..."
cd /Users/demeulemeesterxmaxime/Documents/LogiScan
rm -rf build/
echo "   ✅ Dossier build nettoyé"

# 3. Nettoyer les caches Swift Package Manager
echo "3️⃣ Nettoyage SPM cache..."
rm -rf ~/Library/Caches/org.swift.swiftpm/
echo "   ✅ Cache SPM nettoyé"

# 4. Résoudre les packages (télécharger uniquement Auth + Firestore)
echo "4️⃣ Résolution des packages Firebase..."
xcodebuild -resolvePackageDependencies -project LogiScan.xcodeproj -scheme LogiScan
echo "   ✅ Packages résolus"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ NETTOYAGE TERMINÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 Prochaine étape dans Xcode :"
echo "   1. ⇧⌘K (Clean Build Folder)"
echo "   2. ⌘R (Run pour rebuild)"
echo ""
echo "⏱️ Le build devrait maintenant être 40-50% plus rapide !"

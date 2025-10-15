# 🚀 Roadmap LogiScan - Prochaines Étapes

**Date**: 14 octobre 2025  
**Version**: 1.0 (Post-correction crash SwiftData)

---

## ✅ CORRECTIFS CRITIQUES APPLIQUÉS

### 1. Crash SwiftData lors de la sauvegarde du panier ✅
**Problème**: L'app crashait avec `SwiftData._KKMDBackingData.getValue<A>(forKey:)` lors de :
- Enregistrement du panier
- Finalisation du devis

**Cause**: 
- Utilisation directe des objets `@Query` dans le State
- Suppression d'objets SwiftData puis réinsertion des mêmes instances
- SwiftData tentait d'accéder à des propriétés d'objets déjà marqués pour suppression

**Solution appliquée**:
```swift
// ❌ AVANT (crash)
quoteItems = existingItems // Référence directe @Query

// ✅ APRÈS (stable)
quoteItems = existingItems.map { item in
    // Créer une COPIE propre
    let newItem = QuoteItem(...)
    return newItem
}
```

**Fichiers modifiés**:
- ✅ `EventService.swift` - Ligne 38-80 (fonction `saveLocally`)
- ✅ `QuoteBuilderView.swift` - Ligne 985-1020 (fonction `loadExistingQuoteItems`)

---

## 🎯 ÉTAPES PRIORITAIRES

### P0 - VALIDATION TESTFLIGHT (Immédiat)
**Objectif**: Valider les corrections sur TestFlight avant d'ajouter de nouvelles fonctionnalités

#### Tests à effectuer :
1. **Test synchronisation multi-appareils** ⏳
   - [ ] Appareil A : Créer un événement
   - [ ] Appareil A : Ajouter 5 articles au devis
   - [ ] Appareil A : Enregistrer le panier
   - [ ] Appareil A : Vérifier que l'app ne crash pas
   - [ ] Appareil B : Ouvrir l'événement
   - [ ] Appareil B : Vérifier que les 5 articles apparaissent
   - [ ] Appareil B : Modifier les quantités
   - [ ] Appareil B : Enregistrer
   - [ ] Appareil A : Rafraîchir et vérifier la mise à jour

2. **Test navigation +/- quantité** ⏳
   - [ ] Ouvrir un devis
   - [ ] Cliquer 10x sur + d'un article
   - [ ] Vérifier : Pas de retour en arrière intempestif
   - [ ] Cliquer 5x sur - du même article
   - [ ] Vérifier : La navigation reste stable

3. **Test finalisation devis** ⏳
   - [ ] Créer un devis avec 3 articles
   - [ ] Appliquer une remise de 10%
   - [ ] Cliquer "Terminer le devis"
   - [ ] Vérifier : Pas de crash
   - [ ] Vérifier : Statut passe à "Finalisé"
   - [ ] Vérifier : Le devis est readonly

**Logs attendus** (console Xcode lors des tests):
```
✅ [EventService] Sauvegarde locale réussie
✅ [EventService] Événement sauvegardé avec succès
📥 [SyncManager] X items récupérés pour événement
```

**Si un test échoue**: 
- Copier les logs console complets
- Noter les étapes exactes pour reproduire
- Ne PAS passer à P1 avant résolution

---

### P1 - LOGIQUE DE DISPONIBILITÉ INTELLIGENTE (4-6h)
**Objectif**: Empêcher la sur-réservation d'assets et afficher la disponibilité réelle

#### Contexte actuel :
```swift
// ❌ DEPRECATED - Ne fonctionne pas
item.availableQuantity // Toujours égal à totalQuantity

// ✅ À UTILISER - Logique intelligente existante
StockItem.calculateQuantities(from: assets, for: event)
// Retourne: (available: Int, reserved: Int, total: Int)
```

#### Étapes d'implémentation :

**1. Créer le service de disponibilité** (1h)
```swift
// Fichier : LogiScan/Domain/Services/AvailabilityService.swift

@MainActor
final class AvailabilityService: ObservableObject {
    
    /// Calcule la disponibilité d'un article pour un événement
    func checkAvailability(
        for stockItem: StockItem,
        event: Event,
        requestedQuantity: Int,
        allAssets: [Asset],
        allReservations: [AssetReservation]
    ) -> AvailabilityResult {
        
        // 1. Filtrer les assets de cet article
        let itemAssets = allAssets.filter { $0.sku == stockItem.sku }
        
        // 2. Calculer les quantités
        let quantities = stockItem.calculateQuantities(
            from: itemAssets,
            for: event
        )
        
        // 3. Vérifier les conflits de date
        let conflicts = findConflictingReservations(
            assets: itemAssets,
            eventDates: (event.startDate, event.endDate),
            reservations: allReservations
        )
        
        // 4. Calculer disponibilité réelle
        let realAvailable = quantities.available - conflicts.count
        
        return AvailabilityResult(
            requestedQuantity: requestedQuantity,
            availableQuantity: realAvailable,
            totalQuantity: quantities.total,
            reservedQuantity: quantities.reserved,
            conflicts: conflicts,
            canFulfill: requestedQuantity <= realAvailable
        )
    }
    
    private func findConflictingReservations(...) -> [AssetReservation] {
        // Logique de détection de chevauchement de dates
    }
}

struct AvailabilityResult {
    let requestedQuantity: Int
    let availableQuantity: Int
    let totalQuantity: Int
    let reservedQuantity: Int
    let conflicts: [AssetReservation]
    let canFulfill: Bool
    
    var warning: String? {
        if !canFulfill {
            return "Stock insuffisant : \(availableQuantity)/\(requestedQuantity) disponible"
        }
        if conflicts.count > 0 {
            return "Attention : \(conflicts.count) asset(s) déjà réservé(s)"
        }
        return nil
    }
}
```

**2. Intégrer dans QuoteBuilderView** (1-2h)
```swift
// Ajouter dans QuoteBuilderView
@StateObject private var availabilityService = AvailabilityService()
@State private var availabilityWarnings: [String: String] = [:] // sku -> message

// Modifier addItemToCart
private func addItemToCart(_ stockItem: StockItem) {
    // Vérifier disponibilité AVANT d'ajouter
    let result = availabilityService.checkAvailability(
        for: stockItem,
        event: event,
        requestedQuantity: quantities[stockItem.sku, default: 0] + 1,
        allAssets: allAssets, // Ajouter @Query var allAssets: [Asset]
        allReservations: allReservations // Ajouter @Query var allReservations: [AssetReservation]
    )
    
    if !result.canFulfill {
        // Afficher alerte
        availabilityWarnings[stockItem.sku] = result.warning
        return // Ne pas ajouter
    }
    
    // Ajouter normalement
    if let existingIndex = quoteItems.firstIndex(where: { $0.sku == stockItem.sku }) {
        quoteItems[existingIndex].updateQuantity(quoteItems[existingIndex].quantity + 1)
    } else {
        let quoteItem = QuoteItem(...)
        quoteItems.append(quoteItem)
    }
    
    // Effacer le warning si résolu
    availabilityWarnings.removeValue(forKey: stockItem.sku)
}
```

**3. Afficher les warnings dans l'UI** (1h)
```swift
// Dans StockItemCard, ajouter :
if let warning = availabilityWarnings[item.sku] {
    HStack {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
        Text(warning)
            .font(.caption)
            .foregroundColor(.orange)
    }
    .padding(.vertical, 4)
}
```

**4. Badge de disponibilité dans la liste** (30min)
```swift
// Dans StockItemCard, afficher :
HStack {
    Text(item.name)
    Spacer()
    
    let result = availabilityService.checkAvailability(...)
    
    if result.availableQuantity == 0 {
        Text("Épuisé")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.2))
            .foregroundColor(.red)
            .cornerRadius(8)
    } else if result.availableQuantity < 5 {
        Text("\(result.availableQuantity) dispo")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.2))
            .foregroundColor(.orange)
            .cornerRadius(8)
    }
}
```

**Tests à effectuer** :
- [ ] Créer un événement A avec 5 chaises réservées
- [ ] Créer un événement B aux mêmes dates
- [ ] Vérifier : Lors de l'ajout de chaises dans B, warning "Stock insuffisant"
- [ ] Modifier les dates de B (pas de chevauchement)
- [ ] Vérifier : Warning disparaît, chaises disponibles

---

### P2 - CRÉATION AUTOMATIQUE DE RÉSERVATIONS (2-3h)
**Objectif**: Bloquer automatiquement les assets assignés lors de l'ajout au devis

#### Contexte :
Actuellement, lorsqu'un article est ajouté au devis, aucun asset spécifique n'est réservé. Il faut :
1. Sélectionner les meilleurs assets disponibles
2. Créer une `AssetReservation` pour chaque asset
3. Ajouter les `assetIds` dans `QuoteItem.assignedAssets`

#### Étapes d'implémentation :

**1. Créer le service de réservation** (1h)
```swift
// Fichier : LogiScan/Domain/Services/ReservationService.swift

@MainActor
final class ReservationService: ObservableObject {
    
    /// Sélectionne et réserve les meilleurs assets pour un item
    func reserveAssets(
        for quoteItem: QuoteItem,
        stockItem: StockItem,
        event: Event,
        allAssets: [Asset],
        existingReservations: [AssetReservation],
        modelContext: ModelContext
    ) async throws -> [String] {
        
        // 1. Filtrer les assets disponibles
        let itemAssets = allAssets.filter { $0.sku == stockItem.sku }
        let availableAssets = itemAssets.filter { asset in
            !hasConflictingReservation(
                asset: asset,
                eventDates: (event.startDate, event.endDate),
                reservations: existingReservations
            )
        }
        
        guard availableAssets.count >= quoteItem.quantity else {
            throw ReservationError.insufficientStock
        }
        
        // 2. Sélectionner les meilleurs assets
        let selectedAssets = selectBestAssets(
            from: availableAssets,
            quantity: quoteItem.quantity
        )
        
        // 3. Créer les réservations
        var assignedIds: [String] = []
        for asset in selectedAssets {
            let reservation = AssetReservation(
                reservationId: UUID().uuidString,
                assetId: asset.assetId,
                eventId: event.eventId,
                startDate: event.startDate,
                endDate: event.endDate,
                status: .pending
            )
            modelContext.insert(reservation)
            assignedIds.append(asset.assetId)
            
            print("🔒 Asset réservé: \(asset.assetId) pour événement \(event.name)")
        }
        
        try modelContext.save()
        return assignedIds
    }
    
    private func selectBestAssets(from assets: [Asset], quantity: Int) -> [Asset] {
        // Critères de sélection:
        // 1. Assets en bon état d'abord
        // 2. Assets les plus récents
        // 3. Assets avec moins d'utilisation
        return assets
            .sorted { asset1, asset2 in
                // Logique de tri
                if asset1.condition != asset2.condition {
                    return asset1.condition == .good
                }
                return asset1.purchaseDate > asset2.purchaseDate
            }
            .prefix(quantity)
            .map { $0 }
    }
    
    private func hasConflictingReservation(...) -> Bool {
        // Vérifier chevauchement de dates
    }
}

enum ReservationError: Error {
    case insufficientStock
    case reservationFailed
}
```

**2. Intégrer dans addItemToCart** (30min)
```swift
// Dans QuoteBuilderView
@StateObject private var reservationService = ReservationService()

private func addItemToCart(_ stockItem: StockItem) {
    // ... code existant de vérification disponibilité ...
    
    // Créer le QuoteItem
    let quoteItem = QuoteItem(...)
    
    // Réserver automatiquement les assets
    Task {
        do {
            let assignedIds = try await reservationService.reserveAssets(
                for: quoteItem,
                stockItem: stockItem,
                event: event,
                allAssets: allAssets,
                existingReservations: allReservations,
                modelContext: modelContext
            )
            
            // Mettre à jour le QuoteItem avec les assets assignés
            await MainActor.run {
                quoteItem.assignedAssets = assignedIds
                print("✅ \(assignedIds.count) assets assignés à \(stockItem.name)")
            }
        } catch {
            print("❌ Erreur réservation: \(error)")
            // Afficher alerte
        }
    }
    
    quoteItems.append(quoteItem)
}
```

**3. Libérer les réservations lors de la suppression** (30min)
```swift
private func removeItemFromCart(_ stockItem: StockItem) {
    if let existingIndex = quoteItems.firstIndex(where: { $0.sku == stockItem.sku }) {
        let item = quoteItems[existingIndex]
        
        // Libérer les réservations si on supprime complètement
        if item.quantity <= 1 {
            Task {
                await releaseReservations(for: item)
            }
            quoteItems.remove(at: existingIndex)
        } else {
            // Diminuer quantité = libérer 1 asset
            let currentQuantity = item.quantity
            item.updateQuantity(currentQuantity - 1)
            
            Task {
                await releaseOneAsset(for: item)
            }
        }
    }
}

private func releaseReservations(for item: QuoteItem) async {
    for assetId in item.assignedAssets {
        if let reservation = allReservations.first(where: {
            $0.assetId == assetId && $0.eventId == event.eventId
        }) {
            modelContext.delete(reservation)
            print("🔓 Réservation libérée: \(assetId)")
        }
    }
    try? modelContext.save()
}
```

**Tests à effectuer** :
- [ ] Ajouter 5 chaises au devis
- [ ] Vérifier logs : "🔒 Asset réservé: xxx"
- [ ] Aller dans la vue Assets
- [ ] Vérifier : 5 chaises ont le badge "Réservé"
- [ ] Retourner au devis, supprimer 2 chaises
- [ ] Vérifier logs : "🔓 Réservation libérée"
- [ ] Vérifier : 3 chaises restent réservées, 2 sont libérées

---

### P3 - SCANNER CONTEXTUEL LIÉ À L'ÉVÉNEMENT (3-4h)
**Objectif**: Créer une liste de scan liée au devis finalisé pour faciliter la préparation

#### Fonctionnalités :

**1. Génération automatique de la liste de scan** (1h)
```swift
// Fichier : LogiScan/Domain/Models/ScanList.swift

@Model
final class ScanList {
    var scanListId: String
    var eventId: String
    var eventName: String
    var totalItemsCount: Int
    var scannedItemsCount: Int
    var createdAt: Date
    var completedAt: Date?
    var status: ScanListStatus
    
    // Relations
    var items: [ScanListItem] = []
    
    init(eventId: String, eventName: String) {
        self.scanListId = UUID().uuidString
        self.eventId = eventId
        self.eventName = eventName
        self.totalItemsCount = 0
        self.scannedItemsCount = 0
        self.createdAt = Date()
        self.status = .pending
    }
}

@Model
final class ScanListItem {
    var itemId: String
    var scanListId: String
    var sku: String
    var name: String
    var category: String
    var requiredQuantity: Int
    var scannedQuantity: Int
    var scannedAssetIds: [String] = []
    var lastScannedAt: Date?
    
    var isComplete: Bool {
        scannedQuantity >= requiredQuantity
    }
    
    var progress: Double {
        Double(scannedQuantity) / Double(requiredQuantity)
    }
}

enum ScanListStatus: String, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
}
```

**2. Créer la liste lors de la finalisation** (30min)
```swift
// Dans QuoteBuilderView, modifier generateInvoice()
private func generateInvoice() {
    Task {
        // Finaliser le devis
        await saveQuote(finalize: true)
        
        // Créer la liste de scan
        await createScanList()
        
        // TODO: Naviguer vers InvoicePreviewView
    }
}

private func createScanList() async {
    let scanList = ScanList(eventId: event.eventId, eventName: event.name)
    
    // Créer un ScanListItem pour chaque article du devis
    for quoteItem in quoteItems {
        let scanItem = ScanListItem(
            itemId: UUID().uuidString,
            scanListId: scanList.scanListId,
            sku: quoteItem.sku,
            name: quoteItem.name,
            category: quoteItem.category,
            requiredQuantity: quoteItem.quantity,
            scannedQuantity: 0
        )
        scanList.items.append(scanItem)
        modelContext.insert(scanItem)
    }
    
    scanList.totalItemsCount = scanList.items.reduce(0) { $0 + $1.requiredQuantity }
    modelContext.insert(scanList)
    try? modelContext.save()
    
    print("📋 Liste de scan créée: \(scanList.totalItemsCount) assets à scanner")
}
```

**3. Interface de scan contextuel** (2h)
```swift
// Fichier : LogiScan/UI/Scanner/ScanListView.swift

struct ScanListView: View {
    @Query var scanLists: [ScanList]
    @State private var selectedList: ScanList?
    @State private var showingScanner = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(activeScanLists) { list in
                    ScanListRow(list: list)
                        .onTapGesture {
                            selectedList = list
                            showingScanner = true
                        }
                }
            }
            .navigationTitle("Listes de scan")
            .sheet(isPresented: $showingScanner) {
                if let list = selectedList {
                    ContextualScannerView(scanList: list)
                }
            }
        }
    }
    
    private var activeScanLists: [ScanList] {
        scanLists.filter { $0.status != .completed }
    }
}

struct ScanListRow: View {
    let list: ScanList
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(list.eventName)
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(status: list.status)
            }
            
            // Barre de progression
            ProgressView(value: progress) {
                HStack {
                    Text("\(list.scannedItemsCount)/\(list.totalItemsCount) assets")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            
            // Articles par catégorie
            FlowLayout(spacing: 8) {
                ForEach(list.items.groupedByCategory()) { group in
                    CategoryProgressChip(
                        category: group.category,
                        completed: group.completedCount,
                        total: group.totalCount
                    )
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var progress: Double {
        Double(list.scannedItemsCount) / Double(list.totalItemsCount)
    }
}

struct ContextualScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let scanList: ScanList
    
    @State private var scannedCode: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scanner QR
                QRScannerView(scannedCode: $scannedCode)
                    .frame(height: 300)
                
                // Liste des articles avec progression
                List {
                    ForEach(scanList.items) { item in
                        ScanItemRow(item: item)
                    }
                }
            }
            .navigationTitle("Scan - \(scanList.eventName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminer") {
                        dismiss()
                    }
                }
            }
            .onChange(of: scannedCode) { oldValue, newValue in
                if let code = newValue {
                    handleScannedCode(code)
                }
            }
        }
    }
    
    private func handleScannedCode(_ code: String) {
        // Retrouver l'asset scanné
        let descriptor = FetchDescriptor<Asset>(
            predicate: #Predicate<Asset> { $0.qrCode == code }
        )
        
        guard let asset = try? modelContext.fetch(descriptor).first else {
            print("❌ Asset non trouvé: \(code)")
            return
        }
        
        // Trouver le ScanListItem correspondant
        guard let item = scanList.items.first(where: { $0.sku == asset.sku }) else {
            print("⚠️ Cet asset n'est pas dans la liste de scan")
            return
        }
        
        // Vérifier si déjà scanné
        if item.scannedAssetIds.contains(asset.assetId) {
            print("⚠️ Asset déjà scanné")
            return
        }
        
        // Marquer comme scanné
        item.scannedAssetIds.append(asset.assetId)
        item.scannedQuantity += 1
        item.lastScannedAt = Date()
        
        scanList.scannedItemsCount += 1
        
        // Vérifier si liste complète
        if scanList.scannedItemsCount >= scanList.totalItemsCount {
            scanList.status = .completed
            scanList.completedAt = Date()
            print("🎉 Liste de scan terminée!")
        } else {
            scanList.status = .inProgress
        }
        
        try? modelContext.save()
        
        print("✅ Asset scanné: \(asset.assetId) - Progression: \(item.scannedQuantity)/\(item.requiredQuantity)")
        
        // Réinitialiser pour prochain scan
        scannedCode = nil
    }
}

struct ScanItemRow: View {
    let item: ScanListItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if item.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                Text("\(item.scannedQuantity)/\(item.requiredQuantity)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(item.isComplete ? .green : .orange)
            }
        }
    }
}
```

**4. Ajouter dans MainTabView** (15min)
```swift
// Modifier ScannerMainView pour inclure ScanListView
TabView(selection: $selectedTab) {
    ScanListView()
        .tabItem {
            Label("Listes", systemImage: "list.clipboard")
        }
        .tag(0)
    
    SimpleScannerView(...)
        .tabItem {
            Label("Scanner", systemImage: "qrcode.viewfinder")
        }
        .tag(1)
    
    // ... autres tabs
}
```

**Tests à effectuer** :
- [ ] Créer un devis avec 10 articles
- [ ] Finaliser le devis
- [ ] Aller dans Scanner > Listes
- [ ] Vérifier : Une liste de scan est créée
- [ ] Ouvrir la liste
- [ ] Scanner 5 QR codes valides
- [ ] Vérifier : Progression 5/10 affichée
- [ ] Vérifier : Assets marqués comme scannés
- [ ] Scanner les 5 restants
- [ ] Vérifier : Badge "Complété" apparaît

---

### P4 - GÉNÉRATION PDF FACTURE (2-3h)
**Objectif**: Générer une facture PDF professionnelle à partir du devis finalisé

#### Étapes :

**1. Installer dépendance PDFKit** (déjà disponible dans iOS)

**2. Créer le service de génération PDF** (2h)
```swift
// Fichier : LogiScan/Domain/Services/InvoiceService.swift

import PDFKit
import UIKit

@MainActor
final class InvoiceService: ObservableObject {
    
    func generateInvoicePDF(
        event: Event,
        quoteItems: [QuoteItem],
        companyInfo: CompanyInfo
    ) async throws -> URL {
        
        // 1. Créer le PDF
        let pdfMetaData = [
            kCGPDFContextCreator: "LogiScan",
            kCGPDFContextTitle: "Facture - \(event.name)"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 50
            
            // En-tête entreprise
            yPosition = drawCompanyHeader(context: context, info: companyInfo, yPosition: yPosition)
            yPosition += 20
            
            // Informations événement
            yPosition = drawEventInfo(context: context, event: event, yPosition: yPosition)
            yPosition += 30
            
            // Table des articles
            yPosition = drawItemsTable(context: context, items: quoteItems, yPosition: yPosition)
            yPosition += 20
            
            // Totaux
            yPosition = drawTotals(context: context, event: event, items: quoteItems, yPosition: yPosition)
            yPosition += 40
            
            // Pied de page
            drawFooter(context: context, pageRect: pageRect)
        }
        
        // 2. Sauvegarder le PDF
        let fileName = "Facture-\(event.name.replacingOccurrences(of: " ", with: "-"))-\(Date().timeIntervalSince1970).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
        
        print("✅ Facture PDF générée: \(url.lastPathComponent)")
        return url
    }
    
    private func drawCompanyHeader(...) -> CGFloat { ... }
    private func drawEventInfo(...) -> CGFloat { ... }
    private func drawItemsTable(...) -> CGFloat { ... }
    private func drawTotals(...) -> CGFloat { ... }
    private func drawFooter(...) { ... }
}

struct CompanyInfo {
    let name: String
    let address: String
    let phone: String
    let email: String
    let siret: String?
    let tva: String?
}
```

**3. Interface de prévisualisation et partage** (1h)
```swift
// Fichier : LogiScan/UI/Events/InvoicePreviewView.swift

struct InvoicePreviewView: View {
    let pdfURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            PDFKitView(url: pdfURL)
                .navigationTitle("Facture")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Fermer") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    ShareSheet(items: [pdfURL])
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {}
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

**Tests à effectuer** :
- [ ] Finaliser un devis
- [ ] Cliquer "Générer la facture"
- [ ] Vérifier : PDF s'affiche correctement
- [ ] Vérifier : Toutes les infos sont présentes (articles, quantités, prix, totaux)
- [ ] Cliquer bouton partage
- [ ] Vérifier : Options de partage (Mail, AirDrop, etc.)
- [ ] Envoyer par email
- [ ] Vérifier : PDF reçu et lisible

---

## 📊 ESTIMATION TEMPS TOTAL

| Priorité | Tâche | Estimation | Criticité |
|----------|-------|------------|-----------|
| P0 | Tests TestFlight | 1-2h | 🔴 BLOQUANT |
| P1 | Logique disponibilité | 4-6h | 🟠 IMPORTANT |
| P2 | Création réservations | 2-3h | 🟠 IMPORTANT |
| P3 | Scanner contextuel | 3-4h | 🟡 AMÉLIORATION |
| P4 | Génération PDF | 2-3h | 🟡 AMÉLIORATION |
| **TOTAL** | | **12-18h** | |

---

## ✅ CHECKLIST DE VALIDATION

### Avant de passer à la prochaine étape :

- [ ] **P0 validé** : Tous les tests TestFlight passent
- [ ] **Logs propres** : Aucune erreur dans la console
- [ ] **Pas de crash** : L'app est stable sur tous les flux
- [ ] **Sync fonctionnel** : Les données se synchronisent entre appareils

### Après chaque implémentation P1-P4 :

- [ ] Code compilé sans erreur
- [ ] Tests fonctionnels effectués
- [ ] Logs ajoutés pour debug
- [ ] Documentation mise à jour
- [ ] Commit Git avec message descriptif
- [ ] TestFlight mis à jour pour validation utilisateur

---

## 🚨 NOTES IMPORTANTES

### Architecture SwiftData
⚠️ **RÈGLE CRITIQUE** : Ne JAMAIS utiliser directement les objets `@Query` dans un State

```swift
// ❌ DANGER - Cause des crash
@State private var items: [QuoteItem] = []
items = allQuoteItems.filter { ... } // Référence directe

// ✅ CORRECT - Toujours créer des copies
items = allQuoteItems.filter { ... }.map { item in
    QuoteItem(
        quoteItemId: item.quoteItemId,
        // ... copier toutes les propriétés
    )
}
```

### Firebase + SwiftData
⚠️ **PATTERN À SUIVRE** :
1. Toujours sauvegarder en local AVANT Firebase
2. Utiliser EventService pour toute modification Event + QuoteItems
3. Ne jamais manipuler directement modelContext.delete() puis modelContext.insert()
4. Créer des copies propres avant toute manipulation

### Gestion des assets
⚠️ **DEPRECATED** :
- `item.availableQuantity` → Ne pas utiliser
- Calculs manuels de disponibilité → Ne pas faire

⚠️ **À UTILISER** :
- `StockItem.calculateQuantities(from: assets, for: event)`
- AvailabilityService (à créer en P1)

---

## 📝 SUIVI DE PROGRESSION

### Session du 14 octobre 2025

- [x] Crash SwiftData corrigé (EventService + QuoteBuilderView)
- [x] Build réussi
- [ ] Tests TestFlight (en attente déploiement)
- [ ] Logique disponibilité (planifié P1)
- [ ] Création réservations (planifié P2)
- [ ] Scanner contextuel (planifié P3)
- [ ] Génération PDF (planifié P4)

---

**Prochaine étape** : Valider P0 sur TestFlight puis implémenter P1 (Logique disponibilité)

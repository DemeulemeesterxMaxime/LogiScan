//
//  QuoteBuilderView.swift
//  LogiScan
//
//  Created by Demeulemeester on 08/10/2025.
//

import SwiftData
import SwiftUI

enum DiscountMode {
    case percentage
    case euros
}

struct QuoteBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var stockItems: [StockItem]
    @Query private var trucks: [Truck]
    @Query private var allQuoteItems: [QuoteItem]
    @Query private var allAssets: [Asset]
    @Query private var allReservations: [AssetReservation]
    @Query private var allScanLists: [ScanList]
    @Query private var users: [User]
    
    @StateObject private var firebaseService = FirebaseService()
    @StateObject private var syncManager = SyncManager()
    @StateObject private var eventService = EventService()
    @StateObject private var availabilityService = AvailabilityService()
    @StateObject private var reservationService = ReservationService()
    @StateObject private var scanListService = ScanListService()
    @StateObject private var versionService = QuoteVersionService()

    let event: Event

    // State local pour les modifications en cours (performance)
    @State private var quoteItems: [QuoteItem] = []
    
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showingScanner = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var globalDiscount: Double = 0.0
    @State private var globalDiscountEuros: Double = 0.0
    @State private var discountMode: DiscountMode = .percentage
    @State private var showingCartSummary = false  // Initialisé à false pour ne pas ouvrir automatiquement
    @State private var showingCategoryFilter = false  // Pour le sheet de filtres
    @State private var showingCartDetail = false  // Pour naviguer vers CartDetailView
    @State private var quantities: [String: Int] = [:]  // SKU -> Quantity in cart
    @State private var availabilityWarnings: [String: String] = [:]  // SKU -> Warning message
    @State private var availabilityResults: [String: AvailabilityResult] = [:]  // SKU -> Result
    @State private var hasLoadedInitialData = false  // Flag pour charger une seule fois
    @State private var autoSaveTask: Task<Void, Never>?  // Pour le debounce de la sauvegarde auto
    @State private var isSaving = false  // Indicateur de sauvegarde en cours
    @State private var generatedScanList: ScanList? = nil  // Liste de scan générée
    @State private var showingScanList = false  // Afficher la liste de scan

    private var assignedTruck: Truck? {
        guard let truckId = event.assignedTruckId else { return nil }
        return trucks.first { $0.truckId == truckId }
    }

    private var filteredStockItems: [StockItem] {
        var items = stockItems

        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText)
                    || item.sku.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    private var categories: [String] {
        Array(Set(stockItems.map { $0.category })).sorted()
    }

    private var subtotal: Double {
        quoteItems.reduce(0) { $0 + $1.totalPrice }
    }

    private var totalWeight: Double {
        quoteItems.reduce(0) { total, item in
            if let stockItem = stockItems.first(where: { $0.sku == item.sku }) {
                return total + (stockItem.unitWeight * Double(item.quantity))
            }
            return total
        }
    }

    private var totalVolume: Double {
        quoteItems.reduce(0) { total, item in
            if let stockItem = stockItems.first(where: { $0.sku == item.sku }) {
                return total + (stockItem.unitVolume * Double(item.quantity))
            }
            return total
        }
    }

    private var discountAmount: Double {
        switch discountMode {
        case .percentage:
            return subtotal * (globalDiscount / 100)
        case .euros:
            return globalDiscountEuros
        }
    }
    
    private var discountPercentage: Double {
        guard subtotal > 0 else { return 0 }
        return (discountAmount / subtotal) * 100
    }

    private var finalTotal: Double {
        max(0, subtotal - discountAmount)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header avec infos événement
                headerView
                
                // Zone de recherche et filtres
                searchAndFilterSection
                
                // Liste des articles disponibles (style catalogue)
                stockItemsCatalog
            }
            
            // Panier flottant en bas (seulement si non vide)
            if !quoteItems.isEmpty {
                floatingCartButton
                    .animation(.easeInOut(duration: 0.3), value: quoteItems.count)
            }
        }
        .navigationTitle("Sélection articles")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Annuler") {
                    print("🔴 BOUTON ANNULER CLIQUÉ - dismiss() appelé")
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if quoteItems.isEmpty {
                        alertMessage = "Le panier est vide. Ajoutez des articles avant d'enregistrer."
                        showAlert = true
                    } else {
                        // Bouton "Enregistrer" : sauvegarde ET fermer la vue
                        Task {
                            isSaving = true
                            await saveQuote(finalize: true)  // Finaliser et fermer
                            isSaving = false
                        }
                    }
                }) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Text("Enregistrer")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(quoteItems.isEmpty || isSaving)
            }
        }
        .sheet(isPresented: $showingScanner) {
            SimpleScannerView(onScanComplete: { result in
                handleScanResult(result)
            })
        }
        .sheet(isPresented: $showingCategoryFilter) {
            categoryFilterSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingCartSummary) {
            cartSummarySheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingScanList) {
            if let scanList = generatedScanList {
                NavigationStack {
                    EventScanListView(scanList: scanList)
                }
            }
        }
        .alert("Information", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // Charger UNE SEULE FOIS au premier affichage
            if !hasLoadedInitialData {
                hasLoadedInitialData = true
                
                // Charger immédiatement les données locales
                loadExistingQuoteItems()
                
                // Synchroniser en arrière-plan APRÈS le chargement initial (non bloquant)
                Task {
                    await syncManager.syncFromFirebaseIfNeeded(modelContext: modelContext, forceRefresh: true)
                }
            }
        }
        .onDisappear {
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                    Text(event.clientName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(event.startDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let truck = assignedTruck {
                        Label(truck.displayName, systemImage: "truck.box")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Barre de recherche avec boutons filtre et scan QR
            HStack(spacing: 8) {
                // Bouton filtre avec indicateur
                Button(action: { showingCategoryFilter = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundColor(selectedCategory != nil ? .blue : .secondary)
                            .font(.title3)
                        
                        if selectedCategory != nil {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .padding(.leading, 8)
                
                // Champ de recherche
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Rechercher un article...", text: $searchText)
                }
                .padding(.vertical, 10)
                
                // Bouton scan QR
                Button(action: { showingScanner = true }) {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .padding(.trailing, 8)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Stock Items Catalog
    
    private var stockItemsCatalog: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredStockItems) { item in
                    StockItemCard(
                        item: item,
                        quantityInCart: quantities[item.sku] ?? 0,
                        availabilityResult: availabilityResults[item.sku],
                        warning: availabilityWarnings[item.sku],
                        onAdd: {
                            // Utiliser DispatchQueue pour éviter les modifications d'état pendant le render
                            DispatchQueue.main.async {
                                addItemToCart(item)
                            }
                        },
                        onRemove: {
                            // Utiliser DispatchQueue pour éviter les modifications d'état pendant le render
                            DispatchQueue.main.async {
                                removeItemFromCart(item)
                            }
                        },
                        onQuantityChange: { newQuantity in
                            // Utiliser DispatchQueue pour éviter les modifications d'état pendant le render
                            DispatchQueue.main.async {
                                updateCartQuantity(item: item, quantity: newQuantity)
                            }
                        }
                    )
                }
                
                if filteredStockItems.isEmpty {
                    emptySearchState
                }
                
                // Espace en bas pour le bouton flottant
                Color.clear.frame(height: 80)
            }
            .padding()
        }
    }
    
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Aucun article trouvé")
                .font(.headline)
            Text("Essayez de modifier vos critères de recherche")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
    
    // MARK: - Floating Cart Button
    
    private var floatingCartButton: some View {
        Button(action: {
            withAnimation {
                showingCartSummary = true
            }
        }) {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(quoteItems.count) article(s)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(Int(finalTotal))€")
                        .font(.caption)
                }
                
                Spacer()
                
                Image(systemName: "chevron.up")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        }
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Category Filter Sheet
    
    private var categoryFilterSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    CategoryChip(
                        title: "Tous",
                        count: stockItems.count,
                        isSelected: selectedCategory == nil,
                        action: {
                            selectedCategory = nil
                            showingCategoryFilter = false
                        }
                    )
                    
                    ForEach(categories, id: \.self) { category in
                        let count = stockItems.filter { $0.category == category }.count
                        CategoryChip(
                            title: category,
                            count: count,
                            isSelected: selectedCategory == category,
                            action: {
                                selectedCategory = category
                                showingCategoryFilter = false
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Filtrer par catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        showingCategoryFilter = false
                    }
                }
            }
        }
    }
    
    // MARK: - Cart Summary Sheet
    
    private var cartSummarySheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Liste des articles dans le panier
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(quoteItems) { item in
                            CartItemRow(
                                item: item,
                                onQuantityChange: { newQuantity in
                                    if let stockItem = stockItems.first(where: { $0.sku == item.sku }) {
                                        updateCartQuantity(item: stockItem, quantity: newQuantity)
                                    }
                                },
                                onRemove: {
                                    if let stockItem = stockItems.first(where: { $0.sku == item.sku }) {
                                        removeAllFromCart(stockItem)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Récapitulatif des prix
                pricingSummary
                
                // Boutons d'action
                cartActionButtons
            }
            .navigationTitle("Mon panier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continuer") {
                        showingCartSummary = false
                    }
                }
            }
        }
    }
    
    private var pricingSummary: some View {
        VStack(spacing: 12) {
            // Sous-total
            HStack {
                Text("Sous-total")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(subtotal))€")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            // Remise globale
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Remise")
                    Spacer()
                    
                    // Sélecteur de mode
                    Picker("Mode", selection: $discountMode) {
                        Text("%").tag(DiscountMode.percentage)
                        Text("€").tag(DiscountMode.euros)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }
                
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        if discountMode == .percentage {
                            TextField("0", value: $globalDiscount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                            Text("%")
                                .foregroundColor(.secondary)
                        } else {
                            TextField("0", value: $globalDiscountEuros, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                            Text("€")
                                .foregroundColor(.secondary)
                        }
                        
                        // Affichage de la valeur calculée
                        Group {
                            if discountMode == .percentage {
                                Text("(-\(Int(discountAmount))€)")
                                    .foregroundColor(.red)
                            } else {
                                Text("(-\(String(format: "%.1f", discountPercentage))%)")
                                    .foregroundColor(.red)
                            }
                        }
                        .font(.caption)
                    }
                }
            }
            
            Divider()
            
            // Total
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text("\(Int(finalTotal))€")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            // Infos logistique
            HStack(spacing: 20) {
                Label("\(String(format: "%.1f", totalWeight)) kg", systemImage: "scalemass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("\(String(format: "%.1f", totalVolume)) m³", systemImage: "cube")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let truck = assignedTruck {
                    let weightPercent = (totalWeight / truck.maxWeight) * 100
                    let volumePercent = (totalVolume / truck.maxVolume) * 100
                    let maxPercent = max(weightPercent, volumePercent)
                    
                    if maxPercent > 100 {
                        Label("Dépassement!", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if maxPercent > 80 {
                        Label("\(Int(maxPercent))% capacité", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var cartActionButtons: some View {
        VStack(spacing: 12) {
            // Bouton principal : Terminer le devis
            Button(action: {
                Task {
                    isSaving = true
                    await saveQuote(finalize: true)
                    isSaving = false
                }
            }) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isSaving ? "Sauvegarde..." : "Terminer le devis")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSaving ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isSaving)
            
            // Bouton secondaire : Continuer les achats
            Button(action: {
                withAnimation {
                    showingCartSummary = false
                }
            }) {
                HStack {
                    Image(systemName: "cart.badge.plus")
                    Text("Continuer les achats")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }
            
            // Bouton danger : Vider le panier
            Button(action: {
                clearCart()
                // Ne PAS fermer la sheet automatiquement
                // L'utilisateur peut fermer manuellement ou continuer à ajouter
                print("🗑️ Panier vidé - Sheet reste ouverte")
            }) {
                Text("Vider le panier")
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
        }
        .padding()
    }

    // MARK: - Add Items Section

    private var addItemsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Barre de recherche
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Rechercher dans le stock...", text: $searchText)
                }
                .padding(8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)

                // Bouton scanner
                Button(action: { showingScanner = true }) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }

            // Filtres par catégorie
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "Tous",
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )

                    ForEach(categories, id: \.self) { category in
                        FilterChip(
                            title: category,
                            isSelected: selectedCategory == category,
                            action: { selectedCategory = category }
                        )
                    }
                }
            }

            // Liste des articles disponibles (collapsible)
            if !searchText.isEmpty || selectedCategory != nil {
                VStack(spacing: 8) {
                    ForEach(filteredStockItems.prefix(5)) { item in
                        StockItemQuickAddRow(item: item) {
                            addItemToQuote(item)
                        }
                    }

                    if filteredStockItems.count > 5 {
                        Text("\(filteredStockItems.count - 5) autre(s) article(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Quote Items List

    private var quoteItemsList: some View {
        VStack(spacing: 12) {
            Text("Articles du devis")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(quoteItems) { item in
                QuoteItemCard(
                    item: item,
                    onQuantityChange: { newQuantity in
                        updateQuantity(for: item, quantity: newQuantity)
                    },
                    onPriceChange: { newPrice in
                        updatePrice(for: item, price: newPrice)
                    },
                    onDelete: {
                        deleteItem(item)
                    }
                )
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: 16) {
            // Capacité camion
            if let truck = assignedTruck {
                VStack(spacing: 12) {
                    CapacityBar(
                        title: "Volume",
                        current: totalVolume,
                        max: truck.maxVolume,
                        unit: "m³"
                    )

                    CapacityBar(
                        title: "Poids",
                        current: totalWeight,
                        max: truck.maxWeight,
                        unit: "kg"
                    )
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

            // Récapitulatif financier
            VStack(spacing: 12) {
                HStack {
                    Text("Total articles:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(quoteItems.reduce(0) { $0 + $1.quantity })")
                }

                HStack {
                    Text("Poids total:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f kg", totalWeight))
                }

                HStack {
                    Text("Volume total:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f m³", totalVolume))
                }

                Divider()

                HStack {
                    Text("Sous-total:")
                    Spacer()
                    Text(String(format: "%.2f €", subtotal))
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Remise globale:")

                    Spacer()

                    HStack(spacing: 4) {
                        TextField("0", value: $globalDiscount, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 40)
                            .multilineTextAlignment(.trailing)

                        Text("%")
                    }

                    Text(String(format: "-%.2f €", discountAmount))
                        .foregroundColor(.orange)
                }

                Divider()

                HStack {
                    Text("TOTAL TTC:")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.2f €", finalTotal))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Aucun article dans le devis")
                .font(.headline)

            Text("Recherchez des articles ou scannez un QR code pour commencer")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: saveDraft) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Enregistrer")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(quoteItems.isEmpty)

            Button(action: generateInvoice) {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Générer la facture")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(quoteItems.isEmpty)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 4, y: -2)
    }

    // MARK: - Cart Actions
    
    private func addItemToCart(_ stockItem: StockItem) {
        print("🔵 DÉBUT addItemToCart - Article: \(stockItem.name)")
        print("🔵 QuoteItems avant: \(quoteItems.count)")
        
        // ÉTAPE 1: Vérifier la disponibilité AVANT d'ajouter
        let requestedQuantity = quantities[stockItem.sku, default: 0] + 1
        let availabilityResult = availabilityService.checkAvailability(
            for: stockItem,
            event: event,
            requestedQuantity: requestedQuantity,
            allAssets: allAssets,
            allReservations: allReservations
        )
        
        // Stocker le résultat pour l'UI
        availabilityResults[stockItem.sku] = availabilityResult
        
        // Si stock insuffisant, afficher l'alerte et arrêter
        if !availabilityResult.canFulfill {
            availabilityWarnings[stockItem.sku] = availabilityResult.warning
            alertMessage = availabilityResult.warning ?? "Stock insuffisant"
            showAlert = true
            print("❌ Stock insuffisant pour \(stockItem.name)")
            return
        }
        
        // Effacer les warnings précédents
        availabilityWarnings.removeValue(forKey: stockItem.sku)
        
        // ÉTAPE 2: Vérifier si l'item existe déjà dans le panier local
        if let existingIndex = quoteItems.firstIndex(where: { $0.sku == stockItem.sku }) {
            print("🔵 Article existant trouvé à l'index \(existingIndex)")
            let existingItem = quoteItems[existingIndex]
            
            // Augmenter la quantité DANS L'ÉTAT LOCAL SEULEMENT
            existingItem.updateQuantity(existingItem.quantity + 1)
            quantities[stockItem.sku, default: 0] += 1
            print("🔍 Quantité augmentée pour \(stockItem.name): \(existingItem.quantity)")
            print("✅ Article ajouté au panier LOCAL (pas encore sauvegardé)")
            
            // ÉTAPE 3: Réserver un asset additionnel en arrière-plan
            Task {
                do {
                    let newAssignedIds = try await reservationService.adjustReservations(
                        for: existingItem,
                        stockItem: stockItem,
                        newQuantity: existingItem.quantity,
                        event: event,
                        allAssets: allAssets,
                        allReservations: allReservations,
                        modelContext: modelContext
                    )
                    
                    await MainActor.run {
                        existingItem.assignedAssets = newAssignedIds
                        print("✅ Réservation ajustée: \(newAssignedIds.count) assets")
                    }
                } catch {
                    print("❌ Erreur ajustement réservation: \(error)")
                    await MainActor.run {
                        alertMessage = "Erreur lors de la réservation: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
            
        } else {
            print("🔵 Nouvel article - Création du QuoteItem")
            // Nouvel item, créer et ajouter au State local UNIQUEMENT
            let quoteItem = QuoteItem(
                quoteItemId: UUID().uuidString,
                eventId: event.eventId,
                sku: stockItem.sku,
                name: stockItem.name,
                category: stockItem.category,
                quantity: 1,
                unitPrice: stockItem.effectivePrice
            )
            quoteItems.append(quoteItem)
            quantities[stockItem.sku] = 1
            print("🔍 Nouvel item ajouté: \(stockItem.name)")
            print("✅ Article ajouté au panier LOCAL (pas encore sauvegardé)")
            
            // ÉTAPE 3: Réserver automatiquement les assets en arrière-plan
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
                    
                    await MainActor.run {
                        quoteItem.assignedAssets = assignedIds
                        print("✅ \(assignedIds.count) assets réservés pour \(stockItem.name)")
                    }
                } catch {
                    print("❌ Erreur réservation: \(error)")
                    await MainActor.run {
                        alertMessage = "Erreur lors de la réservation: \(error.localizedDescription)"
                        showAlert = true
                        // Retirer l'item du panier car pas d'assets réservés
                        if let index = quoteItems.firstIndex(where: { $0.sku == stockItem.sku }) {
                            quoteItems.remove(at: index)
                            quantities.removeValue(forKey: stockItem.sku)
                        }
                    }
                }
            }
        }
        
        print("🔵 QuoteItems après: \(quoteItems.count)")
        print("🔵 FIN addItemToCart")
        print("⚠️ RAPPEL: Les modifications ne seront sauvegardées qu'au clic sur 'Enregistrer'")
    }
    
    private func removeItemFromCart(_ stockItem: StockItem) {
        print("🔵 DÉBUT removeItemFromCart - Article: \(stockItem.name)")
        
        if let existingIndex = quoteItems.firstIndex(where: { $0.sku == stockItem.sku }) {
            let item = quoteItems[existingIndex]
            let currentQuantity = item.quantity
            
            if currentQuantity > 1 {
                // Diminuer la quantité DANS L'ÉTAT LOCAL SEULEMENT
                item.updateQuantity(currentQuantity - 1)
                quantities[stockItem.sku, default: 1] -= 1
                print("🔍 Quantité diminuée pour \(stockItem.name): \(currentQuantity - 1)")
                print("✅ Quantité mise à jour dans le panier LOCAL (pas encore sauvegardée)")
                
                // Libérer un asset en arrière-plan
                Task {
                    do {
                        let newAssignedIds = try await reservationService.adjustReservations(
                            for: item,
                            stockItem: stockItem,
                            newQuantity: currentQuantity - 1,
                            event: event,
                            allAssets: allAssets,
                            allReservations: allReservations,
                            modelContext: modelContext
                        )
                        
                        await MainActor.run {
                            item.assignedAssets = newAssignedIds
                            print("🔓 Réservation ajustée: \(newAssignedIds.count) assets")
                        }
                    } catch {
                        print("❌ Erreur libération réservation: \(error)")
                    }
                }
                
            } else {
                // Supprimer complètement l'item DU STATE LOCAL SEULEMENT
                quoteItems.remove(at: existingIndex)
                quantities.removeValue(forKey: stockItem.sku)
                availabilityWarnings.removeValue(forKey: stockItem.sku)
                availabilityResults.removeValue(forKey: stockItem.sku)
                print("🔍 Item supprimé du panier LOCAL: \(stockItem.name)")
                print("✅ Suppression effective dans le panier LOCAL (pas encore sauvegardée)")
                
                // Libérer toutes les réservations en arrière-plan
                Task {
                    do {
                        try await reservationService.releaseReservations(
                            for: item,
                            event: event,
                            allReservations: allReservations,
                            modelContext: modelContext
                        )
                        print("🔓 Toutes les réservations libérées pour \(stockItem.name)")
                    } catch {
                        print("❌ Erreur libération réservations: \(error)")
                    }
                }
            }
        }
        
        print("🔵 FIN removeItemFromCart")
        print("⚠️ RAPPEL: Les modifications ne seront sauvegardées qu'au clic sur 'Enregistrer'")
    }
    
    private func removeAllFromCart(_ stockItem: StockItem) {
        print("🔵 DÉBUT removeAllFromCart - Article: \(stockItem.name)")
        
        // Trouver l'item avant de le supprimer
        if let item = quoteItems.first(where: { $0.sku == stockItem.sku }) {
            // Libérer toutes les réservations en arrière-plan
            Task {
                do {
                    try await reservationService.releaseReservations(
                        for: item,
                        event: event,
                        allReservations: allReservations,
                        modelContext: modelContext
                    )
                    print("🔓 Toutes les réservations libérées pour \(stockItem.name)")
                } catch {
                    print("❌ Erreur libération réservations: \(error)")
                }
            }
        }
        
        // Supprimer du STATE LOCAL SEULEMENT
        quoteItems.removeAll { $0.sku == stockItem.sku }
        quantities.removeValue(forKey: stockItem.sku)
        availabilityWarnings.removeValue(forKey: stockItem.sku)
        availabilityResults.removeValue(forKey: stockItem.sku)
        print("🔍 Item complètement supprimé du panier LOCAL: \(stockItem.name)")
        print("✅ Suppression effective dans le panier LOCAL (pas encore sauvegardée)")
        print("🔵 FIN removeAllFromCart")
        print("⚠️ RAPPEL: Les modifications ne seront sauvegardées qu'au clic sur 'Enregistrer'")
    }
    
    private func updateCartQuantity(item: StockItem, quantity: Int) {
        print("🔵 DÉBUT updateCartQuantity - Article: \(item.name), Quantité: \(quantity)")
        
        if quantity <= 0 {
            removeAllFromCart(item)
        } else if let existingIndex = quoteItems.firstIndex(where: { $0.sku == item.sku }) {
            // Mettre à jour la quantité DANS L'ÉTAT LOCAL SEULEMENT
            quoteItems[existingIndex].updateQuantity(quantity)
            quantities[item.sku] = quantity
            print("🔍 Quantité mise à jour pour \(item.name): \(quantity)")
            print("✅ Quantité mise à jour dans le panier LOCAL (pas encore sauvegardée)")
        }
        
        print("🔵 FIN updateCartQuantity")
        print("⚠️ RAPPEL: Les modifications ne seront sauvegardées qu'au clic sur 'Enregistrer'")
    }
    
    private func clearCart() {
        print("🔵 DÉBUT clearCart")
        
        // Vider le panier LOCAL SEULEMENT
        quoteItems.removeAll()
        quantities.removeAll()
        print("🔍 Panier LOCAL vidé complètement")
        print("✅ Panier vidé dans l'état LOCAL (pas encore sauvegardé)")
        print("🔵 FIN clearCart")
        print("⚠️ RAPPEL: Les modifications ne seront sauvegardées qu'au clic sur 'Enregistrer'")
    }

    private func addItemToQuote(_ stockItem: StockItem) {
        addItemToCart(stockItem)
    }

    private func handleScanResult(_ result: ScanResult) {
        let scannedCode = result.rawPayload
        if let stockItem = stockItems.first(where: { $0.sku == scannedCode }) {
            addItemToCart(stockItem)
            alertMessage = "✓ \(stockItem.name) ajouté au panier"
            showAlert = true
        } else {
            alertMessage = "Article non trouvé dans le stock"
            showAlert = true
        }
    }

    private func updateQuantity(for item: QuoteItem, quantity: Int) {
        print("🔵 DÉBUT updateQuantity - Article: \(item.name), Quantité: \(quantity)")
        
        if let existingIndex = quoteItems.firstIndex(where: { $0.quoteItemId == item.quoteItemId }) {
            // Mettre à jour la quantité DANS L'ÉTAT LOCAL SEULEMENT
            quoteItems[existingIndex].updateQuantity(quantity)
            print("🔍 Quantité mise à jour pour \(item.name): \(quantity)")
            print("✅ Quantité mise à jour dans le panier LOCAL (pas encore sauvegardée)")
        }
        
        print("🔵 FIN updateQuantity")
        print("⚠️ RAPPEL: Les modifications ne seront sauvegardées qu'au clic sur 'Enregistrer'")
    }

    private func updatePrice(for item: QuoteItem, price: Double) {
        print("🔵 DÉBUT updatePrice - Article: \(item.name), Prix: \(price)€")
        
        if let existingIndex = quoteItems.firstIndex(where: { $0.quoteItemId == item.quoteItemId }) {
            // Mettre à jour le prix DANS L'ÉTAT LOCAL SEULEMENT
            quoteItems[existingIndex].updateCustomPrice(price)
            print("🔍 Prix mis à jour pour \(item.name): \(price)€")
            print("✅ Prix mis à jour dans le panier LOCAL (pas encore sauvegardé)")
        }
        
        print("🔵 FIN updatePrice")
        print("⚠️ RAPPEL: Les modifications ne seront sauvegardées qu'au clic sur 'Enregistrer'")
    }

    private func deleteItem(_ item: QuoteItem) {
        print("🔵 DÉBUT deleteItem - Article: \(item.name)")
        
        // Supprimer du STATE LOCAL SEULEMENT
        quoteItems.removeAll { $0.quoteItemId == item.quoteItemId }
        quantities.removeValue(forKey: item.sku)
        print("🔍 Item supprimé du panier LOCAL: \(item.name)")
        print("✅ Suppression effective dans le panier LOCAL (pas encore sauvegardée)")
        print("🔵 FIN deleteItem")
        print("⚠️ RAPPEL: Les modifications ne seront sauvegardées qu'au clic sur 'Enregistrer'")
    }
    
    // MARK: - Data Loading
    
    private func loadExistingQuoteItems() {
        print("🔍 DEBUG - Chargement des items existants pour eventId: \(event.eventId)")
        print("🔍 Statut du devis: \(event.quoteStatus.displayName)")
        print("🔍 Nombre total de QuoteItems en base: \(allQuoteItems.count)")
        
        // Charger les items existants depuis la DB
        let existingItems = allQuoteItems.filter { $0.eventId == event.eventId }
        print("🔍 Items trouvés pour cet événement: \(existingItems.count)")
        
        if !existingItems.isEmpty {
            // IMPORTANT: Créer des COPIES propres pour éviter les conflits SwiftData
            // Ne jamais utiliser directement les objets de la @Query
            quoteItems = existingItems.map { item in
                let newItem = QuoteItem(
                    quoteItemId: item.quoteItemId,
                    eventId: item.eventId,
                    sku: item.sku,
                    name: item.name,
                    category: item.category,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice
                )
                newItem.customPrice = item.customPrice
                newItem.assignedAssets = item.assignedAssets
                return newItem
            }
            
            print("🔍 Items chargés dans le panier LOCAL:")
            for item in quoteItems {
                print("  - \(item.name): \(item.quantity)x à \(item.customPrice)€")
            }
            
            // Reconstruire le dictionnaire des quantités
            quantities = [:]
            for item in quoteItems {
                quantities[item.sku] = item.quantity
            }
            
            // Charger la remise existante
            globalDiscount = event.discountPercent
            
            print("🔍 Remise chargée: \(globalDiscount)%")
            print("✅ Devis existant chargé avec succès")
        } else {
            print("🔍 Aucun item existant - nouveau devis")
            quoteItems = []
            print("✅ Panier vide - prêt pour créer un nouveau devis")
        }
        
        // Toujours afficher le catalogue (ne pas ouvrir la sheet automatiquement)
        showingCartSummary = false
    }
    
    private func saveQuote(finalize: Bool = false) async {
        print("💾 DEBUG - Sauvegarde du devis (finalize: \(finalize))")
        print("🔍 Nombre d'items dans le panier: \(quoteItems.count)")
        
        // Annuler toute sauvegarde automatique en attente
        autoSaveTask?.cancel()
        
        do {
            // Supprimer les anciens items de cet événement
            let oldItems = allQuoteItems.filter { $0.eventId == event.eventId }
            print("🗑️ Suppression de \(oldItems.count) anciens items")
            for oldItem in oldItems {
                modelContext.delete(oldItem)
            }
            
            // Insérer les nouveaux items
            for item in quoteItems {
                print("➕ Insertion de: \(item.name) - Quantité: \(item.quantity)")
                modelContext.insert(item)
            }
            
            // Mettre à jour l'événement
            event.updateTotalAmount(finalTotal)
            event.discountPercent = discountPercentage
            event.quoteStatus = finalize ? .finalized : .draft
            event.updatedAt = Date() // Forcer la mise à jour
            
            print("💰 Total du devis: \(finalTotal)€")
            print("🎯 Remise: \(discountPercentage)%")
            print("📋 Statut: \(finalize ? "finalisé" : "brouillon")")

            // Utiliser EventService pour sauvegarder (local + Firebase)
            print("📤 Utilisation d'EventService pour la sauvegarde...")
            try await eventService.saveEventWithQuoteItems(
                event: event,
                quoteItems: quoteItems,
                modelContext: modelContext
            )
            print("✅ Sauvegarde complète réussie (local + Firebase)")
            
            // Si finalisation, créer automatiquement les 4 ScanLists
            if finalize {
                print("📋 Création automatique des listes de scan...")
                do {
                    let scanLists = try scanListService.generateAllScanLists(
                        from: event,
                        quoteItems: quoteItems,
                        modelContext: modelContext
                    )
                    print("✅ \(scanLists.count) ScanLists créées automatiquement")
                    
                    // Créer les tâches automatiquement
                    try await createTasksForEvent()
                    
                    // 🆕 CRÉER LA VERSION PDF
                    print("📄 Génération de la version PDF...")
                    if let currentUser = PermissionService.shared.currentUser {
                        do {
                            // Générer le PDF
                            let pdfData = generatePDFData()
                            print("✅ PDF généré (\(pdfData.count) bytes)")
                            
                            // Créer la version avec upload du PDF
                            let version = try await versionService.createVersion(
                                event: event,
                                quoteItems: quoteItems,
                                pdfData: pdfData,
                                createdBy: currentUser.userId,
                                createdByName: currentUser.displayName,
                                modelContext: modelContext
                            )
                            
                            print("✅ Version \(version.versionNumber) créée et uploadée dans Firebase Storage")
                        } catch {
                            print("⚠️ Erreur création version PDF (non bloquant): \(error)")
                            // Ne pas bloquer la finalisation si le PDF échoue
                        }
                    } else {
                        print("⚠️ Utilisateur non connecté - version PDF non créée")
                    }
                    
                } catch {
                    print("⚠️ Erreur création ScanLists/Tâches (non bloquant): \(error)")
                    // Ne pas bloquer la finalisation si la liste échoue
                }
            }
            
            // Fermer l'interface sur le Main Thread (SEULEMENT si finalisé)
            await MainActor.run {
                if finalize {
                    // Finalisation : fermer d'abord la sheet si ouverte
                    if showingCartSummary {
                        print("🔽 Fermeture de la sheet du panier...")
                        showingCartSummary = false
                        
                        // Attendre que la sheet se ferme avant de dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            print("🔙 Retour à EventDetailView après finalisation")
                            dismiss()
                        }
                    } else {
                        // Pas de sheet ouverte, dismiss direct
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("🔙 Retour à EventDetailView après finalisation")
                            dismiss()
                        }
                    }
                } else {
                    // Sauvegarde simple : rester sur la vue
                    print("✅ Sauvegarde brouillon réussie - Vue reste ouverte")
                }
            }
            
        } catch {
            print("❌ Erreur lors de la sauvegarde: \(error.localizedDescription)")
            await MainActor.run {
                alertMessage = "Erreur lors de la sauvegarde: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func syncToFirebase() async throws {
        print("🔄 Synchronisation Firebase - Événement: \(event.eventId)")
        
        do {
            // 1. Synchroniser l'événement
            print("📝 Conversion de l'événement en FirestoreEvent...")
            let firestoreEvent = event.toFirestoreEvent()
            print("📤 Envoi de l'événement à Firebase...")
            try await firebaseService.updateEvent(firestoreEvent)
            print("✅ Événement synchronisé avec Firebase")
            
            // 2. Supprimer les anciens quote items de Firebase
            print("🔍 Récupération des anciens items Firebase...")
            let oldFirestoreItems = try await firebaseService.fetchQuoteItems(forEvent: event.eventId)
            print("🗑️ \(oldFirestoreItems.count) anciens items trouvés, suppression...")
            for oldItem in oldFirestoreItems {
                try await firebaseService.deleteQuoteItem(quoteItemId: oldItem.quoteItemId, forEvent: event.eventId)
            }
            print("✅ Anciens items supprimés de Firebase")
            
            // 3. Créer les nouveaux quote items dans Firebase
            print("📤 Création de \(quoteItems.count) nouveaux items dans Firebase...")
            for (index, item) in quoteItems.enumerated() {
                print("  ➡️ Item \(index + 1)/\(quoteItems.count): \(item.name) x\(item.quantity)")
                let firestoreItem = item.toFirestoreQuoteItem()
                try await firebaseService.createQuoteItem(firestoreItem, forEvent: event.eventId)
            }
            print("✅ Nouveaux items synchronisés avec Firebase (\(quoteItems.count) items)")
            
        } catch {
            print("❌ ERREUR FIREBASE SYNC: \(error.localizedDescription)")
            print("❌ Détails: \(error)")
            throw error
        }
    }
    
    private func autoSave() {
        print("💾 Sauvegarde automatique...")
        
        // Supprimer les anciens items de cet événement
        let oldItems = allQuoteItems.filter { $0.eventId == event.eventId }
        for oldItem in oldItems {
            modelContext.delete(oldItem)
        }
        
        // Insérer les nouveaux items
        for item in quoteItems {
            modelContext.insert(item)
        }
        
        // Mettre à jour l'événement (garder le statut actuel)
        event.updateTotalAmount(finalTotal)
        event.discountPercent = discountPercentage
        
        do {
            try modelContext.save()
            print("✅ Sauvegarde automatique réussie")
            
            // Synchroniser avec Firebase en arrière-plan (erreurs ignorées car auto-save)
            Task {
                try? await syncToFirebase()
            }
        } catch {
            print("❌ Erreur sauvegarde automatique: \(error)")
        }
    }
    
    private func scheduleAutoSave() {
        // Annuler la sauvegarde précédente si elle existe
        autoSaveTask?.cancel()
        
        // Programmer une nouvelle sauvegarde après 2 secondes
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes
            
            // Vérifier si la tâche n'a pas été annulée
            if !Task.isCancelled {
                await MainActor.run {
                    autoSave()
                }
            }
        }
    }
    
    private func saveDraft() {
        Task {
            await saveQuote()
        }
    }

    private func generateInvoice() {
        Task { @MainActor in
            isSaving = true
            
            do {
                // 1. Sauvegarder et finaliser le devis
                await saveQuote(finalize: true)
                
                // 2. Générer les 4 listes de scan + créer les tâches
                print("📋 Génération des listes de préparation complètes...")
                let scanLists = try scanListService.generateAllScanLists(
                    from: event,
                    quoteItems: quoteItems,
                    modelContext: modelContext
                )
                
                generatedScanList = scanLists.first
                
                // 3. Créer les tâches automatiquement
                try await createTasksForEvent()
                
                // 4. Afficher un message de succès
                await MainActor.run {
                    isSaving = false
                    alertMessage = "✅ Devis finalisé : \(scanLists.count) listes de scan et tâches créées !"
                    showAlert = true
                    
                    // 5. Proposer d'ouvrir la liste de scan
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingScanList = true
                    }
                }
                
            } catch let error as ScanListError {
                await MainActor.run {
                    isSaving = false
                    alertMessage = "⚠️ Erreur : \(error.localizedDescription)"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    alertMessage = "❌ Erreur lors de la finalisation : \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func createTasksForEvent() async throws {
        print("🔄 [QuoteBuilder] Début création des tâches...")
        
        // Récupérer l'utilisateur connecté depuis UserDefaults
        let userId = UserDefaults.standard.string(forKey: "currentUserId")
        print("👤 [QuoteBuilder] UserId depuis UserDefaults: \(userId ?? "nil")")
        
        guard let userId = userId else {
            print("❌ [QuoteBuilder] Pas d'userId dans UserDefaults")
            return
        }
        
        // Récupérer le companyId depuis PermissionService (qui a déjà l'utilisateur chargé)
        guard let currentUser = PermissionService.shared.currentUser else {
            print("❌ [QuoteBuilder] Pas d'utilisateur dans PermissionService")
            return
        }
        
        print("✅ [QuoteBuilder] Utilisateur trouvé: \(currentUser.displayName)")
        
        guard let companyId = currentUser.companyId else {
            print("❌ [QuoteBuilder] Pas de companyId pour l'utilisateur")
            return
        }
        
        print("✅ [QuoteBuilder] CompanyId: \(companyId)")
        
        // Générer les tâches suggérées
        print("🔄 [QuoteBuilder] Génération des tâches suggérées...")
        var allTasks = try TaskService.shared.generateSuggestedTasks(
            for: event,
            companyId: companyId,
            createdBy: userId,
            modelContext: modelContext
        )
        
        print("✅ [QuoteBuilder] \(allTasks.count) tâches générées")
        
        // Retirer la tâche "Créer liste de scan" car elles sont déjà créées automatiquement
        allTasks.removeAll { $0.type == .createScanList }
        
        print("✅ [QuoteBuilder] \(allTasks.count) tâches à créer (après filtrage)")
        
        // Créer toutes les tâches
        for (index, task) in allTasks.enumerated() {
            print("📝 [QuoteBuilder] Création tâche \(index + 1)/\(allTasks.count): \(task.type.displayName)")
            _ = try await TaskService.shared.createTask(task, modelContext: modelContext)
        }
        
        print("✅ [QuoteBuilder] \(allTasks.count) tâches créées automatiquement")
    }
}

// MARK: - Supporting Views

struct StockItemQuickAddRow: View {
    let item: StockItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    HStack {
                        Text(item.sku)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text("\(item.availableQuantity)/\(item.totalQuantity) dispo")
                            .font(.caption)
                            .foregroundColor(item.availableQuantity > 0 ? .green : .red)
                    }
                }

                Spacer()

                Text(String(format: "%.2f €", item.effectivePrice))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct QuoteItemCard: View {
    let item: QuoteItem
    let onQuantityChange: (Int) -> Void
    let onPriceChange: (Double) -> Void
    let onDelete: () -> Void

    @State private var customPrice: String
    @State private var showDeleteConfirmation = false

    init(
        item: QuoteItem, onQuantityChange: @escaping (Int) -> Void,
        onPriceChange: @escaping (Double) -> Void, onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.onQuantityChange = onQuantityChange
        self.onPriceChange = onPriceChange
        self.onDelete = onDelete
        _customPrice = State(initialValue: String(format: "%.2f", item.customPrice))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête
            HStack {
                Text(item.name)
                    .font(.headline)

                Spacer()

                Text(item.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }

            Text("SKU: \(item.sku)")
                .font(.caption)
                .foregroundColor(.secondary)

            // Quantité
            HStack {
                Text("Quantité:")
                    .font(.subheadline)

                Spacer()

                HStack(spacing: 16) {
                    Button(action: { onQuantityChange(max(1, item.quantity - 1)) }) {
                        Image(systemName: "minus.circle")
                            .font(.title3)
                    }
                    .disabled(item.quantity <= 1)

                    Text("\(item.quantity)")
                        .font(.headline)
                        .frame(minWidth: 30)

                    Button(action: { onQuantityChange(item.quantity + 1) }) {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                }
            }

            // Prix
            VStack(spacing: 8) {
                HStack {
                    Text("Prix unitaire configuré:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f €", item.unitPrice))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Prix appliqué:")
                        .font(.subheadline)

                    Spacer()

                    HStack(spacing: 4) {
                        TextField("Prix", text: $customPrice)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: customPrice) { _, newValue in
                                if let price = Double(
                                    newValue.replacingOccurrences(of: ",", with: "."))
                                {
                                    onPriceChange(price)
                                }
                            }

                        Text("€")
                    }

                    // Badge discount
                    if abs(item.discountPercent) > 0.01 {
                        HStack(spacing: 2) {
                            Image(systemName: item.discountPercent < 0 ? "arrow.down" : "arrow.up")
                                .font(.caption2)
                            Text(String(format: "%.0f%%", abs(item.discountPercent)))
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            item.discountPercent < 0
                                ? Color.green.opacity(0.2) : Color.red.opacity(0.2)
                        )
                        .foregroundColor(item.discountPercent < 0 ? .green : .red)
                        .cornerRadius(4)
                    }
                }
            }

            Divider()

            // Total
            HStack {
                Text("Total ligne:")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(String(format: "%.2f €", item.totalPrice))
                    .font(.headline)
                    .foregroundColor(.blue)

                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .confirmationDialog(
            "Supprimer cet article ?", isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                onDelete()
            }
            Button("Annuler", role: .cancel) {}
        }
    }
}

struct CapacityBar: View {
    let title: String
    let current: Double
    let max: Double
    let unit: String

    private var percentage: Double {
        guard max > 0 else { return 0 }
        return min(current / max, 1.0)
    }

    private var color: Color {
        if percentage > 1.0 {
            return .red
        } else if percentage > 0.8 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "%.1f / %.0f %@", current, max, unit))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percentage))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - New Components for Shopping Cart Style

struct CategoryChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("(\(count))")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct StockItemCard: View {
    let item: StockItem
    let quantityInCart: Int
    let availabilityResult: AvailabilityResult?
    let warning: String?
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onQuantityChange: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Image placeholder ou icône catégorie
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: categoryIcon(for: item.category))
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                // Informations article
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(item.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text("\(Int(item.effectivePrice))€")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        // Badge de disponibilité intelligent
                        if let result = availabilityResult {
                            availabilityBadge(for: result)
                        } else if item.availableQuantity > 0 {
                            Label("\(item.availableQuantity) dispo", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Label("Stock limité", systemImage: "exclamationmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Contrôles quantité
                if quantityInCart > 0 {
                    HStack(spacing: 12) {
                        Button(action: {
                            print("➖ Bouton moins cliqué pour: \(item.name)")
                            onRemove()
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        
                        Text("\(quantityInCart)")
                            .font(.headline)
                            .frame(minWidth: 30)
                        
                        Button(action: {
                            print("➕ Bouton plus cliqué pour: \(item.name)")
                            onAdd()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: {
                        print("🆕 Bouton Ajouter cliqué pour: \(item.name)")
                        onAdd()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Ajouter")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Warning de disponibilité
            if let warning = warning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(warning)
                        .font(.caption)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func availabilityBadge(for result: AvailabilityResult) -> some View {
        let available = result.availableQuantity
        let severity = result.severity
        
        if available == 0 {
            Label("Épuisé", systemImage: "xmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.15))
                .cornerRadius(8)
        } else if severity == .warning {
            Label("\(available) dispo", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
        } else {
            Label("\(available) dispo", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "tables": return "table.furniture"
        case "chaises": return "chair"
        case "scène": return "music.mic"
        case "lumières": return "lightbulb"
        case "son": return "speaker.wave.2"
        case "décoration": return "sparkles"
        default: return "cube.box"
        }
    }
}

struct CartItemRow: View {
    let item: QuoteItem
    let onQuantityChange: (Int) -> Void
    let onRemove: () -> Void
    
    @State private var showEditPrice = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Infos article
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(item.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showEditPrice = true
                    }) {
                        HStack(spacing: 4) {
                            Text("\(Int(item.customPrice))€")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Contrôles quantité
                HStack(spacing: 12) {
                    Button(action: {
                        onQuantityChange(item.quantity - 1)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    
                    Text("\(item.quantity)")
                        .font(.headline)
                        .frame(minWidth: 30)
                    
                    Button(action: {
                        onQuantityChange(item.quantity + 1)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                
                // Prix total
                Text("\(Int(item.totalPrice))€")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(width: 60, alignment: .trailing)
                
                // Bouton supprimer
                Button(action: onRemove) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            
            // Barre de modification du prix
            if showEditPrice {
                PriceEditRow(
                    currentPrice: item.customPrice,
                    unitPrice: item.unitPrice,
                    onSave: { newPrice in
                        item.updateCustomPrice(newPrice)
                        showEditPrice = false
                    },
                    onCancel: {
                        showEditPrice = false
                    }
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct PriceEditRow: View {
    let currentPrice: Double
    let unitPrice: Double
    let onSave: (Double) -> Void
    let onCancel: () -> Void
    
    @State private var editedPrice: String = ""
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Prix unitaire:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Prix", text: $editedPrice)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                
                Text("€")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Annuler") {
                    onCancel()
                }
                .font(.caption)
                .foregroundColor(.red)
                
                Button("OK") {
                    if let newPrice = Double(editedPrice), newPrice > 0 {
                        onSave(newPrice)
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Text("Prix catalogue: \(Int(unitPrice))€")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .onAppear {
            editedPrice = String(format: "%.2f", currentPrice)
        }
    }
}

// MARK: - PDF Generation

extension QuoteBuilderView {
    // Propriétés calculées spécifiques pour le PDF (les autres existent déjà dans la vue principale)
    private var pdfSubtotal: Double {
        quoteItems.reduce(0) { $0 + $1.totalPrice }
    }
    
    private var pdfDeliveryAmount: Double {
        event.deliveryFee
    }
    
    private var pdfAssemblyAmount: Double {
        event.assemblyFee
    }
    
    private var pdfDisassemblyAmount: Double {
        event.disassemblyFee
    }
    
    private var pdfTotalBeforeTVA: Double {
        pdfSubtotal + pdfDeliveryAmount + pdfAssemblyAmount + pdfDisassemblyAmount
    }
    
    private var pdfTvaAmount: Double {
        pdfTotalBeforeTVA * (event.tvaRate / 100)
    }
    
    private var pdfTotalWithTVA: Double {
        pdfTotalBeforeTVA + pdfTvaAmount
    }
    
    func generatePDFData() -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 size in points
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        return renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 50
            
            // En-tête
            yPosition = drawHeader(in: pageRect, startY: yPosition)
            
            // Informations événement
            yPosition = drawEventInfo(in: pageRect, startY: yPosition + 20)
            
            // Informations client
            yPosition = drawClientInfo(in: pageRect, startY: yPosition + 15)
            
            // Ligne de séparation
            yPosition += 20
            drawLine(in: pageRect, y: yPosition)
            
            // Tableau des articles
            yPosition = drawItemsTable(in: pageRect, startY: yPosition + 20, context: context)
            
            // Ligne de séparation
            yPosition += 20
            drawLine(in: pageRect, y: yPosition)
            
            // Récapitulatif des prix
            yPosition = drawPricingSummary(in: pageRect, startY: yPosition + 20)
            
            // Pied de page
            drawFooter(in: pageRect)
        }
    }
    
    private func drawHeader(in rect: CGRect, startY: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.systemBlue
        ]
        
        let title = "DEVIS"
        title.draw(at: CGPoint(x: 50, y: startY), withAttributes: attributes)
        
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateText = "Date : \(dateFormatter.string(from: event.createdAt))"
        let dateSize = dateText.size(withAttributes: dateAttributes)
        dateText.draw(at: CGPoint(x: rect.width - dateSize.width - 50, y: startY + 5), withAttributes: dateAttributes)
        
        return startY + 30
    }
    
    private func drawEventInfo(in rect: CGRect, startY: CGFloat) -> CGFloat {
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        
        var y = startY
        
        "Événement".draw(at: CGPoint(x: 50, y: y), withAttributes: boldAttributes)
        y += 20
        
        event.name.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
        y += 18
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        "Du \(dateFormatter.string(from: event.startDate)) au \(dateFormatter.string(from: event.endDate))".draw(
            at: CGPoint(x: 50, y: y),
            withAttributes: regularAttributes
        )
        y += 18
        
        if !event.eventAddress.isEmpty {
            event.eventAddress.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
        }
        
        return y
    }
    
    private func drawClientInfo(in rect: CGRect, startY: CGFloat) -> CGFloat {
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        
        var y = startY
        
        if !event.clientName.isEmpty {
            "Client".draw(at: CGPoint(x: 50, y: y), withAttributes: boldAttributes)
            y += 20
            
            event.clientName.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
            y += 18
            
            if !event.clientPhone.isEmpty {
                event.clientPhone.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
                y += 18
            }
            
            if !event.clientEmail.isEmpty {
                event.clientEmail.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
                y += 18
            }
            
            if !event.clientAddress.isEmpty {
                event.clientAddress.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
            }
        }
        
        return y
    }
    
    private func drawLine(in rect: CGRect, y: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 50, y: y))
        path.addLine(to: CGPoint(x: rect.width - 50, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
    
    private func drawItemsTable(in rect: CGRect, startY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        
        var y = startY
        
        // En-tête du tableau
        "Article".draw(at: CGPoint(x: 50, y: y), withAttributes: boldAttributes)
        "Qté".draw(at: CGPoint(x: 350, y: y), withAttributes: boldAttributes)
        "P.U.".draw(at: CGPoint(x: 410, y: y), withAttributes: boldAttributes)
        "Total".draw(at: CGPoint(x: 480, y: y), withAttributes: boldAttributes)
        
        y += 20
        drawLine(in: rect, y: y)
        y += 10
        
        // Articles
        for item in quoteItems {
            // Vérifier si on a besoin d'une nouvelle page
            if y > rect.height - 150 {
                context.beginPage()
                y = 50
            }
            
            item.name.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
            "\(item.quantity)".draw(at: CGPoint(x: 350, y: y), withAttributes: regularAttributes)
            String(format: "%.2f €", item.unitPrice).draw(at: CGPoint(x: 410, y: y), withAttributes: regularAttributes)
            String(format: "%.2f €", item.totalPrice).draw(at: CGPoint(x: 480, y: y), withAttributes: regularAttributes)
            
            y += 20
        }
        
        return y
    }
    
    private func drawPricingSummary(in rect: CGRect, startY: CGFloat) -> CGFloat {
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        var y = startY
        let leftX: CGFloat = 350
        let rightX: CGFloat = 480
        
        // Sous-total
        "Sous-total articles".draw(at: CGPoint(x: leftX, y: y), withAttributes: regularAttributes)
        String(format: "%.2f €", pdfSubtotal).draw(at: CGPoint(x: rightX, y: y), withAttributes: regularAttributes)
        y += 20
        
        // Frais supplémentaires
        if pdfDeliveryAmount > 0 {
            "Frais de déplacement".draw(at: CGPoint(x: leftX, y: y), withAttributes: regularAttributes)
            String(format: "%.2f €", pdfDeliveryAmount).draw(at: CGPoint(x: rightX, y: y), withAttributes: regularAttributes)
            y += 20
        }
        
        if pdfAssemblyAmount > 0 {
            "Frais de montage".draw(at: CGPoint(x: leftX, y: y), withAttributes: regularAttributes)
            String(format: "%.2f €", pdfAssemblyAmount).draw(at: CGPoint(x: rightX, y: y), withAttributes: regularAttributes)
            y += 20
        }
        
        if pdfDisassemblyAmount > 0 {
            "Frais de démontage".draw(at: CGPoint(x: leftX, y: y), withAttributes: regularAttributes)
            String(format: "%.2f €", pdfDisassemblyAmount).draw(at: CGPoint(x: rightX, y: y), withAttributes: regularAttributes)
            y += 20
        }
        
        // Total HT
        drawLine(in: rect, y: y)
        y += 10
        
        "Total HT".draw(at: CGPoint(x: leftX, y: y), withAttributes: boldAttributes)
        String(format: "%.2f €", pdfTotalBeforeTVA).draw(at: CGPoint(x: rightX, y: y), withAttributes: boldAttributes)
        y += 20
        
        // TVA
        let tvaRateValue = event.tvaRate
        "TVA (\(String(format: "%.1f", tvaRateValue))%)".draw(at: CGPoint(x: leftX, y: y), withAttributes: regularAttributes)
        String(format: "%.2f €", pdfTvaAmount).draw(at: CGPoint(x: rightX, y: y), withAttributes: regularAttributes)
        y += 20
        
        // Total TTC
        drawLine(in: rect, y: y)
        y += 10
        
        let totalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.systemBlue
        ]
        
        "TOTAL TTC".draw(at: CGPoint(x: leftX, y: y), withAttributes: totalAttributes)
        String(format: "%.2f €", pdfTotalWithTVA).draw(at: CGPoint(x: rightX, y: y), withAttributes: totalAttributes)
        
        return y + 30
    }
    
    private func drawFooter(in rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        
        let footerText = "Ce devis est valable 30 jours à compter de sa date d'émission."
        let y = rect.height - 50
        footerText.draw(at: CGPoint(x: 50, y: y), withAttributes: attributes)
    }
}

#Preview {
    NavigationStack {
        QuoteBuilderView(
            event: Event(
                eventId: "1",
                name: "Concert Jazz Festival",
                clientName: "Ville de Paris",
                clientPhone: "01 23 45 67 89",
                clientEmail: "contact@paris.fr",
                clientAddress: "Mairie de Paris",
                eventAddress: "Place de la République",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400),
                assignedTruckId: "truck1"
            ))
    }
    .modelContainer(for: [Event.self, QuoteItem.self, StockItem.self, Truck.self], inMemory: true)
}

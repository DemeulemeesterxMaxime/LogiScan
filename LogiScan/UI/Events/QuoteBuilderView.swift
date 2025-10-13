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
    
    @StateObject private var firebaseService = FirebaseService()
    @StateObject private var syncManager = SyncManager()

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
    @State private var autoSaveTask: Task<Void, Never>?  // Pour le debounce de la sauvegarde auto

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
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if quoteItems.isEmpty {
                        alertMessage = "Le panier est vide. Ajoutez des articles avant d'enregistrer."
                        showAlert = true
                    } else {
                        saveQuote()
                    }
                }) {
                    Text("Enregistrer")
                        .fontWeight(.semibold)
                }
                .disabled(quoteItems.isEmpty)
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
        .alert("Information", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadExistingQuoteItems()
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
                        onAdd: {
                            addItemToCart(item)
                        },
                        onRemove: {
                            removeItemFromCart(item)
                        },
                        onQuantityChange: { newQuantity in
                            updateCartQuantity(item: item, quantity: newQuantity)
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
                saveQuote(finalize: true)
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Terminer le devis")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
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
                showingCartSummary = false
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
        // Vérifier si l'item existe déjà dans le panier local
        if let existingIndex = quoteItems.firstIndex(where: { $0.sku == stockItem.sku }) {
            // Item existe, augmenter la quantité
            quoteItems[existingIndex].updateQuantity(quoteItems[existingIndex].quantity + 1)
            quantities[stockItem.sku, default: 0] += 1
            print("🔍 Quantité augmentée pour \(stockItem.name): \(quoteItems[existingIndex].quantity)")
        } else {
            // Nouvel item, créer et ajouter au State local
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
        }
        
        // Sauvegarde automatique avec debounce
        scheduleAutoSave()
    }
    
    private func removeItemFromCart(_ stockItem: StockItem) {
        if let existingIndex = quoteItems.firstIndex(where: { $0.sku == stockItem.sku }) {
            let currentQuantity = quoteItems[existingIndex].quantity
            if currentQuantity > 1 {
                quoteItems[existingIndex].updateQuantity(currentQuantity - 1)
                quantities[stockItem.sku, default: 1] -= 1
                print("🔍 Quantité diminuée pour \(stockItem.name): \(currentQuantity - 1)")
            } else {
                quoteItems.remove(at: existingIndex)
                quantities.removeValue(forKey: stockItem.sku)
                print("🔍 Item supprimé: \(stockItem.name)")
            }
        }
        
        // Sauvegarde automatique avec debounce
        scheduleAutoSave()
    }
    
    private func removeAllFromCart(_ stockItem: StockItem) {
        quoteItems.removeAll { $0.sku == stockItem.sku }
        quantities.removeValue(forKey: stockItem.sku)
        print("🔍 Item complètement supprimé: \(stockItem.name)")
        
        // Sauvegarde automatique avec debounce
        scheduleAutoSave()
    }
    
    private func updateCartQuantity(item: StockItem, quantity: Int) {
        if quantity <= 0 {
            removeAllFromCart(item)
        } else if let existingIndex = quoteItems.firstIndex(where: { $0.sku == item.sku }) {
            quoteItems[existingIndex].updateQuantity(quantity)
            quantities[item.sku] = quantity
            print("🔍 Quantité mise à jour pour \(item.name): \(quantity)")
        }
        
        // Sauvegarde automatique avec debounce
        scheduleAutoSave()
    }
    
    private func clearCart() {
        quoteItems.removeAll()
        quantities.removeAll()
        print("🔍 Panier vidé complètement")
        
        // Sauvegarde automatique avec debounce
        scheduleAutoSave()
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
        if let existingIndex = quoteItems.firstIndex(where: { $0.quoteItemId == item.quoteItemId }) {
            quoteItems[existingIndex].updateQuantity(quantity)
            print("🔍 Quantité mise à jour pour \(item.name): \(quantity)")
        }
        
        // Sauvegarde automatique avec debounce
        scheduleAutoSave()
    }

    private func updatePrice(for item: QuoteItem, price: Double) {
        if let existingIndex = quoteItems.firstIndex(where: { $0.quoteItemId == item.quoteItemId }) {
            quoteItems[existingIndex].updateCustomPrice(price)
            print("🔍 Prix mis à jour pour \(item.name): \(price)€")
        }
        
        // Sauvegarde automatique avec debounce
        scheduleAutoSave()
    }

    private func deleteItem(_ item: QuoteItem) {
        quoteItems.removeAll { $0.quoteItemId == item.quoteItemId }
        quantities.removeValue(forKey: item.sku)
        print("🔍 Item supprimé: \(item.name)")
        
        // Sauvegarde automatique avec debounce
        scheduleAutoSave()
    }
    
    // MARK: - Data Loading
    
    private func loadExistingQuoteItems() {
        print("🔍 DEBUG - Chargement des items existants pour eventId: \(event.eventId)")
        print("🔍 Nombre total de QuoteItems en base: \(allQuoteItems.count)")
        
        // Charger les items existants depuis la DB
        let existingItems = allQuoteItems.filter { $0.eventId == event.eventId }
        print("🔍 Items trouvés pour cet événement: \(existingItems.count)")
        
        if !existingItems.isEmpty {
            // Copier les items dans le State local
            quoteItems = existingItems
            
            print("🔍 Items chargés:")
            for item in existingItems {
                print("  - \(item.name): \(item.quantity)x à \(item.customPrice)€")
            }
            
            // Reconstruire le dictionnaire des quantités
            quantities = [:]
            for item in existingItems {
                quantities[item.sku] = item.quantity
            }
            
            // Charger la remise existante
            globalDiscount = event.discountPercent
            
            print("🔍 Remise chargée: \(globalDiscount)%")
        } else {
            print("🔍 Aucun item existant - nouveau devis")
            quoteItems = []
        }
        
        // Toujours afficher le catalogue
        showingCartSummary = false
    }
    
    private func saveQuote(finalize: Bool = false) {
        print("🔍 DEBUG - Sauvegarde du devis")
        print("🔍 Nombre d'items dans le panier: \(quoteItems.count)")
        
        // Annuler toute sauvegarde automatique en attente
        autoSaveTask?.cancel()
        
        // Supprimer les anciens items de cet événement
        let oldItems = allQuoteItems.filter { $0.eventId == event.eventId }
        print("🔍 Suppression de \(oldItems.count) anciens items")
        for oldItem in oldItems {
            modelContext.delete(oldItem)
        }
        
        // Insérer les nouveaux items
        for item in quoteItems {
            print("🔍 Insertion de: \(item.name) - Quantité: \(item.quantity)")
            modelContext.insert(item)
        }
        
        // Mettre à jour l'événement
        event.updateTotalAmount(finalTotal)
        event.discountPercent = discountPercentage
        event.quoteStatus = finalize ? .finalized : .draft
        
        print("🔍 Total du devis: \(finalTotal)€")
        print("🔍 Remise: \(discountPercentage)%")
        print("🔍 Statut: \(finalize ? "finalisé" : "brouillon")")

        do {
            // Sauvegarder le contexte
            try modelContext.save()
            print("✅ Sauvegarde réussie dans SwiftData")
            
            // Vérification immédiate
            print("✅ Vérification - Items sauvegardés:")
            for item in quoteItems {
                print("  - \(item.name): \(item.quantity)x à \(item.customPrice)€")
            }
            
            // Synchroniser avec Firebase
            Task {
                await syncToFirebase()
            }
            
            // Fermer la sheet du panier si elle est ouverte
            showingCartSummary = false
            
            // Attendre un peu avant de dismiss pour que la sheet se ferme proprement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        } catch {
            print("❌ Erreur de sauvegarde: \(error)")
            alertMessage = "Erreur lors de la sauvegarde: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func syncToFirebase() async {
        print("🔄 Synchronisation Firebase - Événement: \(event.eventId)")
        
        do {
            // 1. Synchroniser l'événement
            let firestoreEvent = event.toFirestoreEvent()
            try await firebaseService.updateEvent(firestoreEvent)
            print("✅ Événement synchronisé avec Firebase")
            
            // 2. Supprimer les anciens quote items de Firebase
            let oldFirestoreItems = try await firebaseService.fetchQuoteItems(forEvent: event.eventId)
            for oldItem in oldFirestoreItems {
                try await firebaseService.deleteQuoteItem(quoteItemId: oldItem.quoteItemId, forEvent: event.eventId)
            }
            print("✅ Anciens items supprimés de Firebase")
            
            // 3. Créer les nouveaux quote items dans Firebase
            for item in quoteItems {
                let firestoreItem = item.toFirestoreQuoteItem()
                try await firebaseService.createQuoteItem(firestoreItem, forEvent: event.eventId)
            }
            print("✅ Nouveaux items synchronisés avec Firebase (\(quoteItems.count) items)")
            
        } catch {
            print("❌ Erreur synchronisation Firebase: \(error.localizedDescription)")
            // Ne pas bloquer l'utilisateur, les données sont déjà sauvegardées localement
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
            
            // Synchroniser avec Firebase en arrière-plan
            Task {
                await syncToFirebase()
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
        saveQuote()
    }

    private func generateInvoice() {
        // Sauvegarder d'abord
        saveDraft()

        // TODO: Naviguer vers InvoicePreviewView
        alertMessage = "Génération de facture à venir..."
        showAlert = true
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
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onQuantityChange: (Int) -> Void
    
    var body: some View {
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
                    
                    if item.availableQuantity > 0 {
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
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    
                    Text("\(quantityInCart)")
                        .font(.headline)
                        .frame(minWidth: 30)
                    
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Button(action: onAdd) {
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
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
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
        .padding(8)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
        .onAppear {
            editedPrice = String(format: "%.0f", currentPrice)
        }
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

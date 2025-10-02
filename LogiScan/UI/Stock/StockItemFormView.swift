//
//  StockItemFormView.swift
//  LogiScan
//
//  Created by Demeulemeester on 02/10/2025.
//

import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

struct StockItemFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingItems: [StockItem]
    
    let editingItem: StockItem?
    
    // Sélection article existant
    @State private var isExistingArticle = false
    @State private var selectedExistingItem: StockItem?
    
    // Champs de base
    @State private var name = ""
    @State private var sku = ""
    @State private var category = "Éclairage"
    @State private var itemDescription = ""
    
    // Quantités
    @State private var totalQuantity = 1
    @State private var maintenanceQuantity = 0
    
    // Type de propriété
    @State private var ownershipType: OwnershipType = .owned
    
    // Prix
    @State private var unitValue = ""
    @State private var rentalPrice = ""
    @State private var purchasePrice = ""
    
    // Caractéristiques techniques
    @State private var unitWeight = ""
    @State private var unitVolume = ""
    @State private var powerConsumption = ""
    
    // Dimensions
    @State private var hasDimensions = false
    @State private var dimensionLength = ""
    @State private var dimensionWidth = ""
    @State private var dimensionHeight = ""
    
    // Tags
    @State private var tags: [String] = []
    @State private var showingTagPicker = false
    
    // Commentaires / Specs techniques libres
    @State private var technicalComments = ""
    
    // QR Code après création
    @State private var showingQRCode = false
    @State private var createdItem: StockItem?
    @State private var createdAssets: [Asset] = []
    
    // UI State
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    
    private let categories = ["Éclairage", "Son", "Structures", "Mobilier", "Divers"]
    
    // Tags existants dans la base
    var allExistingTags: [String] {
        let allTags = existingItems.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    init(editingItem: StockItem? = nil) {
        self.editingItem = editingItem
        
        // Si on édite, pré-remplir les champs
        if let item = editingItem {
            _name = State(initialValue: item.name)
            _sku = State(initialValue: item.sku)
            _category = State(initialValue: item.category)
            _itemDescription = State(initialValue: item.itemDescription)
            _totalQuantity = State(initialValue: item.totalQuantity)
            _maintenanceQuantity = State(initialValue: item.maintenanceQuantity)
            _ownershipType = State(initialValue: item.ownershipType)
            _unitValue = State(initialValue: String(format: "%.2f", item.unitValue))
            _unitWeight = State(initialValue: String(format: "%.2f", item.unitWeight))
            _unitVolume = State(initialValue: String(format: "%.4f", item.unitVolume))
            _tags = State(initialValue: item.tags)
            
            // Convertir les specs techniques en commentaires
            let comments = item.technicalSpecs.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            _technicalComments = State(initialValue: comments)
            
            if let rental = item.rentalPrice {
                _rentalPrice = State(initialValue: String(format: "%.2f", rental))
            }
            if let purchase = item.purchasePrice {
                _purchasePrice = State(initialValue: String(format: "%.2f", purchase))
            }
            if let power = item.powerConsumption {
                _powerConsumption = State(initialValue: String(format: "%.2f", power))
            }
            if let dims = item.dimensions {
                _hasDimensions = State(initialValue: true)
                _dimensionLength = State(initialValue: String(format: "%.0f", dims.length))
                _dimensionWidth = State(initialValue: String(format: "%.0f", dims.width))
                _dimensionHeight = State(initialValue: String(format: "%.0f", dims.height))
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Section sélection article existant (seulement en création)
                if editingItem == nil {
                    Section {
                        Toggle("Ajouter des unités à un article existant", isOn: $isExistingArticle)
                            .onChange(of: isExistingArticle) { _, newValue in
                                if !newValue {
                                    selectedExistingItem = nil
                                    resetForm()
                                }
                            }
                        
                        if isExistingArticle {
                            Picker("Sélectionner l'article", selection: $selectedExistingItem) {
                                Text("Choisir...").tag(nil as StockItem?)
                                ForEach(existingItems, id: \.sku) { item in
                                    Text("\(item.name) (\(item.sku))").tag(item as StockItem?)
                                }
                            }
                            .onChange(of: selectedExistingItem) { _, item in
                                if let item = item {
                                    fillFromExistingItem(item)
                                }
                            }
                        }
                    } header: {
                        Text("Type d'ajout")
                    } footer: {
                        if isExistingArticle {
                            Text("Sélectionnez un article pour ajouter des unités. Les informations seront pré-remplies.")
                        }
                    }
                }
                
                // Section informations de base
                Section("Informations générales") {
                    TextField("Nom de l'article", text: $name)
                        .disabled(isExistingArticle && selectedExistingItem != nil)
                    
                    if !isExistingArticle || selectedExistingItem == nil {
                        TextField("SKU (code unique)", text: $sku)
                            .autocapitalization(.allCharacters)
                            .disabled(editingItem != nil)
                    } else {
                        HStack {
                            Text("SKU")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(sku)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Picker("Catégorie", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .disabled(isExistingArticle && selectedExistingItem != nil)
                    
                    TextField("Description", text: $itemDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .disabled(isExistingArticle && selectedExistingItem != nil)
                }
                
                // Section quantités
                Section("Quantités") {
                    Stepper("Quantité à ajouter: \(totalQuantity)", value: $totalQuantity, in: 1...9999)
                    
                    if !isExistingArticle {
                        Stepper("En maintenance: \(maintenanceQuantity)", value: $maintenanceQuantity, in: 0...totalQuantity)
                    }
                }
                
                // Section propriété et tarification
                Section("Propriété et tarification") {
                    Picker("Type de propriété", selection: $ownershipType) {
                        ForEach(OwnershipType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .disabled(isExistingArticle && selectedExistingItem != nil)
                    
                    if ownershipType == .owned {
                        HStack {
                            Text("Valeur unitaire")
                            Spacer()
                            TextField("0.00", text: $unitValue)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("€")
                        }
                        .disabled(isExistingArticle && selectedExistingItem != nil)
                        
                        HStack {
                            Text("Prix d'achat")
                            Spacer()
                            TextField("0.00", text: $purchasePrice)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("€")
                        }
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .disabled(isExistingArticle && selectedExistingItem != nil)
                    } else {
                        HStack {
                            Text("Prix location / jour")
                            Spacer()
                            TextField("0.00", text: $rentalPrice)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("€")
                        }
                        .disabled(isExistingArticle && selectedExistingItem != nil)
                    }
                }
                
                // Section caractéristiques techniques
                if !isExistingArticle || selectedExistingItem == nil {
                    Section("Caractéristiques techniques") {
                        HStack {
                            Text("Poids unitaire")
                            Spacer()
                            TextField("0.0", text: $unitWeight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("kg")
                        }
                        
                        HStack {
                            Text("Volume unitaire")
                            Spacer()
                            TextField("0.0", text: $unitVolume)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("m³")
                        }
                        
                        HStack {
                            Text("Consommation")
                            Spacer()
                            TextField("0", text: $powerConsumption)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("W")
                        }
                        
                        // Dimensions
                        Toggle("Dimensions spécifiques", isOn: $hasDimensions)
                        
                        if hasDimensions {
                            HStack {
                                Text("L")
                                TextField("0", text: $dimensionLength)
                                    .keyboardType(.decimalPad)
                                Text("×")
                                TextField("0", text: $dimensionWidth)
                                    .keyboardType(.decimalPad)
                                Text("×")
                                TextField("0", text: $dimensionHeight)
                                    .keyboardType(.decimalPad)
                                Text("cm")
                            }
                            
                            if let vol = calculatedVolume {
                                Text("Volume: \(String(format: "%.4f", vol)) m³")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                // Section étiquettes
                Section {
                    if !tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.caption)
                                    Button(action: { removeTag(tag) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    
                    Button(action: { showingTagPicker = true }) {
                        Label("Ajouter des étiquettes", systemImage: "tag")
                    }
                } header: {
                    Text("Étiquettes")
                } footer: {
                    Text("Utilisez les étiquettes pour faciliter la recherche")
                }
                
                // Section commentaires / spécifications techniques
                Section {
                    TextEditor(text: $technicalComments)
                        .frame(minHeight: 100)
                } header: {
                    Text("Commentaires & Spécifications techniques")
                } footer: {
                    Text("Espace libre pour ajouter des notes, spécifications techniques, ou tout commentaire utile")
                }
            }
            .navigationTitle(editingItem == nil ? (isExistingArticle ? "Ajouter des unités" : "Nouvel article") : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isExistingArticle ? "Ajouter" : (editingItem == nil ? "Créer" : "Enregistrer")) {
                        saveItem()
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
            .sheet(isPresented: $showingTagPicker) {
                TagPickerView(
                    existingTags: allExistingTags,
                    selectedTags: $tags
                )
            }
            .sheet(isPresented: $showingQRCode) {
                if let item = createdItem {
                    CreatedItemQRView(
                        stockItem: item,
                        serializedAssets: createdAssets,
                        onComplete: {
                            // Fermer le sheet QR et le formulaire
                            showingQRCode = false
                            dismiss()
                        }
                    )
                }
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        if isExistingArticle {
            return selectedExistingItem != nil && totalQuantity > 0
        }
        
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !sku.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !unitValue.isEmpty &&
        (ownershipType == .owned || !rentalPrice.isEmpty) &&
        !unitWeight.isEmpty &&
        !unitVolume.isEmpty
    }
    
    private var calculatedVolume: Double? {
        guard hasDimensions,
              let length = Double(dimensionLength),
              let width = Double(dimensionWidth),
              let height = Double(dimensionHeight),
              length > 0, width > 0, height > 0 else {
            return nil
        }
        return (length * width * height) / 1_000_000
    }
    
    // MARK: - Actions
    
    private func resetForm() {
        name = ""
        sku = ""
        category = "Éclairage"
        itemDescription = ""
        totalQuantity = 1
        maintenanceQuantity = 0
        ownershipType = .owned
        unitValue = ""
        rentalPrice = ""
        purchasePrice = ""
        unitWeight = ""
        unitVolume = ""
        powerConsumption = ""
        hasDimensions = false
        dimensionLength = ""
        dimensionWidth = ""
        dimensionHeight = ""
        tags = []
        technicalComments = ""
    }
    
    private func fillFromExistingItem(_ item: StockItem) {
        name = item.name
        sku = item.sku
        category = item.category
        itemDescription = item.itemDescription
        ownershipType = item.ownershipType
        unitValue = String(format: "%.2f", item.unitValue)
        unitWeight = String(format: "%.2f", item.unitWeight)
        unitVolume = String(format: "%.4f", item.unitVolume)
        tags = item.tags
        
        if let rental = item.rentalPrice {
            rentalPrice = String(format: "%.2f", rental)
        }
        if let purchase = item.purchasePrice {
            purchasePrice = String(format: "%.2f", purchase)
        }
        if let power = item.powerConsumption {
            powerConsumption = String(format: "%.2f", power)
        }
        if let dims = item.dimensions {
            hasDimensions = true
            dimensionLength = String(format: "%.0f", dims.length)
            dimensionWidth = String(format: "%.0f", dims.width)
            dimensionHeight = String(format: "%.0f", dims.height)
        }
        
        // Commentaires vides pour l'ajout d'unités
        technicalComments = ""
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    private func saveItem() {
        guard isFormValid else { return }
        isSubmitting = true
        
        // Cas 1: Ajout d'unités à un article existant
        if isExistingArticle, let existing = selectedExistingItem {
            existing.totalQuantity += totalQuantity
            
            // Créer des assets sérialisés pour chaque unité ajoutée
            var newAssets: [Asset] = []
            for i in 1...totalQuantity {
                let serialNumber = "\(existing.sku)-\(String(format: "%04d", existing.totalQuantity - totalQuantity + i))"
                let assetId = UUID().uuidString
                
                let qrPayload = """
                {
                    "v": 1,
                    "type": "asset",
                    "assetId": "\(assetId)",
                    "serialNumber": "\(serialNumber)",
                    "sku": "\(existing.sku)",
                    "name": "\(existing.name)"
                }
                """
                
                let asset = Asset(
                    assetId: assetId,
                    sku: existing.sku,
                    name: existing.name,
                    category: existing.category,
                    serialNumber: serialNumber,
                    status: .available,
                    weight: existing.unitWeight,
                    volume: existing.unitVolume,
                    value: existing.unitValue,
                    qrPayload: qrPayload,
                    tags: existing.tags
                )
                
                modelContext.insert(asset)
                newAssets.append(asset)
            }
            
            // Ajouter le commentaire s'il y en a un
            if !technicalComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                let timestamp = dateFormatter.string(from: Date())
                let comment = "[\(timestamp)] \(technicalComments)"
                existing.technicalSpecs["Commentaire_\(UUID().uuidString.prefix(8))"] = comment
            }
            
            existing.updatedAt = Date()
            
            do {
                try modelContext.save()
                createdItem = existing
                createdAssets = newAssets
                showingQRCode = true
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
                showingError = true
                isSubmitting = false
            }
            return
        }
        
        // Cas 2: Validation SKU unique (création uniquement)
        if editingItem == nil {
            let skuExists = existingItems.contains { $0.sku.uppercased() == sku.uppercased() }
            if skuExists {
                errorMessage = "Ce SKU existe déjà. Veuillez en choisir un autre."
                showingError = true
                isSubmitting = false
                return
            }
        }
        
        // Conversion des valeurs numériques
        guard let unitValueDouble = Double(unitValue),
              let unitWeightDouble = Double(unitWeight),
              let unitVolumeDouble = Double(unitVolume) else {
            errorMessage = "Valeurs numériques invalides."
            showingError = true
            isSubmitting = false
            return
        }
        
        if ownershipType == .rented && rentalPrice.isEmpty {
            errorMessage = "Le prix de location est obligatoire pour le matériel loué."
            showingError = true
            isSubmitting = false
            return
        }
        
        let rentalPriceDouble = ownershipType == .rented ? Double(rentalPrice) : nil
        let purchasePriceDouble = !purchasePrice.isEmpty ? Double(purchasePrice) : nil
        let powerConsumptionDouble = !powerConsumption.isEmpty ? Double(powerConsumption) : nil
        
        // Dimensions
        var dimensions: Dimensions? = nil
        if hasDimensions,
           let length = Double(dimensionLength),
           let width = Double(dimensionWidth),
           let height = Double(dimensionHeight),
           length > 0, width > 0, height > 0 {
            dimensions = Dimensions(length: length, width: width, height: height)
        }
        
        // Convertir les commentaires en specs techniques
        var specs: [String: String] = [:]
        if !technicalComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            specs["Commentaires"] = technicalComments
        }
        
        if let existingItem = editingItem {
            // Mise à jour
            existingItem.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existingItem.category = category
            existingItem.itemDescription = itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            existingItem.totalQuantity = totalQuantity
            existingItem.maintenanceQuantity = maintenanceQuantity
            existingItem.ownershipType = ownershipType
            existingItem.unitValue = unitValueDouble
            existingItem.unitWeight = unitWeightDouble
            existingItem.unitVolume = unitVolumeDouble
            existingItem.rentalPrice = rentalPriceDouble
            existingItem.purchasePrice = purchasePriceDouble
            existingItem.powerConsumption = powerConsumptionDouble
            existingItem.dimensions = dimensions
            existingItem.tags = tags
            existingItem.technicalSpecs = specs
            existingItem.updatedAt = Date()
        } else {
            // Création
            let newItem = StockItem(
                sku: sku.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                itemDescription: itemDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                totalQuantity: totalQuantity,
                maintenanceQuantity: maintenanceQuantity,
                unitWeight: unitWeightDouble,
                unitVolume: unitVolumeDouble,
                unitValue: unitValueDouble,
                tags: tags,
                ownershipType: ownershipType,
                rentalPrice: rentalPriceDouble,
                purchasePrice: purchasePriceDouble,
                dimensions: dimensions,
                powerConsumption: powerConsumptionDouble,
                technicalSpecs: specs
            )
            
            modelContext.insert(newItem)
            
            // Créer des assets sérialisés pour chaque unité
            var newAssets: [Asset] = []
            for i in 1...totalQuantity {
                let serialNumber = "\(newItem.sku)-\(String(format: "%04d", i))"
                let assetId = UUID().uuidString
                
                let qrPayload = """
                {
                    "v": 1,
                    "type": "asset",
                    "assetId": "\(assetId)",
                    "serialNumber": "\(serialNumber)",
                    "sku": "\(newItem.sku)",
                    "name": "\(newItem.name)"
                }
                """
                
                let asset = Asset(
                    assetId: assetId,
                    sku: newItem.sku,
                    name: newItem.name,
                    category: newItem.category,
                    serialNumber: serialNumber,
                    status: .available,
                    weight: newItem.unitWeight,
                    volume: newItem.unitVolume,
                    value: newItem.unitValue,
                    qrPayload: qrPayload,
                    tags: newItem.tags
                )
                
                modelContext.insert(asset)
                newAssets.append(asset)
            }
            
            createdItem = newItem
            createdAssets = newAssets
        }
        
        do {
            try modelContext.save()
            if editingItem == nil {
                showingQRCode = true
            } else {
                dismiss()
            }
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
            showingError = true
            isSubmitting = false
        }
    }
}

// MARK: - Tag Picker View

struct TagPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let existingTags: [String]
    @Binding var selectedTags: [String]
    
    @State private var newTagName = ""
    @State private var searchText = ""
    @State private var allTags: [String] = []
    @State private var justCreatedTag: String?
    
    var filteredTags: [String] {
        let tagsToFilter = allTags.isEmpty ? existingTags : allTags
        
        if searchText.isEmpty {
            return tagsToFilter.sorted()
        }
        
        // Filtrer par recherche
        let filtered = tagsToFilter.filter { $0.localizedCaseInsensitiveContains(searchText) }
        
        // Si une nouvelle étiquette correspond à la recherche, l'inclure
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty && !filtered.contains(trimmedSearch) {
            return filtered + [trimmedSearch]
        }
        
        return filtered.sorted()
    }
    
    var canCreateNewTag: Bool {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !allTags.contains(trimmed) && !existingTags.contains(trimmed)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Section création
                Section {
                    HStack {
                        TextField("Nouvelle étiquette", text: $newTagName)
                            .autocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit {
                                if canCreateNewTag {
                                    createNewTag()
                                }
                            }
                        
                        Button {
                            createNewTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(canCreateNewTag ? .green : .gray)
                        }
                        .disabled(!canCreateNewTag)
                    }
                } header: {
                    Text("Créer une nouvelle étiquette")
                } footer: {
                    if !newTagName.isEmpty && !canCreateNewTag {
                        if allTags.contains(newTagName.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            Text("Cette étiquette existe déjà")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Section étiquettes sélectionnées (en haut pour visibilité)
                if !selectedTags.isEmpty {
                    Section {
                        ForEach(selectedTags, id: \.self) { tag in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(tag)
                                    .fontWeight(.medium)
                                Spacer()
                                
                                // Animation si c'est une étiquette nouvellement créée
                                if tag == justCreatedTag {
                                    Text("Nouveau")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.2))
                                        .clipShape(Capsule())
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    toggleTag(tag)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Étiquettes sélectionnées")
                            Spacer()
                            Text("\(selectedTags.count)")
                                .foregroundColor(.green)
                                .fontWeight(.bold)
                        }
                    }
                }
                
                // Section toutes les étiquettes
                Section {
                    if filteredTags.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "tag.slash")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Aucune étiquette trouvée")
                                    .foregroundColor(.secondary)
                                
                                if !searchText.isEmpty {
                                    Button {
                                        createTagFromSearch()
                                    } label: {
                                        Label("Créer \"\(searchText)\"", systemImage: "plus")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical)
                            Spacer()
                        }
                    } else {
                        ForEach(filteredTags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                if selectedTags.contains(tag) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                                
                                // Indicateur si nouveau
                                if tag == justCreatedTag {
                                    Text("Nouveau")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.green.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    toggleTag(tag)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Toutes les étiquettes (\(filteredTags.count))")
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher ou créer une étiquette")
            .navigationTitle("Étiquettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Initialiser la liste complète avec les tags existants
            allTags = Array(Set(existingTags)).sorted()
        }
    }
    
    private func createNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Vérifier que le tag n'existe pas déjà
        guard !allTags.contains(trimmed) else {
            // Si le tag existe déjà, juste le sélectionner
            if !selectedTags.contains(trimmed) {
                withAnimation(.spring(response: 0.3)) {
                    selectedTags.append(trimmed)
                    justCreatedTag = trimmed
                }
            }
            newTagName = ""
            return
        }
        
        withAnimation(.spring(response: 0.3)) {
            // Ajouter à la liste complète
            allTags.append(trimmed)
            allTags.sort()
            
            // Sélectionner automatiquement le nouveau tag
            selectedTags.append(trimmed)
            
            // Marquer comme nouveau
            justCreatedTag = trimmed
            
            // Réinitialiser après 2 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    if justCreatedTag == trimmed {
                        justCreatedTag = nil
                    }
                }
            }
        }
        
        newTagName = ""
        
        // Scroll vers le tag créé si possible
        searchText = ""
    }
    
    private func createTagFromSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        withAnimation(.spring(response: 0.3)) {
            // Ajouter à la liste si n'existe pas
            if !allTags.contains(trimmed) {
                allTags.append(trimmed)
                allTags.sort()
            }
            
            // Sélectionner
            if !selectedTags.contains(trimmed) {
                selectedTags.append(trimmed)
            }
            
            justCreatedTag = trimmed
            
            // Réinitialiser
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    if justCreatedTag == trimmed {
                        justCreatedTag = nil
                    }
                }
            }
        }
        
        searchText = ""
    }
    
    private func toggleTag(_ tag: String) {
        if let index = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }
}

// MARK: - Created Item QR View

struct CreatedItemQRView: View {
    @Environment(\.dismiss) private var dismiss
    let stockItem: StockItem
    let serializedAssets: [Asset]
    @State private var qrCodeImages: [(asset: Asset?, image: UIImage)] = []
    @State private var selectedQRIndex: Int?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    // Callback pour fermer aussi le formulaire parent
    let onComplete: () -> Void
    
    // 5cm = ~189 points à 72 DPI (standard iOS)
    private let qrCodeSize: CGFloat = 189
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Article créé avec succès!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(stockItem.name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("SKU: \(stockItem.sku)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if serializedAssets.isEmpty {
                            Text("Article non sérialisé")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("\(serializedAssets.count) unité\(serializedAssets.count > 1 ? "s" : "") sérialisée\(serializedAssets.count > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    // QR Codes Grid
                    if serializedAssets.isEmpty {
                        // Un seul QR pour l'article non sérialisé
                        VStack(spacing: 16) {
                            Text("Code QR de l'article")
                                .font(.headline)
                            
                            if let stockQR = qrCodeImages.first {
                                QRCodeCard(
                                    title: stockItem.name,
                                    subtitle: "SKU: \(stockItem.sku)",
                                    image: stockQR.image,
                                    size: qrCodeSize
                                )
                                .onTapGesture {
                                    selectedQRIndex = 0
                                }
                            }
                        }
                        .padding()
                    } else {
                        // Grille de QR codes pour les assets sérialisés
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Codes QR des unités (5cm × 5cm)")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(Array(qrCodeImages.enumerated()), id: \.offset) { index, item in
                                    if let asset = item.asset {
                                        QRCodeCard(
                                            title: stockItem.name,
                                            subtitle: "S/N: \(asset.serialNumber ?? "")",
                                            image: item.image,
                                            size: qrCodeSize
                                        )
                                        .onTapGesture {
                                            selectedQRIndex = index
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: shareAllQRCodes) {
                            Label("Partager tous les QR Codes", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: printAllQRCodes) {
                            Label("Imprimer tout", systemImage: "printer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Terminé") {
                            dismiss()
                            onComplete() // Ferme aussi le formulaire parent
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                        onComplete() // Ferme aussi le formulaire parent
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if !shareItems.isEmpty {
                    ActivityViewController(activityItems: shareItems)
                }
            }
            .sheet(item: Binding(
                get: { selectedQRIndex.map { QRDetailIdentifier(index: $0) } },
                set: { selectedQRIndex = $0?.index }
            )) { identifier in
                if identifier.index < qrCodeImages.count {
                    let item = qrCodeImages[identifier.index]
                    QRCodeDetailView(
                        image: item.image,
                        title: stockItem.name,
                        subtitle: item.asset != nil ? "S/N: \(item.asset!.serialNumber ?? "")" : "SKU: \(stockItem.sku)",
                        qrCodeSize: qrCodeSize
                    )
                }
            }
        }
        .onAppear {
            generateQRCodes()
        }
    }
    
    private func generateQRCodes() {
        let context = CIContext()
        
        if serializedAssets.isEmpty {
            // QR code pour l'article non sérialisé
            let qrPayload = """
            {
                "v": 1,
                "type": "stock",
                "sku": "\(stockItem.sku)",
                "name": "\(stockItem.name)",
                "category": "\(stockItem.category)"
            }
            """
            
            if let image = generateSingleQRCode(payload: qrPayload, context: context) {
                qrCodeImages.append((asset: nil, image: image))
            }
        } else {
            // QR codes pour chaque asset sérialisé
            for asset in serializedAssets {
                let qrPayload = """
                {
                    "v": 1,
                    "type": "asset",
                    "assetId": "\(asset.assetId)",
                    "serialNumber": "\(asset.serialNumber ?? "")",
                    "sku": "\(stockItem.sku)",
                    "name": "\(stockItem.name)"
                }
                """
                
                if let image = generateSingleQRCode(payload: qrPayload, context: context) {
                    qrCodeImages.append((asset: asset, image: image))
                }
            }
        }
    }
    
    private func generateSingleQRCode(payload: String, context: CIContext) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    private func shareAllQRCodes() {
        // Préparer les items à partager
        var items: [Any] = []
        
        // Créer le PDF
        let pdfData = createQRCodesPDF()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("QRCodes-\(stockItem.sku).pdf")
        
        do {
            try pdfData.write(to: tempURL)
            items.append(tempURL)
        } catch {
            print("Erreur PDF: \(error)")
        }
        
        // Ajouter toutes les images individuellement
        items.append(contentsOf: qrCodeImages.map { $0.image })
        
        // Ajouter un texte descriptif
        if serializedAssets.isEmpty {
            items.append("QR Code: \(stockItem.name) (SKU: \(stockItem.sku))")
        } else {
            items.append("\(serializedAssets.count) QR Codes pour \(stockItem.name) (SKU: \(stockItem.sku))")
        }
        
        shareItems = items
        showingShareSheet = true
    }
    
    private func createQRCodesPDF() -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "LogiScan",
            kCGPDFContextAuthor: "LogiScan App",
            kCGPDFContextTitle: "QR Codes - \(stockItem.name)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // A4 format: 595 x 842 points
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        return renderer.pdfData { context in
            // Configuration de la grille
            let qrSize = qrCodeSize  // 189 points = 5cm
            let columns = 3
            let margin: CGFloat = 20
            let textHeight: CGFloat = 40  // Espace pour titre + sous-titre
            let cellHeight = qrSize + textHeight
            
            // Calcul de l'espacement horizontal pour centrer
            let totalQRWidth = CGFloat(columns) * qrSize
            let availableSpacing = pageWidth - (2 * margin) - totalQRWidth
            let horizontalSpacing = availableSpacing / CGFloat(columns - 1)
            
            // Calcul du nombre de lignes par page
            let availableHeight = pageHeight - (2 * margin)
            let rowsPerPage = Int(availableHeight / (cellHeight + 15))  // 15 = espacement vertical
            let qrPerPage = columns * rowsPerPage
            
            var currentIndex = 0
            
            while currentIndex < qrCodeImages.count {
                context.beginPage()
                
                // Dessiner le titre de la page
                let pageTitle = "QR Codes - \(stockItem.name) (Page \(currentIndex / qrPerPage + 1))"
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ]
                let headerString = NSAttributedString(string: pageTitle, attributes: headerAttributes)
                headerString.draw(at: CGPoint(x: margin, y: 15))
                
                // Dessiner les QR codes en grille
                var yPosition = margin + 30
                
                for row in 0..<rowsPerPage {
                    guard currentIndex < qrCodeImages.count else { break }
                    
                    for col in 0..<columns {
                        guard currentIndex < qrCodeImages.count else { break }
                        
                        let item = qrCodeImages[currentIndex]
                        
                        // Position X de cette colonne
                        let xPosition = margin + CGFloat(col) * (qrSize + horizontalSpacing)
                        
                        // Dessiner le QR code
                        let qrRect = CGRect(x: xPosition, y: yPosition, width: qrSize, height: qrSize)
                        item.image.draw(in: qrRect)
                        
                        // Dessiner le nom de l'article (tronqué si nécessaire)
                        let titleAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.boldSystemFont(ofSize: 9),
                            .foregroundColor: UIColor.black
                        ]
                        let title = stockItem.name
                        let titleRect = CGRect(x: xPosition, y: yPosition + qrSize + 3, width: qrSize, height: 15)
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.lineBreakMode = .byTruncatingTail
                        let titleAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.boldSystemFont(ofSize: 9),
                            .foregroundColor: UIColor.black,
                            .paragraphStyle: paragraphStyle
                        ]
                        title.draw(in: titleRect, withAttributes: titleAttrs)
                        
                        // Dessiner le numéro de série ou SKU
                        let subtitleAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 8),
                            .foregroundColor: UIColor.gray
                        ]
                        let subtitle = item.asset != nil ? "S/N: \(item.asset!.serialNumber ?? "")" : "SKU: \(stockItem.sku)"
                        let subtitleRect = CGRect(x: xPosition, y: yPosition + qrSize + 20, width: qrSize, height: 12)
                        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
                        
                        currentIndex += 1
                    }
                    
                    yPosition += cellHeight + 15  // Passer à la ligne suivante
                }
            }
        }
    }
    
    private func printAllQRCodes() {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "QR Codes - \(stockItem.name)"
        printInfo.outputType = .general
        
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        
        // Utiliser le PDF pour l'impression
        printController.printingItem = createQRCodesPDF()
        
        printController.present(animated: true)
    }
}

// MARK: - QR Detail Identifier
struct QRDetailIdentifier: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - QR Code Detail View
struct QRCodeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let title: String
    let subtitle: String
    let qrCodeSize: CGFloat
    
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 16) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: qrCodeSize, height: qrCodeSize)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
                
                Text("5cm × 5cm")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: { showingShareSheet = true }) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: printQRCode) {
                        Label("Imprimer", systemImage: "printer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityViewController(activityItems: [image, "\(title) - \(subtitle)"])
            }
        }
    }
    
    private func shareQRCode() {
        showingShareSheet = true
    }
    
    private func printQRCode() {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "QR Code - \(subtitle)"
        printInfo.outputType = .general
        
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.printingItem = image
        
        printController.present(animated: true)
    }
}

// MARK: - QR Code Card

struct QRCodeCard: View {
    let title: String
    let subtitle: String
    let image: UIImage
    let size: CGFloat
    
    var body: some View {
        VStack(spacing: 8) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 2)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Activity View Controller Wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

#Preview("Création") {
    StockItemFormView()
        .modelContainer(for: [StockItem.self], inMemory: true)
}

#Preview("Édition") {
    @Previewable @State var sampleItem = StockItem(
        sku: "LED-SPOT-50W",
        name: "Projecteur LED 50W",
        category: "Éclairage",
        itemDescription: "Projecteur LED professionnel",
        totalQuantity: 25,
        unitWeight: 2.5,
        unitVolume: 0.01,
        unitValue: 150.0,
        tags: ["LED", "50W"],
        ownershipType: .owned,
        purchasePrice: 120.0
    )
    
    StockItemFormView(editingItem: sampleItem)
        .modelContainer(for: [StockItem.self], inMemory: true)
}

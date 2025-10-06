//
//  StockItemFormView.swift
//  LogiScan
//
//  Created by Demeulemeester on 02/10/2025.
//

import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct StockItemFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingItems: [StockItem]
    
    // ✅ AJOUT : SyncManager pour synchronisation Firebase
    @StateObject private var syncManager = SyncManager()

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

    // Création automatique des références
    @State private var createIndividualReferences = true

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
            let comments = item.technicalSpecs.map { "\($0.key): \($0.value)" }.joined(
                separator: "\n")
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
                            Text(
                                "Sélectionnez un article pour ajouter des unités. Les informations seront pré-remplies."
                            )
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
                    Stepper(
                        "Quantité à ajouter: \(totalQuantity)", value: $totalQuantity, in: 1...9999)

                    if !isExistingArticle {
                        Stepper(
                            "En maintenance: \(maintenanceQuantity)", value: $maintenanceQuantity,
                            in: 0...totalQuantity)

                        // Option pour créer les références individuelles
                        Toggle(isOn: $createIndividualReferences) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Créer les références individuelles")
                                    .font(.body)
                                Text("Génère \(totalQuantity) référence(s) avec QR codes uniques")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
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
                    Text(
                        "Espace libre pour ajouter des notes, spécifications techniques, ou tout commentaire utile"
                    )
                }
            }
            .navigationTitle(
                editingItem == nil
                    ? (isExistingArticle ? "Ajouter des unités" : "Nouvel article") : "Modifier"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        isExistingArticle
                            ? "Ajouter" : (editingItem == nil ? "Créer" : "Enregistrer")
                    ) {
                        saveItem()
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
            .sheet(isPresented: $showingTagPicker) {
                UnifiedTagPickerView(
                    category: category,
                    selectedTags: $tags
                )
            }
            .sheet(isPresented: $showingQRCode) {
                if let item = createdItem {
                    CreatedItemQRView(
                        stockItem: item,
                        onDismiss: {
                            showingQRCode = false
                            dismiss()  // Ferme aussi le formulaire parent
                        })
                }
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
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

        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sku.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !unitValue.isEmpty
            && (ownershipType == .owned || !rentalPrice.isEmpty) && !unitWeight.isEmpty
            && !unitVolume.isEmpty
    }

    private var calculatedVolume: Double? {
        guard hasDimensions,
            let length = Double(dimensionLength),
            let width = Double(dimensionWidth),
            let height = Double(dimensionHeight),
            length > 0, width > 0, height > 0
        else {
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
                
                // ✅ AJOUT : Synchroniser avec Firebase
                Task {
                    await syncManager.updateStockItemInFirebase(existing)
                }
                
                createdItem = existing
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
            let unitVolumeDouble = Double(unitVolume)
        else {
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
            length > 0, width > 0, height > 0
        {
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
            existingItem.itemDescription = itemDescription.trimmingCharacters(
                in: .whitespacesAndNewlines)
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
            createdItem = newItem

            // Créer les références individuelles si demandé
            if createIndividualReferences {
                createIndividualAssets(
                    for: newItem, quantity: totalQuantity, weight: unitWeightDouble,
                    volume: unitVolumeDouble, value: unitValueDouble)
            }
        }

        do {
            try modelContext.save()
            
            // ✅ AJOUT : Synchroniser avec Firebase
            Task {
                if let existingItem = editingItem {
                    // Mise à jour d'un article existant
                    await syncManager.updateStockItemInFirebase(existingItem)
                } else if let newItem = createdItem {
                    // Création d'un nouvel article
                    await syncManager.syncStockItemToFirebase(newItem)
                }
            }
            
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

    // MARK: - Création des références individuelles

    private func createIndividualAssets(
        for stockItem: StockItem, quantity: Int, weight: Double, volume: Double, value: Double
    ) {
        let skuPrefix = stockItem.sku.uppercased()
        let availableQuantity = quantity - stockItem.maintenanceQuantity

        for i in 1...quantity {
            let assetId = "\(skuPrefix)-\(String(format: "%03d", i))"
            let serialNumber = "\(skuPrefix)-SN\(String(format: "%03d", i))"
            let assetName = "\(stockItem.name) #\(i)"

            let qrPayload = """
                {"v":1,"type":"asset","id":"\(assetId)","sku":"\(stockItem.sku)","sn":"\(serialNumber)"}
                """

            // Les dernières unités sont en maintenance si maintenanceQuantity > 0
            let isInMaintenance = i > availableQuantity

            let asset = Asset(
                assetId: assetId,
                sku: stockItem.sku,
                name: assetName,
                category: stockItem.category,
                serialNumber: serialNumber,
                status: isInMaintenance ? .maintenance : .available,
                weight: weight,
                volume: volume,
                value: value,
                qrPayload: qrPayload,
                tags: stockItem.tags
            )

            modelContext.insert(asset)
        }
    }
}

// MARK: - Created Item QR View

struct CreatedItemQRView: View {
    @Environment(\.dismiss) private var dismiss
    let stockItem: StockItem
    let onDismiss: () -> Void
    @State private var qrCodeImage: UIImage?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
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

                if let qrImage = qrCodeImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding()
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: shareQRCode) {
                        Label("Partager le QR Code", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(qrCodeImage == nil)

                    Button(action: saveQRCodeToFiles) {
                        Label("Enregistrer le QR Code", systemImage: "arrow.down.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(qrCodeImage == nil)
                }
                .padding(.horizontal)

                Spacer()

                Button("Terminé") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        onDismiss()
                    }
                }
            }
        }
        .onAppear {
            generateQRCode()
        }
    }

    private func generateQRCode() {
        let qrPayload = """
            {
                "v": 1,
                "type": "stock",
                "sku": "\(stockItem.sku)",
                "name": "\(stockItem.name)",
                "category": "\(stockItem.category)"
            }
            """

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(qrPayload.utf8)

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }

    private func shareQRCode() {
        guard let image = qrCodeImage else { return }

        let activityVC = UIActivityViewController(
            activityItems: [image, "QR Code: \(stockItem.name) (\(stockItem.sku))"],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first,
            let rootVC = window.rootViewController
        {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func saveQRCodeToFiles() {
        guard let image = qrCodeImage else { return }

        // Sauvegarder dans la galerie photos
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

        // TODO: Ajouter une confirmation visuelle
        // Pour l'instant, ça sauvegarde directement dans Photos
    }
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

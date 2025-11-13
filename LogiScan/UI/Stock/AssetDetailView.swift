//
//  AssetDetailView.swift
//  LogiScan
//
//  Created by Demeulemeester on 02/10/2025.
//

import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct AssetDetailView: View {
    @Bindable var asset: Asset
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var qrCodeImage: UIImage?
    @State private var showingShareSheet = false
    @State private var editingComments = false
    @State private var editingTags = false
    @State private var showingTagPicker = false
    @State private var showingStatusPicker = false
    @State private var showingMaintenancePicker = false
    @State private var selectedStatus: AssetStatus
    @State private var selectedMaintenanceDate: Date = Date()
    
    // Variables pour tracker l'état initial et détecter les modifications
    @State private var initialStatus: AssetStatus
    @State private var initialComments: String
    @State private var initialTags: [String]
    @State private var initialLocation: String?
    @State private var initialMaintenanceDate: Date?

    @Query private var stockItems: [StockItem]
    @Query private var allAssets: [Asset]
    @StateObject private var syncManager = SyncManager()
    
    init(asset: Asset) {
        self._asset = Bindable(wrappedValue: asset)
        self._selectedStatus = State(initialValue: asset.status)
        self._initialStatus = State(initialValue: asset.status)
        self._initialComments = State(initialValue: asset.comments)
        self._initialTags = State(initialValue: asset.tags)
        self._initialLocation = State(initialValue: asset.currentLocationId)
        self._initialMaintenanceDate = State(initialValue: asset.nextMaintenanceDate)
    }
    
    // Computed property pour vérifier si des modifications ont été faites
    var hasChanges: Bool {
        selectedStatus != initialStatus ||
        asset.comments != initialComments ||
        asset.tags != initialTags ||
        asset.currentLocationId != initialLocation ||
        asset.nextMaintenanceDate != initialMaintenanceDate
    }

    var relatedStockItem: StockItem? {
        stockItems.first { $0.sku == asset.sku }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                // Header avec QR Code
                VStack(spacing: 16) {
                        // QR Code
                        if let qrImage = qrCodeImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 4)
                        }

                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 40))
                            .foregroundColor(selectedStatus.swiftUIColor)

                        Text(asset.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("Référence: \(asset.assetId)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let serialNumber = asset.serialNumber {
                            Text("S/N: \(serialNumber)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Boutons partage et impression
                        HStack(spacing: 12) {
                            Button {
                                showingShareSheet = true
                            } label: {
                                Label("Partager", systemImage: "square.and.arrow.up")
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button {
                                printQRCode()
                            } label: {
                                Label("Imprimer", systemImage: "printer")
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding()

                    // Status badge
                    HStack(spacing: 8) {
                        Image(systemName: selectedStatus.icon)
                            .font(.title3)
                        Text(selectedStatus.displayName)
                            .font(.headline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedStatus.swiftUIColor.opacity(0.2))
                    )
                    .foregroundColor(selectedStatus.swiftUIColor)

                    // Commentaires - ÉDITABLE DIRECTEMENT
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "text.bubble.fill")
                                .foregroundColor(.blue)
                            Text("comments".localized())
                                .font(.headline)

                            Spacer()

                            Button(editingComments ? "Terminer" : "Modifier") {
                                editingComments.toggle()
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }

                        if editingComments {
                            TextEditor(text: $asset.comments)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            if asset.comments.isEmpty {
                                Text("no_comments".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                Text(asset.comments)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)

                    // Étiquettes - ÉDITABLE DIRECTEMENT
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.orange)
                            Text("labels".localized())
                                .font(.headline)

                            Spacer()

                            Button(editingTags ? "Terminer" : "Modifier") {
                                if editingTags {
                                    // Sauvegarder les changements
                                    editingTags = false
                                } else {
                                    editingTags = true
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }

                        if editingTags {
                            Button {
                                showingTagPicker = true
                            } label: {
                                Label("Ajouter des étiquettes", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }

                        if asset.tags.isEmpty {
                            Text("no_labels".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(asset.tags, id: \.self) { tag in
                                    HStack(spacing: 6) {
                                        Text(tag)
                                            .font(.caption)

                                        if editingTags {
                                            Button {
                                                removeTag(tag)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.green.opacity(0.15))
                                    )
                                    .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)

                    // Infos de base
                    VStack(alignment: .leading, spacing: 16) {
                        Text("info".localized())
                            .font(.headline)

                        // Status
                        HStack {
                            Image(systemName: selectedStatus.icon)
                                .foregroundColor(selectedStatus.swiftUIColor)
                            Text("Statut:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(selectedStatus.displayName)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }

                        // Localisation actuelle
                        if let location = asset.currentLocationId {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Localisation:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(location)
                                    .fontWeight(.medium)
                            }
                        } else {
                            HStack {
                                Image(systemName: "mappin.slash.circle")
                                    .foregroundColor(.gray)
                                Text("Localisation:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("not_defined".localized())
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.green)
                            Text("SKU:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(asset.sku)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.orange)
                            Text("Catégorie:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(asset.category)
                                .fontWeight(.medium)
                        }

                        Divider()

                        // Date de dernière maintenance
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.orange)
                            Text("Dernière maintenance:")
                                .foregroundColor(.secondary)
                            Spacer()
                            if let lastMaintenance = asset.lastMaintenanceDate {
                                Text(lastMaintenance.formatted(date: .abbreviated, time: .omitted))
                                    .fontWeight(.medium)
                            } else {
                                Text("never".localized())
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Date de prochaine maintenance
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(asset.needsMaintenance ? .red : .blue)
                            Text("Prochaine maintenance:")
                                .foregroundColor(.secondary)
                            Spacer()
                            if let nextMaintenance = asset.nextMaintenanceDate {
                                Text(nextMaintenance.formatted(date: .abbreviated, time: .omitted))
                                    .fontWeight(.medium)
                                    .foregroundColor(asset.needsMaintenance ? .red : .primary)
                            } else {
                                Text("not_planned".localized())
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        HStack {
                            Image(systemName: "scalemass.fill")
                                .foregroundColor(.purple)
                            Text("Poids:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f kg", asset.weight))
                                .fontWeight(.medium)
                        }

                        HStack {
                            Image(systemName: "cube.fill")
                                .foregroundColor(.indigo)
                            Text("Volume:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.3f m³", asset.volume))
                                .fontWeight(.medium)
                        }

                        HStack {
                            Image(systemName: "eurosign.circle.fill")
                                .foregroundColor(.green)
                            Text("Valeur:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f €", asset.value))
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)

                    // Section 5 : Actions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Actions")
                            .font(.headline)

                        // Modifier le statut
                        Button {
                            showingStatusPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.blue)
                                Text("Modifier le statut")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                            )
                        }

                        // Planifier une maintenance
                        Button {
                            showingMaintenancePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(.orange)
                                Text("Planifier une maintenance")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Détail référence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        // Annuler les modifications en rechargeant depuis le contexte
                        modelContext.rollback()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Sauvegarder") {
                        // Appliquer le statut sélectionné
                        asset.status = selectedStatus
                        
                        // Sauvegarder les modifications
                        asset.updatedAt = Date()
                        try? modelContext.save()
                        
                        // Synchroniser avec Firebase
                        Task {
                            await syncManager.updateAssetInFirebase(asset)
                            
                            // Recalculer les quantités du StockItem parent
                            if let stockItem = relatedStockItem {
                                await syncManager.recalculateStockItemQuantities(
                                    stockItem: stockItem,
                                    assets: allAssets,
                                    modelContext: modelContext
                                )
                            }
                        }
                        
                        dismiss()
                    }
                    .disabled(!hasChanges)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let qrImage = qrCodeImage {
                    ShareSheet(items: [qrImage])
                }
            }
            .sheet(isPresented: $showingTagPicker) {
                UnifiedTagPickerView(
                    category: asset.category,
                    selectedTags: $asset.tags
                )
            }
            .sheet(isPresented: $showingStatusPicker) {
                NavigationView {
                    StatusPickerView(
                        selectedStatus: $selectedStatus,
                        onSave: { newStatus in
                            selectedStatus = newStatus
                            // Ne PAS sauvegarder ici, juste mettre à jour la sélection
                            // La sauvegarde se fera avec le bouton "Sauvegarder"
                        }
                    )
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingMaintenancePicker) {
                NavigationView {
                    MaintenanceSchedulerView(
                        selectedDate: $selectedMaintenanceDate,
                        onSave: {
                            asset.nextMaintenanceDate = selectedMaintenanceDate
                            asset.updatedAt = Date()
                            try? modelContext.save()
                        }
                    )
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                generateQRCode()
            }
            .navigationTitle("Détail référence")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Fonctions
    
    func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        // 🆕 Utiliser le format JSON moderne pour la cohérence
        let qrPayload = """
        {
            "v": 1,
            "type": "asset",
            "id": "\(asset.assetId)",
            "sku": "\(asset.sku)",
            "sn": "\(asset.serialNumber ?? "")"
        }
        """

        filter.message = Data(qrPayload.utf8)

        if let outputImage = filter.outputImage {
            // Upscale pour meilleure qualité
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }

    func printQRCode() {
        guard let qrImage = qrCodeImage else { return }

        // Créer un renderer PDF personnalisé
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        printInfo.jobName = "QR Code - \(asset.assetId)"

        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo

        // Créer un renderer personnalisé pour positionner le QR code
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))  // A4 en points

        let data = renderer.pdfData { context in
            context.beginPage()

            // Position en haut à gauche avec une petite marge (10mm = ~28 points)
            let margin: CGFloat = 28

            // 5cm = ~142 points (1cm = 28.35 points)
            let qrSize: CGFloat = 142

            // Dessiner le QR code
            let qrRect = CGRect(x: margin, y: margin, width: qrSize, height: qrSize)
            qrImage.draw(in: qrRect)

            // Ajouter des informations en dessous du QR code
            let textY = margin + qrSize + 10

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .paragraphStyle: paragraphStyle,
            ]

            let info = """
                \(asset.assetId)
                S/N: \(asset.serialNumber ?? "N/A")
                SKU: \(asset.sku)
                """

            info.draw(
                in: CGRect(x: margin, y: textY, width: 200, height: 50), withAttributes: attributes)
        }

        printController.printingItem = data
        printController.present(animated: true)
    }

    func removeTag(_ tag: String) {
        asset.tags.removeAll { $0 == tag }
    }
}

// MARK: - Status Picker View

struct StatusPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStatus: AssetStatus
    let onSave: (AssetStatus) -> Void
    
    @State private var temporaryStatus: AssetStatus
    
    init(selectedStatus: Binding<AssetStatus>, onSave: @escaping (AssetStatus) -> Void) {
        self._selectedStatus = selectedStatus
        self.onSave = onSave
        self._temporaryStatus = State(initialValue: selectedStatus.wrappedValue)
    }
    
    var body: some View {
        List {
            Section {
                ForEach(AssetStatus.allCases, id: \.self) { status in
                    Button {
                        temporaryStatus = status
                    } label: {
                        HStack {
                            Image(systemName: status.icon)
                                .foregroundColor(Color(status.color))
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(status.displayName)
                                    .foregroundColor(.primary)
                                    .fontWeight(temporaryStatus == status ? .semibold : .regular)
                                
                                Text(statusDescription(for: status))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if temporaryStatus == status {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("Sélectionnez un statut")
            } footer: {
                Text("Le statut sera mis à jour immédiatement après validation")
                    .font(.caption)
            }
        }
        .navigationTitle("Modifier le statut")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Valider") {
                    onSave(temporaryStatus)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
    
    private func statusDescription(for status: AssetStatus) -> String {
        switch status {
        case .available:
            return "Prêt à être utilisé ou expédié"
        case .reserved:
            return "Réservé pour une commande ou un événement"
        case .inUse:
            return "Actuellement en utilisation"
        case .inTransitToEvent:
            return "En cours de transport vers l'événement"
        case .inTransitToStock:
            return "En cours de retour vers le stock"
        case .damaged:
            return "Endommagé, nécessite une réparation"
        case .maintenance:
            return "En cours de maintenance"
        case .lost:
            return "Perdu ou manquant à l'inventaire"
        }
    }
}

// MARK: - Maintenance Scheduler View

struct MaintenanceSchedulerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    let onSave: () -> Void
    
    @State private var includeTime = false
    
    var body: some View {
        Form {
            Section {
                DatePicker(
                    "Date de maintenance",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date]
                )
                .datePickerStyle(.graphical)
                
                Toggle("Inclure l'heure", isOn: $includeTime)
            } header: {
                Text("planning".localized())
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("La maintenance sera planifiée pour le:")
                        .font(.caption)
                    Text(selectedDate.formatted(date: .long, time: includeTime ? .shortened : .omitted))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            Section {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                    Text("advice".localized())
                        .fontWeight(.semibold)
                }
                
                Text("Planifiez les maintenances régulières pour prolonger la durée de vie de vos équipements et éviter les pannes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Planifier maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Planifier") {
                    onSave()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Asset.self, configurations: config)

    let sampleAsset = Asset(
        assetId: "LED-50W-001",
        sku: "LED-SPOT-50W",
        name: "Projecteur LED 50W",
        category: "Éclairage",
        serialNumber: "SN-2025-001",
        status: .available,
        weight: 2.5,
        volume: 0.01,
        value: 150.0,
        qrPayload: "LED-50W-001",
        comments: "Boîtier légèrement griffé sur le côté gauche, mais fonctionne parfaitement.",
        tags: ["LED", "50W", "Extérieur", "Urgent"]
    )
    sampleAsset.currentLocationId = "Entrepôt A - Zone 3"

    container.mainContext.insert(sampleAsset)

    return AssetDetailView(asset: sampleAsset)
        .modelContainer(container)
}

//
//  StockItemDetailView.swift
//  LogiScan
//
//  Created by Demeulemeester on 01/10/2025.
//

import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct StockItemDetailView: View {
    @Bindable var stockItem: StockItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingTagEditor = false
    @State private var showingLocationHistory = false
    @State private var showingEditForm = false
    @State private var showingQuantityAdjustment = false
    @State private var showingQRBatchPDF = false
    @State private var selectedAsset: Asset?
    @State private var showingDeleteAlert = false
    @State private var showingAssetsList = false

    @Query private var assets: [Asset]
    @Query private var movements: [Movement]

    var filteredAssets: [Asset] {
        assets.filter { $0.sku == stockItem.sku }
    }

    var relatedMovements: [Movement] {
        movements.filter { $0.sku == stockItem.sku }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Photo + Infos de base (titre, SKU, type, loc/prop)
                    HeaderSectionView(stockItem: stockItem)

                    // 2. Références individuelles
                    SerializedAssetsSectionView(
                        stockItem: stockItem,
                        assets: Array(filteredAssets.prefix(5)),
                        totalAssetsCount: filteredAssets.count,
                        showingQRBatchPDF: $showingQRBatchPDF,
                        selectedAsset: $selectedAsset,
                        showingAssetsList: $showingAssetsList
                    )

                    // 3. Disponibilité
                    AvailabilitySectionView(stockItem: stockItem)

                    // 4. Mouvements récents
                    MovementHistorySectionView(
                        movements: Array(relatedMovements.prefix(5)),
                        showingLocationHistory: $showingLocationHistory
                    )

                    // 5. Étiquettes
                    TagsSectionView(
                        stockItem: stockItem,
                        showingTagEditor: $showingTagEditor
                    )

                    // 6. Actions rapides
                    QuickActionsView(
                        showingQuantityAdjustment: $showingQuantityAdjustment,
                        showingEditForm: $showingEditForm
                    )

                    // 7. Détails techniques
                    DetailsSectionView(stockItem: stockItem)

                    // 8. Description / Commentaires
                    if !stockItem.itemDescription.isEmpty {
                        CommentsSectionView(description: stockItem.itemDescription)
                    }
                }
                .padding()
            }
            .navigationTitle(stockItem.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Modifier l'article", systemImage: "pencil") {
                            showingEditForm = true
                        }

                        Button("Modifier les étiquettes", systemImage: "tag") {
                            showingTagEditor = true
                        }

                        Button("Historique complet", systemImage: "clock") {
                            showingLocationHistory = true
                        }

                        Divider()

                        Button("Supprimer l'article", systemImage: "trash", role: .destructive) {
                            showingDeleteAlert = true
                        }

                        Divider()

                        Button("Créer mouvement", systemImage: "arrow.left.arrow.right") {
                            // TODO: Navigation vers création de mouvement
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            // Removed QR generation for group
        }
        .sheet(isPresented: $showingEditForm) {
            StockItemFormView(editingItem: stockItem)
        }
        .sheet(isPresented: $showingTagEditor) {
            TagEditorView(stockItem: stockItem)
        }
        .sheet(isPresented: $showingLocationHistory) {
            LocationHistoryView(sku: stockItem.sku)
        }
        .sheet(isPresented: $showingQuantityAdjustment) {
            QuantityAdjustmentSheet(stockItem: stockItem, adjustmentType: .total)
        }
        .sheet(isPresented: $showingQRBatchPDF) {
            QRBatchPDFView(assets: filteredAssets, stockItem: stockItem)
        }
        .sheet(item: $selectedAsset) { asset in
            AssetDetailView(asset: asset)
        }
        .sheet(isPresented: $showingAssetsList) {
            AssetsListView(assets: filteredAssets, selectedAsset: $selectedAsset)
        }
        .alert("Supprimer cet article ?", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                deleteStockItem()
            }
        } message: {
            if filteredAssets.isEmpty {
                Text(
                    "Cette action est irréversible. L'article \(stockItem.sku) sera définitivement supprimé."
                )
            } else {
                Text(
                    "Cet article contient \(filteredAssets.count) référence(s). Toutes les références associées seront également supprimées. Cette action est irréversible."
                )
            }
        }
    }

    // MARK: - Fonctions

    func deleteStockItem() {
        // Supprimer toutes les références associées
        for asset in filteredAssets {
            modelContext.delete(asset)
        }

        // Supprimer le StockItem
        modelContext.delete(stockItem)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Header Section

struct HeaderSectionView: View {
    let stockItem: StockItem

    var body: some View {
        VStack(spacing: 16) {
            // Image de l'article (placeholder pour l'instant)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("Photo de l'article")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )

            VStack(spacing: 12) {
                // Badge de propriété en haut
                HStack(spacing: 8) {
                    Image(systemName: stockItem.ownershipType.icon)
                        .font(.caption)
                    Text(stockItem.ownershipType.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            stockItem.ownershipType == .owned
                                ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                )
                .foregroundColor(stockItem.ownershipType == .owned ? .green : .orange)

                Text(stockItem.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("SKU: \(stockItem.sku)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(stockItem.category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.2))
                    )
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Comments Section

struct CommentsSectionView: View {
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description / Commentaires")
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Tags Section

struct TagsSectionView: View {
    let stockItem: StockItem
    @Binding var showingTagEditor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Étiquettes")
                    .font(.headline)

                Spacer()

                Button("Modifier") {
                    showingTagEditor = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }

            if stockItem.tags.isEmpty {
                Text("Aucune étiquette")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 80), spacing: 8)
                    ], spacing: 8
                ) {
                    ForEach(stockItem.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.green.opacity(0.2))
                            )
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Details Section

struct DetailsSectionView: View {
    let stockItem: StockItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Détails techniques")
                .font(.headline)

            VStack(spacing: 12) {
                // Dimensions
                if let dimensions = stockItem.dimensions {
                    DetailRow(
                        title: "Dimensions",
                        value: dimensions.displayString,
                        icon: "ruler"
                    )
                    DetailRow(
                        title: "Volume calculé",
                        value: String(format: "%.3f m³", dimensions.volumeInM3)
                    )
                }

                DetailRow(
                    title: "Poids unitaire",
                    value: String(format: "%.2f kg", stockItem.unitWeight),
                    icon: "scalemass"
                )

                if stockItem.dimensions == nil {
                    DetailRow(
                        title: "Volume unitaire",
                        value: String(format: "%.3f m³", stockItem.unitVolume),
                        icon: "cube"
                    )
                }

                // Consommation électrique
                if let power = stockItem.powerConsumption {
                    DetailRow(
                        title: "Consommation",
                        value: String(format: "%.0f W", power),
                        icon: "bolt.fill"
                    )
                }

                Divider()

                // Tarification
                DetailRow(
                    title: "Valeur unitaire",
                    value: String(format: "%.2f €", stockItem.unitValue),
                    icon: "eurosign.circle"
                )

                if let purchasePrice = stockItem.purchasePrice {
                    DetailRow(
                        title: "Prix d'achat",
                        value: String(format: "%.2f €", purchasePrice),
                        icon: "cart"
                    )
                }

                if let rentalPrice = stockItem.rentalPrice {
                    DetailRow(
                        title: "Prix location/jour",
                        value: String(format: "%.2f €", rentalPrice),
                        icon: "calendar"
                    )
                }

                // Description technique
                if !stockItem.itemDescription.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Description technique")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }

                        Text(stockItem.itemDescription)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Spécifications techniques supplémentaires
                if !stockItem.technicalSpecs.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Spécifications")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }

                        ForEach(Array(stockItem.technicalSpecs.keys.sorted()), id: \.self) { key in
                            if let value = stockItem.technicalSpecs[key] {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.caption)
                                    Text("\(key):")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(value)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Articles substituables
                if !stockItem.substituables.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Articles substituables")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }

                        ForEach(stockItem.substituables, id: \.self) { sku in
                            Text("• \(sku)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var icon: String? = nil

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Availability Section

struct AvailabilitySectionView: View {
    let stockItem: StockItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Disponibilité")
                .font(.headline)

            HStack(spacing: 24) {
                AvailabilityCard(
                    title: "Total",
                    count: stockItem.totalQuantity,
                    color: .blue
                )

                AvailabilityCard(
                    title: "Disponible",
                    count: stockItem.availableQuantity,
                    color: stockItem.availableQuantity > 0 ? .green : .red
                )

                if stockItem.maintenanceQuantity > 0 {
                    AvailabilityCard(
                        title: "Maintenance",
                        count: stockItem.maintenanceQuantity,
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct AvailabilityCard: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Serialized Assets Section

struct SerializedAssetsSectionView: View {
    let stockItem: StockItem
    let assets: [Asset]
    let totalAssetsCount: Int
    @Binding var showingQRBatchPDF: Bool
    @Binding var selectedAsset: Asset?
    @Binding var showingAssetsList: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cube.box")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("Références individuelles (\(totalAssetsCount))")
                    .font(.headline)

                Spacer()

                // Bouton "Voir le détail des unités"
                Button {
                    showingAssetsList = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Voir détail")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "list.bullet")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Boutons d'action
            HStack(spacing: 10) {
                Button {
                    showingQRBatchPDF = true
                } label: {
                    Label("Voir les QR Codes", systemImage: "qrcode.viewfinder")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    // TODO: Ajouter une référence
                } label: {
                    Label("Ajouter", systemImage: "plus")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
            }

            Divider()

            // Message si aucun asset
            if assets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cube.box")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("Aucune référence individuelle")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(
                        "Créez des références pour suivre chaque unité individuellement avec son propre QR code"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Liste des assets (5 premiers) - Cliquables
                LazyVStack(spacing: 12) {
                    ForEach(assets, id: \.assetId) { asset in
                        Button {
                            selectedAsset = asset
                        } label: {
                            AssetRow(stockItem: stockItem, asset: asset)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Bouton "Afficher les X autres" si plus de 5
            if totalAssetsCount > 5 {
                Button {
                    // TODO: Navigation vers liste complète
                } label: {
                    HStack {
                        Text("Afficher les \(assets.count - 5) autres")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct AssetRow: View {
    let stockItem: StockItem
    let asset: Asset
    @State private var showingQRCode = false

    // Computed property pour obtenir la couleur du statut
    private var statusColor: Color {
        switch asset.status {
        case .available: return .green
        case .reserved: return .blue
        case .inUse: return .purple
        case .damaged: return .red
        case .maintenance: return .orange
        case .lost: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Première ligne : Nom complet + Badge de statut
            HStack(alignment: .center, spacing: 8) {
                Text(stockItem.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Badge de statut
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(asset.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
                .foregroundColor(statusColor)
            }

            // Deuxième ligne : SKU + Réf + S/N
            HStack(spacing: 8) {
                Text(stockItem.sku)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)

                Text("•")
                    .foregroundColor(.secondary)
                    .font(.caption2)

                Text("Réf: \(asset.assetId)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let serialNumber = asset.serialNumber {
                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                    Text("S/N: \(serialNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.top, 4)

            // Troisième ligne : Localisation + Bouton QR
            HStack {
                if let location = asset.currentLocationId {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Bouton QR
                Button {
                    showingQRCode = true
                } label: {
                    Image(systemName: "qrcode")
                        .font(.body)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .sheet(isPresented: $showingQRCode) {
            AssetQRCodeView(stockItem: stockItem, asset: asset)
        }
    }
}

// MARK: - Asset QR Code View

struct AssetQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let stockItem: StockItem
    let asset: Asset
    @State private var qrCodeImage: UIImage?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Informations de l'article
                VStack(spacing: 8) {
                    Text(stockItem.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("SKU: \(stockItem.sku)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Référence: \(asset.assetId)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let serialNumber = asset.serialNumber {
                        Text("S/N: \(serialNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // QR Code
                if let qrImage = qrCodeImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 4)
                        )
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }

                Spacer()

                // Boutons d'action
                VStack(spacing: 12) {
                    Button(action: shareQRCode) {
                        Label("Partager le QR Code", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(qrCodeImage == nil)

                    Button(action: saveQRCodeToFiles) {
                        Label("Enregistrer dans Photos", systemImage: "arrow.down.doc")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(qrCodeImage == nil)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
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
                "type": "asset",
                "assetId": "\(asset.assetId)",
                "stockSku": "\(stockItem.sku)",
                "name": "\(stockItem.name)",
                "serialNumber": "\(asset.serialNumber ?? "")"
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
            activityItems: [image, "QR Code: \(stockItem.name) - \(asset.assetId)"],
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
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}

// MARK: - Movement History Section

struct MovementHistorySectionView: View {
    let movements: [Movement]
    @Binding var showingLocationHistory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Mouvements récents")
                    .font(.headline)

                Spacer()

                Button("Historique complet") {
                    showingLocationHistory = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }

            if movements.isEmpty {
                Text("Aucun mouvement enregistré")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(movements, id: \.movementId) { movement in
                        MovementRowCompact(movement: movement)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct MovementRowCompact: View {
    let movement: Movement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: movement.type.icon)
                .font(.title3)
                .foregroundColor(Color(movement.type.color))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(movement.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    if let fromLocation = movement.fromLocationId {
                        Text(fromLocation)
                    }

                    if movement.fromLocationId != nil && movement.toLocationId != nil {
                        Text("→")
                    }

                    if let toLocation = movement.toLocationId {
                        Text(toLocation)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Qty: \(movement.quantity)")
                    .font(.caption)
                    .fontWeight(.medium)

                Text(movement.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Quick Actions View

struct QuickActionsView: View {
    @Binding var showingQuantityAdjustment: Bool
    @Binding var showingEditForm: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions rapides")
                .font(.headline)

            HStack(spacing: 12) {
                // Ajouter unités
                Button {
                    showingQuantityAdjustment = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)

                        Text("Ajouter\nunités")
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                    )
                }
                .buttonStyle(.plain)

                // Supprimer unités
                Button {
                    // TODO: Ouvrir sheet pour supprimer
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)

                        Text("Supprimer\nunités")
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                    )
                }
                .buttonStyle(.plain)

                // Modifier infos
                Button {
                    showingEditForm = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)

                        Text("Modifier\ninfos")
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                    )
                }
                .buttonStyle(.plain)

                // Menu
                Menu {
                    Button("Gérer la maintenance", systemImage: "wrench.and.screwdriver") {
                        // TODO: Action maintenance
                    }

                    Button("Voir historique complet", systemImage: "clock") {
                        // TODO: Navigation historique
                    }

                    Button("Exporter les données", systemImage: "square.and.arrow.up") {
                        // TODO: Export
                    }

                    Divider()

                    Button("Supprimer l'article", systemImage: "trash", role: .destructive) {
                        // TODO: Confirmation suppression
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)

                        Text("Menu")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Quantity Adjustment Sheet

enum QuantityAdjustmentType {
    case total
    case maintenance

    var title: String {
        switch self {
        case .total: return "Ajuster le stock"
        case .maintenance: return "Gérer la maintenance"
        }
    }

    var icon: String {
        switch self {
        case .total: return "plus.minus.circle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        }
    }
}

struct QuantityAdjustmentSheet: View {
    @Bindable var stockItem: StockItem
    let adjustmentType: QuantityAdjustmentType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var adjustmentQuantity: String = ""
    @State private var isAdding: Bool = true
    @State private var reason: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stockItem.name)
                                .font(.headline)
                            Text("SKU: \(stockItem.sku)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "cube.box.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }

                Section {
                    if adjustmentType == .total {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Stock actuel:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(stockItem.totalQuantity)")
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Text("Disponible:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(stockItem.availableQuantity)")
                                    .fontWeight(.semibold)
                                    .foregroundColor(
                                        stockItem.availableQuantity > 0 ? .green : .red)
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            HStack {
                                Text("En maintenance:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(stockItem.maintenanceQuantity)")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }

                            HStack {
                                Text("Disponible:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(stockItem.availableQuantity)")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                } header: {
                    Text("État actuel")
                }

                Section {
                    if adjustmentType == .total {
                        Picker("Action", selection: $isAdding) {
                            Text("Ajouter").tag(true)
                            Text("Retirer").tag(false)
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Picker("Action", selection: $isAdding) {
                            Text("Vers maintenance").tag(true)
                            Text("Depuis maintenance").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        Text("Quantité")
                        Spacer()
                        TextField("0", text: $adjustmentQuantity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    TextField("Raison (optionnel)", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Ajustement")
                }

                if let quantity = Int(adjustmentQuantity), quantity > 0 {
                    Section {
                        if adjustmentType == .total {
                            HStack {
                                Text("Nouveau stock total:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(
                                    "\(isAdding ? stockItem.totalQuantity + quantity : max(0, stockItem.totalQuantity - quantity))"
                                )
                                .fontWeight(.bold)
                                .foregroundColor(isAdding ? .green : .red)
                            }
                        } else {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("En maintenance:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(
                                        "\(isAdding ? stockItem.maintenanceQuantity + quantity : max(0, stockItem.maintenanceQuantity - quantity))"
                                    )
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                }

                                HStack {
                                    Text("Disponible:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(
                                        "\(isAdding ? max(0, stockItem.availableQuantity - quantity) : stockItem.availableQuantity + quantity)"
                                    )
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                }
                            }
                        }
                    } header: {
                        Text("Aperçu")
                    }
                }
            }
            .navigationTitle(adjustmentType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        applyAdjustment()
                    }
                    .disabled(!canApply)
                }
            }
        }
    }

    var canApply: Bool {
        guard let quantity = Int(adjustmentQuantity), quantity > 0 else {
            return false
        }

        if adjustmentType == .total {
            // Si on retire, vérifier qu'on ne va pas en négatif
            if !isAdding && quantity > stockItem.totalQuantity {
                return false
            }
        } else {
            // Vers maintenance : besoin de stock disponible
            if isAdding && quantity > stockItem.availableQuantity {
                return false
            }
            // Depuis maintenance : besoin de stock en maintenance
            if !isAdding && quantity > stockItem.maintenanceQuantity {
                return false
            }
        }

        return true
    }

    func applyAdjustment() {
        guard let quantity = Int(adjustmentQuantity), quantity > 0 else {
            return
        }

        if adjustmentType == .total {
            if isAdding {
                stockItem.totalQuantity += quantity
            } else {
                stockItem.totalQuantity = max(0, stockItem.totalQuantity - quantity)
                // Si on retire plus que le disponible, réduire aussi la maintenance
                let exceeds = quantity - stockItem.availableQuantity
                if exceeds > 0 {
                    stockItem.maintenanceQuantity = max(0, stockItem.maintenanceQuantity - exceeds)
                }
            }
        } else {
            if isAdding {
                // Vers maintenance
                let toMove = min(quantity, stockItem.availableQuantity)
                stockItem.maintenanceQuantity += toMove
            } else {
                // Depuis maintenance
                let toMove = min(quantity, stockItem.maintenanceQuantity)
                stockItem.maintenanceQuantity -= toMove
            }
        }

        stockItem.updatedAt = Date()

        // TODO: Créer un Movement pour tracer cette opération

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sampleItem = StockItem(
        sku: "LED-SPOT-50W",
        name: "Projecteur LED 50W",
        category: "Éclairage",
        itemDescription:
            "Projecteur LED haute performance avec dissipateur thermique en aluminium. Résistant à l'eau (IP65) pour usage extérieur.",
        totalQuantity: 25,
        unitWeight: 2.5,
        unitVolume: 0.01,
        unitValue: 150.0,
        tags: ["LED", "Éclairage", "50W", "Extérieur"],
        ownershipType: .owned,
        purchasePrice: 120.0,
        dimensions: Dimensions(length: 30, width: 25, height: 15),
        powerConsumption: 50.0,
        technicalSpecs: [
            "Voltage": "220-240V AC",
            "Température couleur": "6000K (blanc froid)",
            "Indice de protection": "IP65",
            "Angle d'éclairage": "120°",
        ]
    )

    StockItemDetailView(stockItem: sampleItem)
        .modelContainer(for: [StockItem.self, Asset.self, Movement.self], inMemory: true)
}

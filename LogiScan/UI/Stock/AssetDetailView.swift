//
//  AssetDetailView.swift
//  LogiScan
//
//  Created by Demeulemeester on 02/10/2025.
//

import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI
import UIKit

struct AssetDetailView: View {
    @Bindable var asset: Asset
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var qrCodeImage: UIImage?
    @State private var showingShareSheet = false
    @State private var showingDeleteAlert = false
    @State private var editingComments = false
    @State private var editingTags = false
    @State private var newTag = ""

    @Query private var stockItems: [StockItem]

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
                            .foregroundColor(Color(asset.status.color))

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
                        Text(asset.status.icon)
                            .font(.title3)
                        Text(asset.status.displayName)
                            .font(.headline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(asset.status.color).opacity(0.2))
                    )
                    .foregroundColor(Color(asset.status.color))

                    // Commentaires - ÉDITABLE DIRECTEMENT
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "text.bubble.fill")
                                .foregroundColor(.blue)
                            Text("Commentaires")
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
                                Text("Aucun commentaire")
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
                            Text("Étiquettes")
                                .font(.headline)

                            Spacer()

                            Button(editingTags ? "Terminer" : "Modifier") {
                                editingTags.toggle()
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }

                        if editingTags {
                            // Champ d'ajout
                            HStack {
                                TextField("Nouvelle étiquette", text: $newTag)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    addTag()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }

                        if asset.tags.isEmpty {
                            Text("Aucune étiquette")
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
                                            .fill(Color.blue.opacity(0.2))
                                    )
                                    .foregroundColor(.blue)
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
                        Text("Informations")
                            .font(.headline)

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
                        }

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
                }
                .padding(.vertical)
            }
            .navigationTitle("Détail référence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Modifier statut", systemImage: "arrow.triangle.2.circlepath") {
                            // TODO: Changer le statut
                        }

                        Divider()

                        Button("Supprimer la référence", systemImage: "trash", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Supprimer cette référence ?", isPresented: $showingDeleteAlert) {
                Button("Annuler", role: .cancel) {}
                Button("Supprimer", role: .destructive) {
                    deleteAsset()
                }
            } message: {
                Text(
                    "Cette action est irréversible. La référence \(asset.assetId) sera définitivement supprimée."
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                if let qrImage = qrCodeImage {
                    ShareSheet(items: [qrImage])
                }
            }
            .onAppear {
                generateQRCode()
            }
        }
    }

    // MARK: - Fonctions

    func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        // Payload: Asset ID + Numéro de série + SKU
        var payload = "ASSET:\(asset.assetId)"
        if let serialNumber = asset.serialNumber {
            payload += "|SN:\(serialNumber)"
        }
        payload += "|SKU:\(asset.sku)"

        filter.message = Data(payload.utf8)

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

    func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmedTag.isEmpty, !asset.tags.contains(trimmedTag) else { return }

        asset.tags.append(trimmedTag)
        newTag = ""
    }

    func removeTag(_ tag: String) {
        asset.tags.removeAll { $0 == tag }
    }

    func deleteAsset() {
        // Si l'asset fait partie d'un groupe (StockItem), décrémenter la quantité
        if let stockItem = relatedStockItem {
            stockItem.totalQuantity -= 1
            stockItem.updatedAt = Date()
        }

        modelContext.delete(asset)
        try? modelContext.save()
        dismiss()
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

//
//  QRBatchPDFView.swift
//  LogiScan
//
//  Created by Demeulemeester on 02/10/2025.
//

import CoreImage.CIFilterBuiltins
import PDFKit
import SwiftData
import SwiftUI
import UIKit

struct QRBatchPDFView: View {
    let assets: [Asset]
    let stockItem: StockItem

    @Environment(\.dismiss) private var dismiss
    @State private var generatedPDF: PDFDocument?
    @State private var isGenerating = false
    @State private var showShareSheet = false
    @State private var pdfURL: URL?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Génération du PDF en cours...")
                            .font(.headline)
                        Text("\(assets.count) QR codes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pdf = generatedPDF {
                    // Preview du PDF
                    PDFKitView(document: pdf)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Configuration avant génération
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)

                                Text("Génération PDF des QR Codes")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text("\(assets.count) références pour \(stockItem.name)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()

                            // Infos
                            VStack(alignment: .leading, spacing: 16) {
                                InfoRow(title: "Article", value: stockItem.name)
                                InfoRow(title: "SKU", value: stockItem.sku)
                                InfoRow(title: "Catégorie", value: stockItem.category)
                                InfoRow(title: "Nombre de références", value: "\(assets.count)")
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                            .padding(.horizontal)

                            // Options
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Format")
                                    .font(.headline)

                                Text("• Format A4 paysage")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("• 6 QR codes par page (3×2)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("• Chaque QR code inclut: Asset ID, Numéro de série, SKU")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                            .padding(.horizontal)

                            // Bouton de génération
                            Button {
                                generatePDF()
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                    Text("Générer le PDF")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("QR Codes PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }

                if generatedPDF != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Partager") {
                            sharePDF()
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    func generatePDF() {
        isGenerating = true

        Task {
            // Générer le PDF avec les QR codes
            let pdfDocument = PDFDocument()

            // Configuration de la page A4 paysage
            let pageWidth: CGFloat = 842  // A4 landscape width in points
            let pageHeight: CGFloat = 595  // A4 landscape height in points

            let margin: CGFloat = 28  // ~10mm
            let qrSize: CGFloat = 170  // Taille du QR code
            let spacing: CGFloat = 20  // Espacement entre les QR codes

            // 3 colonnes × 2 lignes = 6 QR codes par page
            let columns = 3
            let rows = 2
            let qrCodesPerPage = columns * rows

            // Calculer le nombre de pages nécessaires
            let pageCount = Int(ceil(Double(assets.count) / Double(qrCodesPerPage)))

            for pageIndex in 0..<pageCount {
                let renderer = UIGraphicsPDFRenderer(
                    bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

                let pageData = renderer.pdfData { context in
                    context.beginPage()

                    let startIndex = pageIndex * qrCodesPerPage
                    let endIndex = min(startIndex + qrCodesPerPage, assets.count)

                    for i in startIndex..<endIndex {
                        let asset = assets[i]
                        let indexInPage = i - startIndex

                        let col = indexInPage % columns
                        let row = indexInPage / columns

                        let x = margin + CGFloat(col) * (qrSize + spacing)
                        let y = margin + CGFloat(row) * (qrSize + spacing)

                        // Générer le QR code pour cet asset
                        if let qrImage = generateQRCodeImage(for: asset) {
                            let qrRect = CGRect(x: x, y: y, width: qrSize, height: qrSize)
                            qrImage.draw(in: qrRect)

                            // Ajouter les informations sous le QR code
                            let textY = y + qrSize + 5
                            let paragraphStyle = NSMutableParagraphStyle()
                            paragraphStyle.alignment = .center

                            let attributes: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 8),
                                .paragraphStyle: paragraphStyle,
                            ]

                            let info = "\(asset.assetId)\n\(asset.serialNumber ?? "")"
                            info.draw(
                                in: CGRect(x: x, y: textY, width: qrSize, height: 30),
                                withAttributes: attributes)
                        }
                    }
                }

                // Ajouter la page au document PDF
                if let pageDocument = PDFDocument(data: pageData),
                    let page = pageDocument.page(at: 0)
                {
                    pdfDocument.insert(page, at: pdfDocument.pageCount)
                }
            }

            await MainActor.run {
                generatedPDF = pdfDocument
                isGenerating = false
            }
        }
    }

    private func generateQRCodeImage(for asset: Asset) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(asset.qrPayload.utf8)

        guard let outputImage = filter.outputImage else { return nil }

        // Upscale pour meilleure qualité
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    func sharePDF() {
        guard let pdf = generatedPDF, let data = pdf.dataRepresentation() else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "QR_Codes_\(stockItem.sku).pdf")

        do {
            try data.write(to: tempURL)
            pdfURL = tempURL
            showShareSheet = true
        } catch {
            print("Erreur lors de la préparation du PDF: \(error)")
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
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

// MARK: - Preview

#Preview {
    @Previewable @State var sampleItem = StockItem(
        sku: "LED-SPOT-50W",
        name: "Projecteur LED 50W",
        category: "Éclairage",
        totalQuantity: 25,
        unitWeight: 2.5,
        unitVolume: 0.01,
        unitValue: 150.0,
        tags: ["LED", "Éclairage"]
    )

    let sampleAssets = [
        Asset(
            assetId: "LED-50W-001",
            sku: "LED-SPOT-50W",
            name: "Projecteur LED 50W",
            category: "Éclairage",
            serialNumber: "SN001",
            status: .available,
            weight: 2.5,
            volume: 0.01,
            value: 150.0,
            qrPayload: "LED-50W-001"
        ),
        Asset(
            assetId: "LED-50W-002",
            sku: "LED-SPOT-50W",
            name: "Projecteur LED 50W",
            category: "Éclairage",
            serialNumber: "SN002",
            status: .available,
            weight: 2.5,
            volume: 0.01,
            value: 150.0,
            qrPayload: "LED-50W-002"
        ),
    ]

    QRBatchPDFView(assets: sampleAssets, stockItem: sampleItem)
        .modelContainer(for: [StockItem.self, Asset.self], inMemory: true)
}

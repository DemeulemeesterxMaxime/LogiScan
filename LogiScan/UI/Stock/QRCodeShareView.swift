//
//  QRCodeShareView.swift
//  LogiScan
//
//  Created by Demeulemeester on 01/10/2025.
//

import SwiftUI
import UIKit

struct QRCodeShareView: View {
    let qrImage: UIImage?
    let itemName: String
    let sku: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingActivitySheet = false
    @State private var showingPrintSheet = false
    
    // 5cm = ~189 points à 72 DPI (standard iOS)
    private let qrCodeSize: CGFloat = 189
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // En-tête
                VStack(spacing: 8) {
                    Text(itemName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("SKU: \(sku)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // QR Code agrandi (5cm × 5cm)
                if let qrImage = qrImage {
                    VStack(spacing: 16) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: qrCodeSize, height: qrCodeSize)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 5)
                        
                        Text("5cm × 5cm")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Scannez ce code pour accéder aux détails de l'article")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                        .frame(width: qrCodeSize, height: qrCodeSize)
                        .overlay(
                            Text("QR Code indisponible")
                                .foregroundColor(.secondary)
                        )
                }
                
                // Actions
                VStack(spacing: 16) {
                    Button(action: {
                        guard qrImage != nil else { return }
                        showingActivitySheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Partager")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(qrImage != nil ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(qrImage == nil)
                    
                    Button(action: {
                        guard qrImage != nil else { return }
                        showingPrintSheet = true
                    }) {
                        HStack {
                            Image(systemName: "printer")
                            Text("Imprimer l'étiquette")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(qrImage != nil ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(qrImage == nil)
                    
                    Button(action: {
                        guard qrImage != nil else { return }
                        saveToPhotos()
                    }) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Sauvegarder dans Photos")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(qrImage != nil ? Color.purple : Color.gray)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(qrImage == nil)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingActivitySheet) {
            ShareSheet(items: [createShareableImage()])
        }
        .sheet(isPresented: $showingPrintSheet) {
            PrintSheet(image: createPrintableLabel())
        }
    }
    
    private func createShareableImage() -> UIImage {
        guard let qrImage = qrImage else { return UIImage() }
        
        // Taille totale avec marges
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 500))
        
        return renderer.image { context in
            // Fond blanc
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 400, height: 500)))
            
            // Titre
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            
            let titleRect = CGRect(x: 20, y: 30, width: 360, height: 30)
            itemName.draw(in: titleRect, withAttributes: titleAttributes)
            
            // SKU
            let skuAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.gray
            ]
            
            let skuRect = CGRect(x: 20, y: 65, width: 360, height: 20)
            "SKU: \(sku)".draw(in: skuRect, withAttributes: skuAttributes)
            
            // QR Code centré (5cm = 189 points)
            let qrX = (400 - qrCodeSize) / 2
            let qrRect = CGRect(x: qrX, y: 120, width: qrCodeSize, height: qrCodeSize)
            qrImage.draw(in: qrRect)
            
            // Indication de taille
            let sizeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.lightGray
            ]
            let sizeRect = CGRect(x: 20, y: 320, width: 360, height: 20)
            "5cm × 5cm".draw(in: sizeRect, withAttributes: sizeAttributes)
            
            // Instructions
            let instructionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.gray
            ]
            
            let instructionRect = CGRect(x: 20, y: 360, width: 360, height: 60)
            "Scannez ce QR code avec l'application LogiScan pour accéder aux détails de l'article".draw(in: instructionRect, withAttributes: instructionAttributes)
        }
    }
    
    private func createPrintableLabel() -> UIImage {
        guard let qrImage = qrImage else { return UIImage() }
        
        // Format étiquette avec QR code 5cm
        // Total: 7cm × 5cm = 265 × 189 points
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 265, height: qrCodeSize))
        
        return renderer.image { context in
            // Fond blanc
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 265, height: qrCodeSize)))
            
            // QR Code à gauche (5cm × 5cm)
            let qrRect = CGRect(x: 0, y: 0, width: qrCodeSize, height: qrCodeSize)
            qrImage.draw(in: qrRect)
            
            // Zone texte à droite
            let textX = qrCodeSize + 10
            let textWidth = 265 - qrCodeSize - 15
            
            // Nom de l'article
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            let titleRect = CGRect(x: textX, y: 20, width: textWidth, height: 50)
            itemName.draw(in: titleRect, withAttributes: titleAttributes)
            
            // SKU
            let skuAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ]
            
            let skuRect = CGRect(x: textX, y: 80, width: textWidth, height: 20)
            "SKU: \(sku)".draw(in: skuRect, withAttributes: skuAttributes)
            
            // Logo/Nom entreprise
            let logoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]
            
            let logoRect = CGRect(x: textX, y: 150, width: textWidth, height: 20)
            "LogiScan".draw(in: logoRect, withAttributes: logoAttributes)
        }
    }
    
    private func saveToPhotos() {
        let image = createShareableImage()
        guard image.size != .zero else { return } // Vérifier que l'image est valide
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // TODO: Afficher une confirmation
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PrintSheet: UIViewControllerRepresentable {
    let image: UIImage
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Étiquette QR Code"
        printInfo.outputType = .photo
        
        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.printingItem = image
        
        let activityViewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // Filtrer pour ne montrer que les options d'impression
        activityViewController.excludedActivityTypes = [
            .message, .mail, .postToFacebook, .postToTwitter,
            .postToWeibo, .copyToPasteboard, .assignToContact,
            .saveToCameraRoll, .addToReadingList, .postToFlickr,
            .postToVimeo, .postToTencentWeibo, .airDrop
        ]
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    @Previewable @State var sampleQRImage = UIImage(systemName: "qrcode")
    
    QRCodeShareView(
        qrImage: sampleQRImage,
        itemName: "Projecteur LED 50W",
        sku: "LED-SPOT-50W"
    )
}

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
                
                // QR Code agrandi
                if let qrImage = qrImage {
                    VStack(spacing: 16) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 5)
                        
                        Text("Scannez ce code pour accéder aux détails de l'article")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                        .frame(width: 250, height: 250)
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
            
            // QR Code
            let qrRect = CGRect(x: 75, y: 120, width: 250, height: 250)
            qrImage.draw(in: qrRect)
            
            // Instructions
            let instructionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.gray
            ]
            
            let instructionRect = CGRect(x: 20, y: 400, width: 360, height: 60)
            "Scannez ce QR code avec l'application LogiScan pour accéder aux détails de l'article".draw(in: instructionRect, withAttributes: instructionAttributes)
        }
    }
    
    private func createPrintableLabel() -> UIImage {
        guard let qrImage = qrImage else { return UIImage() }
        
        // Format étiquette 62x29mm (taille courante pour étiquettes logistique)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 236, height: 110)) // 300 DPI
        
        return renderer.image { context in
            // Fond blanc
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 236, height: 110)))
            
            // QR Code plus petit
            let qrRect = CGRect(x: 5, y: 5, width: 100, height: 100)
            qrImage.draw(in: qrRect)
            
            // Nom de l'article
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ]
            
            let titleRect = CGRect(x: 110, y: 10, width: 120, height: 30)
            itemName.draw(in: titleRect, withAttributes: titleAttributes)
            
            // SKU
            let skuAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.black
            ]
            
            let skuRect = CGRect(x: 110, y: 45, width: 120, height: 15)
            "SKU: \(sku)".draw(in: skuRect, withAttributes: skuAttributes)
            
            // Logo/Nom entreprise
            let logoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 8),
                .foregroundColor: UIColor.gray
            ]
            
            let logoRect = CGRect(x: 110, y: 85, width: 120, height: 15)
            "LogiScan Distribution".draw(in: logoRect, withAttributes: logoAttributes)
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
    let sampleQRImage = UIImage(systemName: "qrcode")
    
    return QRCodeShareView(
        qrImage: sampleQRImage,
        itemName: "Projecteur LED 50W",
        sku: "LED-SPOT-50W"
    )
}

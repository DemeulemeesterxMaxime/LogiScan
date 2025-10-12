//
//  QuotePDFView.swift
//  LogiScan
//
//  Created by Demeulemeester on 12/10/2025.
//

import PDFKit
import SwiftData
import SwiftUI

struct QuotePDFView: View {
    @Environment(\.dismiss) private var dismiss
    
    let event: Event
    let quoteItems: [QuoteItem]
    
    @State private var pdfDocument: PDFDocument?
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    
    var body: some View {
        NavigationView {
            VStack {
                if let pdfDocument = pdfDocument {
                    PDFKitView(document: pdfDocument)
                } else {
                    ProgressView("Génération du PDF...")
                        .padding()
                }
            }
            .navigationTitle("Devis PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if let url = pdfURL {
                            showShareSheet = true
                        }
                    }) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                    }
                    .disabled(pdfURL == nil)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .onAppear {
            generatePDF()
        }
    }
    
    // MARK: - PDF Generation
    
    private func generatePDF() {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 size in points
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
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
        
        // Sauvegarder le PDF
        let fileName = "Devis_\(event.eventId)_\(Date().timeIntervalSince1970).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: url)
            self.pdfURL = url
            self.pdfDocument = PDFDocument(url: url)
        } catch {
            print("Erreur lors de la sauvegarde du PDF : \(error)")
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
        
        event.eventAddress.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
        
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
        
        "Client".draw(at: CGPoint(x: 50, y: y), withAttributes: boldAttributes)
        y += 20
        
        event.clientName.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
        y += 18
        
        event.clientPhone.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
        y += 18
        
        event.clientEmail.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
        y += 18
        
        event.clientAddress.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
        
        return y
    }
    
    private func drawLine(in rect: CGRect, y: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 50, y: y))
        path.addLine(to: CGPoint(x: rect.width - 50, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
    
    private func drawItemsTable(in rect: CGRect, startY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.white
        ]
        
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        
        var y = startY
        
        // En-tête du tableau
        let headerRect = CGRect(x: 50, y: y, width: rect.width - 100, height: 25)
        UIColor.systemBlue.setFill()
        UIBezierPath(rect: headerRect).fill()
        
        "Article".draw(at: CGPoint(x: 60, y: y + 6), withAttributes: headerAttributes)
        "Qté".draw(at: CGPoint(x: rect.width - 250, y: y + 6), withAttributes: headerAttributes)
        "Prix unitaire".draw(at: CGPoint(x: rect.width - 200, y: y + 6), withAttributes: headerAttributes)
        "Total".draw(at: CGPoint(x: rect.width - 100, y: y + 6), withAttributes: headerAttributes)
        
        y += 25
        
        // Lignes du tableau
        for (index, item) in quoteItems.enumerated() {
            // Vérifier si on a besoin d'une nouvelle page
            if y > rect.height - 150 {
                context.beginPage()
                y = 50
            }
            
            // Fond alternant
            if index % 2 == 0 {
                let rowRect = CGRect(x: 50, y: y, width: rect.width - 100, height: 20)
                UIColor.systemGray6.setFill()
                UIBezierPath(rect: rowRect).fill()
            }
            
            item.name.draw(at: CGPoint(x: 60, y: y + 4), withAttributes: cellAttributes)
            "\(item.quantity)".draw(at: CGPoint(x: rect.width - 240, y: y + 4), withAttributes: cellAttributes)
            String(format: "%.2f €", item.unitPrice).draw(at: CGPoint(x: rect.width - 200, y: y + 4), withAttributes: cellAttributes)
            String(format: "%.2f €", item.totalPrice).draw(at: CGPoint(x: rect.width - 100, y: y + 4), withAttributes: cellAttributes)
            
            y += 20
        }
        
        return y
    }
    
    private func drawPricingSummary(in rect: CGRect, startY: CGFloat) -> CGFloat {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let totalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.systemBlue
        ]
        
        var y = startY
        let labelX: CGFloat = rect.width - 250
        let valueX: CGFloat = rect.width - 100
        
        // Sous-total articles
        let subtotal = quoteItems.reduce(0) { $0 + $1.totalPrice }
        "Sous-total articles :".draw(at: CGPoint(x: labelX, y: y), withAttributes: labelAttributes)
        String(format: "%.2f €", subtotal).draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttributes)
        y += 20
        
        // Frais de déplacement
        if event.deliveryFee > 0 {
            "Frais de déplacement :".draw(at: CGPoint(x: labelX, y: y), withAttributes: labelAttributes)
            String(format: "%.2f €", event.deliveryFee).draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttributes)
            y += 20
        }
        
        // Frais de montage
        if event.assemblyFee > 0 {
            "Frais de montage :".draw(at: CGPoint(x: labelX, y: y), withAttributes: labelAttributes)
            String(format: "%.2f €", event.assemblyFee).draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttributes)
            y += 20
        }
        
        // Frais de démontage
        if event.disassemblyFee > 0 {
            "Frais de démontage :".draw(at: CGPoint(x: labelX, y: y), withAttributes: labelAttributes)
            String(format: "%.2f €", event.disassemblyFee).draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttributes)
            y += 20
        }
        
        // Total HT
        let totalHT = subtotal + event.deliveryFee + event.assemblyFee + event.disassemblyFee
        "Total HT :".draw(at: CGPoint(x: labelX, y: y), withAttributes: labelAttributes)
        String(format: "%.2f €", totalHT).draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttributes)
        y += 20
        
        // TVA
        let tvaAmount = totalHT * (event.tvaRate / 100)
        "TVA (\(String(format: "%.1f", event.tvaRate))%) :".draw(at: CGPoint(x: labelX, y: y), withAttributes: labelAttributes)
        String(format: "%.2f €", tvaAmount).draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttributes)
        y += 25
        
        // Total TTC
        "Total TTC :".draw(at: CGPoint(x: labelX, y: y), withAttributes: totalAttributes)
        String(format: "%.2f €", event.finalAmount).draw(at: CGPoint(x: valueX, y: y), withAttributes: totalAttributes)
        
        return y
    }
    
    private func drawFooter(in rect: CGRect) {
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        
        let y = rect.height - 50
        
        let footerText = "Ce devis est valable 30 jours à compter de la date d'émission."
        let textSize = footerText.size(withAttributes: footerAttributes)
        footerText.draw(at: CGPoint(x: (rect.width - textSize.width) / 2, y: y), withAttributes: footerAttributes)
    }
}

#Preview {
    @Previewable @State var event = Event(
        eventId: "evt1",
        name: "Mariage Sophie & Marc",
        clientName: "Sophie Dubois",
        clientPhone: "+33123456789",
        clientEmail: "sophie@example.com",
        clientAddress: "123 Rue de Paris, 75001 Paris",
        eventAddress: "Château de Versailles",
        setupStartTime: Date(),
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400),
        deliveryFee: 150.0,
        assemblyFee: 200.0,
        disassemblyFee: 150.0,
        tvaRate: 20.0
    )
    
    let items = [
        QuoteItem(
            quoteItemId: UUID().uuidString,
            eventId: "evt1",
            sku: "CHR001",
            name: "Chaise Napoleon III Dorée",
            category: "Mobilier",
            quantity: 50,
            unitPrice: 3.50
        ),
        QuoteItem(
            quoteItemId: UUID().uuidString,
            eventId: "evt1",
            sku: "TAB001",
            name: "Table ronde 8 personnes",
            category: "Mobilier",
            quantity: 10,
            unitPrice: 15.00
        )
    ]
    
    QuotePDFView(event: event, quoteItems: items)
}

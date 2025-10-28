//
//  QuoteFinalizationView.swift
//  LogiScan
//
//  Created by Demeulemeester on 12/10/2025.
//

import SwiftData
import SwiftUI

struct QuoteFinalizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService()
    @StateObject private var versionService = QuoteVersionService()
    
    let event: Event
    @Binding var quoteItems: [QuoteItem]
    
    @State private var deliveryFee: String = ""
    @State private var assemblyFee: String = ""
    @State private var disassemblyFee: String = ""
    @State private var tvaRate: String = "20.0"
    
    @State private var showingPDF = false
    @State private var showingTaskSuggestion = false
    @State private var suggestedTasks: [TodoTask] = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isCreatingVersion = false
    
    var subtotal: Double {
        quoteItems.reduce(0) { $0 + $1.totalPrice }
    }
    
    var deliveryAmount: Double {
        Double(deliveryFee) ?? 0.0
    }
    
    var assemblyAmount: Double {
        Double(assemblyFee) ?? 0.0
    }
    
    var disassemblyAmount: Double {
        Double(disassemblyFee) ?? 0.0
    }
    
    var totalBeforeTVA: Double {
        subtotal + deliveryAmount + assemblyAmount + disassemblyAmount
    }
    
    var tvaAmount: Double {
        let rate = Double(tvaRate) ?? 20.0
        return totalBeforeTVA * (rate / 100)
    }
    
    var totalWithTVA: Double {
        totalBeforeTVA + tvaAmount
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Section Articles
                Section(header: Text("Articles")) {
                    HStack {
                        Text("Sous-total articles")
                        Spacer()
                        Text(String(format: "%.2f €", subtotal))
                            .fontWeight(.medium)
                    }
                    
                    Text("\(quoteItems.count) article(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Section Frais supplémentaires
                Section(header: Text("Frais supplémentaires")) {
                    HStack {
                        Text("Frais de déplacement")
                        Spacer()
                        TextField("0.00", text: $deliveryFee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("€")
                    }
                    
                    HStack {
                        Text("Frais de montage")
                        Spacer()
                        TextField("0.00", text: $assemblyFee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("€")
                    }
                    
                    HStack {
                        Text("Frais de démontage")
                        Spacer()
                        TextField("0.00", text: $disassemblyFee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("€")
                    }
                    
                    HStack {
                        Text("Total frais")
                        Spacer()
                        Text(String(format: "%.2f €", deliveryAmount + assemblyAmount + disassemblyAmount))
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                
                // Section TVA
                Section(header: Text("TVA")) {
                    HStack {
                        Text("Taux de TVA")
                        Spacer()
                        TextField("20.0", text: $tvaRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%")
                    }
                    
                    HStack {
                        Text("Total HT")
                        Spacer()
                        Text(String(format: "%.2f €", totalBeforeTVA))
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Montant TVA")
                        Spacer()
                        Text(String(format: "%.2f €", tvaAmount))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Section Total final
                Section {
                    HStack {
                        Text("Total TTC")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.2f €", totalWithTVA))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                // Bouton Finaliser
                Section {
                    Button(action: {
                        finalizeQuote()
                    }) {
                        HStack {
                            Spacer()
                            if isCreatingVersion {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 8)
                                Text("Création en cours...")
                                    .fontWeight(.semibold)
                            } else {
                                Text("Finaliser le devis")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(isCreatingVersion ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .disabled(isCreatingVersion)
                }
            }
            .navigationTitle("Finalisation du devis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPDF) {
                QuotePDFView(event: event, quoteItems: quoteItems)
            }
            .sheet(isPresented: $showingTaskSuggestion) {
                TaskSuggestionView(
                    event: event,
                    suggestedTasks: suggestedTasks,
                    onValidate: { validatedTasks in
                        createTasks(validatedTasks)
                    }
                )
            }
            .alert("Information", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            loadExistingFees()
        }
    }
    
    // MARK: - Functions
    
    private func loadExistingFees() {
        deliveryFee = event.deliveryFee > 0 ? String(format: "%.2f", event.deliveryFee) : ""
        assemblyFee = event.assemblyFee > 0 ? String(format: "%.2f", event.assemblyFee) : ""
        disassemblyFee = event.disassemblyFee > 0 ? String(format: "%.2f", event.disassemblyFee) : ""
        tvaRate = String(format: "%.1f", event.tvaRate)
    }
    
    private func finalizeQuote() {
        guard let currentUser = PermissionService.shared.currentUser else {
            alertMessage = "Utilisateur non connecté"
            showAlert = true
            return
        }
        
        isCreatingVersion = true
        
        // Mettre à jour l'événement avec les frais
        event.deliveryFee = deliveryAmount
        event.assemblyFee = assemblyAmount
        event.disassemblyFee = disassemblyAmount
        event.tvaRate = Double(tvaRate) ?? 20.0
        event.totalAmount = subtotal
        event.finalAmount = totalWithTVA
        event.quoteStatus = .finalized
        event.updatedAt = Date()
        
        do {
            try modelContext.save()
            print("✅ [QuoteFinalization] Sauvegarde locale réussie")
            
            // Créer automatiquement la ScanList
            createScanList()
            
            // Créer la version PDF
            Task {
                do {
                    // 1. Générer le PDF
                    let pdfData = generatePDFData()
                    
                    // 2. Créer la version avec upload du PDF
                    let version = try await versionService.createVersion(
                        event: event,
                        quoteItems: quoteItems,
                        pdfData: pdfData,
                        createdBy: currentUser.userId,
                        createdByName: currentUser.displayName,
                        modelContext: modelContext
                    )
                    
                    print("✅ [QuoteFinalization] Version \(version.versionNumber) créée avec PDF")
                    
                    // 3. Synchroniser l'événement avec Firebase
                    try await syncToFirebase()
                    print("✅ [QuoteFinalization] Synchronisation Firebase réussie")
                    
                    await MainActor.run {
                        isCreatingVersion = false
                        
                        // Générer les tâches suggérées
                        generateTaskSuggestions()
                        
                        // Petite pause avant d'afficher le PDF
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingPDF = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        isCreatingVersion = false
                        alertMessage = "Erreur lors de la création de la version: \(error.localizedDescription)"
                        showAlert = true
                    }
                    print("❌ [QuoteFinalization] Erreur: \(error.localizedDescription)")
                }
            }
        } catch {
            isCreatingVersion = false
            alertMessage = "Erreur lors de la finalisation : \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Génération du PDF
    
    private func generatePDFData() -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 size in points
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        return renderer.pdfData { context in
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
    }
    
    // MARK: - Drawing Functions (copié depuis QuotePDFView)
    
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
        
        if !event.eventAddress.isEmpty {
            event.eventAddress.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
        }
        
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
        
        if !event.clientName.isEmpty {
            "Client".draw(at: CGPoint(x: 50, y: y), withAttributes: boldAttributes)
            y += 20
            
            event.clientName.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
            y += 18
            
            if !event.clientPhone.isEmpty {
                event.clientPhone.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
                y += 18
            }
            
            if !event.clientEmail.isEmpty {
                event.clientEmail.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
                y += 18
            }
            
            if !event.clientAddress.isEmpty {
                event.clientAddress.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
            }
        }
        
        return y
    }
    
    private func drawLine(in rect: CGRect, y: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 50, y: y))
        path.addLine(to: CGPoint(x: rect.width - 50, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
    
    private func drawItemsTable(in rect: CGRect, startY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        
        var y = startY
        
        // En-tête du tableau
        "Article".draw(at: CGPoint(x: 50, y: y), withAttributes: boldAttributes)
        "Qté".draw(at: CGPoint(x: 350, y: y), withAttributes: boldAttributes)
        "P.U.".draw(at: CGPoint(x: 410, y: y), withAttributes: boldAttributes)
        "Total".draw(at: CGPoint(x: 480, y: y), withAttributes: boldAttributes)
        
        y += 20
        drawLine(in: rect, y: y)
        y += 10
        
        // Articles
        for item in quoteItems {
            // Vérifier si on a besoin d'une nouvelle page
            if y > rect.height - 150 {
                context.beginPage()
                y = 50
            }
            
            item.name.draw(at: CGPoint(x: 50, y: y), withAttributes: regularAttributes)
            "\(item.quantity)".draw(at: CGPoint(x: 350, y: y), withAttributes: regularAttributes)
            String(format: "%.2f €", item.unitPrice).draw(at: CGPoint(x: 410, y: y), withAttributes: regularAttributes)
            String(format: "%.2f €", item.totalPrice).draw(at: CGPoint(x: 480, y: y), withAttributes: regularAttributes)
            
            y += 20
        }
        
        return y
    }
    
    private func drawPricingSummary(in rect: CGRect, startY: CGFloat) -> CGFloat {
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        var y = startY
        let leftX: CGFloat = 350
        let rightX: CGFloat = 480
        
        // Sous-total
        "Sous-total articles".draw(at: CGPoint(x: leftX, y: y), withAttributes: regularAttributes)
        String(format: "%.2f €", subtotal).draw(at: CGPoint(x: rightX, y: y), withAttributes: regularAttributes)
        y += 20
        
        // Frais supplémentaires
        if deliveryAmount > 0 {
            "Frais de déplacement".draw(at: CGPoint(x: leftX, y: y), withAttributes: regularAttributes)
            String(format: "%.2f €", deliveryAmount).draw(at: CGPoint(x: rightX, y: y), withAttributes: regularAttributes)
            y += 20
        }
        
        if assemblyAmount > 0 {
            "Frais de montage".draw(at: CGPoint(x: leftX, y: y), withAttributes: regularAttributes)
            String(format: "%.2f €", assemblyAmount).draw(at: CGPoint(x: rightX, y: y), withAttributes: regularAttributes)
            y += 20
        }
        
        if disassemblyAmount > 0 {
            "Frais de démontage".draw(at: CGPoint(x: leftX, y: y), withAttributes: regularAttributes)
            String(format: "%.2f €", disassemblyAmount).draw(at: CGPoint(x: rightX, y: y), withAttributes: regularAttributes)
            y += 20
        }
        
        // Total HT
        drawLine(in: rect, y: y)
        y += 10
        
        "Total HT".draw(at: CGPoint(x: leftX, y: y), withAttributes: boldAttributes)
        String(format: "%.2f €", totalBeforeTVA).draw(at: CGPoint(x: rightX, y: y), withAttributes: boldAttributes)
        y += 20
        
        // TVA
        let tvaRateValue = Double(tvaRate) ?? 20.0
        "TVA (\(String(format: "%.1f", tvaRateValue))%)".draw(at: CGPoint(x: leftX, y: y), withAttributes: regularAttributes)
        String(format: "%.2f €", tvaAmount).draw(at: CGPoint(x: rightX, y: y), withAttributes: regularAttributes)
        y += 20
        
        // Total TTC
        drawLine(in: rect, y: y)
        y += 10
        
        let totalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.systemBlue
        ]
        
        "TOTAL TTC".draw(at: CGPoint(x: leftX, y: y), withAttributes: totalAttributes)
        String(format: "%.2f €", totalWithTVA).draw(at: CGPoint(x: rightX, y: y), withAttributes: totalAttributes)
        
        return y + 30
    }
    
    private func drawFooter(in rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        
        let footerText = "Ce devis est valable 30 jours à compter de sa date d'émission."
        let y = rect.height - 50
        footerText.draw(at: CGPoint(x: 50, y: y), withAttributes: attributes)
    }
    
    private func syncToFirebase() async throws {
        let firebaseService = FirebaseService()
        let firestoreEvent = event.toFirestoreEvent()
        try await firebaseService.updateEvent(firestoreEvent)
    }
    
    private func createScanList() {
        do {
            let scanListService = ScanListService()
            let scanLists = try scanListService.generateAllScanLists(
                from: event,
                quoteItems: quoteItems,
                modelContext: modelContext
            )
            print("✅ [QuoteFinalization] \(scanLists.count) ScanLists créées automatiquement pour toutes les directions")
        } catch {
            print("⚠️ [QuoteFinalization] Erreur création ScanLists: \(error.localizedDescription)")
            // Ne pas bloquer la finalisation si la création des ScanLists échoue
        }
    }
    
    private func generateTaskSuggestions() {
        guard let userId = authService.currentUserId else {
            print("⚠️ [QuoteFinalization] Utilisateur non connecté")
            return
        }
        
        print("👤 [QuoteFinalization] UserId: \(userId)")
        
        // Récupérer le companyId depuis PermissionService (qui a déjà l'utilisateur chargé)
        guard let currentUser = PermissionService.shared.currentUser else {
            print("❌ [QuoteFinalization] Pas d'utilisateur dans PermissionService")
            return
        }
        
        print("✅ [QuoteFinalization] Utilisateur trouvé: \(currentUser.displayName)")
        
        guard let companyId = currentUser.companyId else {
            print("⚠️ [QuoteFinalization] Impossible de récupérer le companyId")
            return
        }
        
        print("✅ [QuoteFinalization] CompanyId: \(companyId)")
        
        // Générer les tâches suggérées
        do {
            var allTasks = try TaskService.shared.generateSuggestedTasks(
                for: event,
                companyId: companyId,
                createdBy: userId,
                modelContext: modelContext
            )
            
            print("✅ [QuoteFinalization] \(allTasks.count) tâches générées")
            
            // Retirer la tâche "Créer liste de scan" car elles sont déjà créées automatiquement
            allTasks.removeAll { $0.type == .createScanList }
            
            print("✅ [QuoteFinalization] \(allTasks.count) tâches à créer (après filtrage)")
            
            suggestedTasks = allTasks
            
            // Créer automatiquement TOUTES les tâches (car les listes sont déjà créées)
            createAllTasksAutomatically(tasks: allTasks)
            
            // Ne plus afficher la modal de suggestion
            // DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            //     showingTaskSuggestion = true
            // }
        } catch {
            print("❌ Erreur génération tâches: \(error)")
        }
    }
    
    private func createAllTasksAutomatically(tasks: [TodoTask]) {
        Task {
            do {
                print("📝 [QuoteFinalization] Création automatique de \(tasks.count) tâches...")
                for (index, task) in tasks.enumerated() {
                    print("📝 [QuoteFinalization] Création tâche \(index + 1)/\(tasks.count): \(task.type.displayName)")
                    _ = try await TaskService.shared.createTask(task, modelContext: modelContext)
                }
                print("✅ [QuoteFinalization] \(tasks.count) tâches créées automatiquement")
            } catch {
                print("❌ [QuoteFinalization] Erreur création tâches: \(error.localizedDescription)")
            }
        }
    }
    
    private func createTasks(_ tasks: [TodoTask]) {
        Task {
            do {
                for task in tasks {
                    // Créer chaque tâche avec TaskService
                    _ = try await TaskService.shared.createTask(task, modelContext: modelContext)
                }
                
                alertMessage = "✅ \(tasks.count) tâches créées avec succès !"
                showAlert = true
                
                // Fermer la vue après un court délai
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch {
                alertMessage = "❌ Erreur création tâches: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

#Preview {
    @Previewable @State var items = [
        QuoteItem(
            quoteItemId: UUID().uuidString,
            eventId: "evt1",
            sku: "CHR001",
            name: "Chaise Napoleon III Dorée",
            category: "Mobilier",
            quantity: 50,
            unitPrice: 3.50
        )
    ]
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Event.self, QuoteItem.self, configurations: config)
    
    let event = Event(
        eventId: "evt1",
        name: "Mariage Sophie & Marc",
        clientName: "Sophie Dubois",
        clientPhone: "+33123456789",
        clientEmail: "sophie@example.com",
        clientAddress: "Paris",
        eventAddress: "Château de Versailles",
        setupStartTime: Date(),
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400)
    )
    
    QuoteFinalizationView(event: event, quoteItems: $items)
        .modelContainer(container)
}

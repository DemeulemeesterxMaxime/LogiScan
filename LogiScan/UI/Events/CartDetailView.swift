//
//  CartDetailView.swift
//  LogiScan
//
//  Created by Demeulemeester on 12/10/2025.
//

import SwiftData
import SwiftUI

struct CartDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var stockItems: [StockItem]
    
    let event: Event
    @Binding var quoteItems: [QuoteItem]
    
    @State private var showingFinalization = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var subtotal: Double {
        quoteItems.reduce(0) { $0 + $1.totalPrice }
    }
    
    var totalWeight: Double {
        quoteItems.reduce(0) { total, item in
            if let stockItem = stockItems.first(where: { $0.sku == item.sku }) {
                return total + (stockItem.unitWeight * Double(item.quantity))
            }
            return total
        }
    }
    
    var totalVolume: Double {
        quoteItems.reduce(0) { total, item in
            if let stockItem = stockItems.first(where: { $0.sku == item.sku }) {
                return total + (stockItem.unitVolume * Double(item.quantity))
            }
            return total
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Liste des articles dans le panier
            ScrollView {
                VStack(spacing: 16) {
                    // En-tête avec infos
                    headerSection
                    
                    Divider()
                    
                    // Liste des articles
                    ForEach(quoteItems) { item in
                        CartItemDetailRow(
                            item: item,
                            onQuantityChange: { newQuantity in
                                updateQuantity(item: item, newQuantity: newQuantity)
                            },
                            onRemove: {
                                removeItem(item)
                            }
                        )
                        Divider()
                    }
                    
                    // Récapitulatif
                    summarySection
                }
                .padding()
            }
            
            Divider()
            
            // Bouton Terminer le devis en bas
            Button(action: {
                saveAndFinalize()
            }) {
                Text("Terminer le devis")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Panier")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Retour") {
                    saveCart()
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Enregistrer") {
                    saveCart()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingFinalization) {
            QuoteFinalizationView(event: event, quoteItems: $quoteItems)
        }
        .alert("Information", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Événement : \(event.name)")
                .font(.headline)
            
            Text("Client : \(event.clientName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Label("\(quoteItems.count) article(s)", systemImage: "cube.box")
                Spacer()
                Label(String(format: "%.1f kg", totalWeight), systemImage: "scalemass")
                Spacer()
                Label(String(format: "%.2f m³", totalVolume), systemImage: "cube")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Récapitulatif")
                .font(.headline)
            
            HStack {
                Text("Sous-total")
                Spacer()
                Text(String(format: "%.2f €", subtotal))
            }
            
            Text("Les frais supplémentaires (déplacement, montage, TVA) seront ajoutés à l'étape suivante.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Functions
    
    private func updateQuantity(item: QuoteItem, newQuantity: Int) {
        if newQuantity <= 0 {
            removeItem(item)
        } else {
            if let index = quoteItems.firstIndex(where: { $0.sku == item.sku }) {
                quoteItems[index].quantity = newQuantity
                quoteItems[index].totalPrice = quoteItems[index].unitPrice * Double(newQuantity)
            }
        }
    }
    
    private func removeItem(_ item: QuoteItem) {
        quoteItems.removeAll { $0.sku == item.sku }
    }
    
    private func saveCart() {
        // Supprimer les anciens items du devis
        let eventId = event.eventId
        let existingItems = try? modelContext.fetch(
            FetchDescriptor<QuoteItem>(
                predicate: #Predicate { $0.eventId == eventId }
            )
        )
        existingItems?.forEach { modelContext.delete($0) }
        
        // Insérer les nouveaux items
        quoteItems.forEach { item in
            modelContext.insert(item)
        }
        
        // Sauvegarder
        do {
            try modelContext.save()
        } catch {
            alertMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func saveAndFinalize() {
        saveCart()
        
        // Petite pause pour s'assurer que le contexte est sauvegardé
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingFinalization = true
        }
    }
}

// MARK: - Cart Item Detail Row

struct CartItemDetailRow: View {
    let item: QuoteItem
    let onQuantityChange: (Int) -> Void
    let onRemove: () -> Void
    
    @State private var quantity: Int
    
    init(item: QuoteItem, onQuantityChange: @escaping (Int) -> Void, onRemove: @escaping () -> Void) {
        self.item = item
        self.onQuantityChange = onQuantityChange
        self.onRemove = onRemove
        _quantity = State(initialValue: item.quantity)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                Text("SKU: \(item.sku)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.2f € / unité", item.unitPrice))
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                // Prix total
                Text(String(format: "%.2f €", item.totalPrice))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Contrôles de quantité
                HStack(spacing: 8) {
                    Button(action: {
                        if quantity > 1 {
                            quantity -= 1
                            onQuantityChange(quantity)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(quantity > 1 ? .blue : .gray)
                    }
                    .disabled(quantity <= 1)
                    
                    Text("\(quantity)")
                        .font(.body)
                        .frame(minWidth: 30)
                    
                    Button(action: {
                        quantity += 1
                        onQuantityChange(quantity)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                // Bouton supprimer
                Button(action: onRemove) {
                    Label("Supprimer", systemImage: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Event.self, QuoteItem.self, StockItem.self, configurations: config)
    
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
    
    @State var items = [
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
    
    NavigationStack {
        CartDetailView(event: event, quoteItems: $items)
            .modelContainer(container)
    }
}

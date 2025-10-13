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
    
    let event: Event
    @Binding var quoteItems: [QuoteItem]
    
    @State private var deliveryFee: String = ""
    @State private var assemblyFee: String = ""
    @State private var disassemblyFee: String = ""
    @State private var tvaRate: String = "20.0"
    
    @State private var showingPDF = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
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
                            Text("Finaliser le devis")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue)
                    .foregroundColor(.white)
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
            
            // Petite pause avant d'afficher le PDF
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingPDF = true
            }
        } catch {
            alertMessage = "Erreur lors de la finalisation : \(error.localizedDescription)"
            showAlert = true
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

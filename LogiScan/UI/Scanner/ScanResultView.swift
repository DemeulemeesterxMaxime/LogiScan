//
//  ScanResultView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftUI

struct ScanResultView: View {
    let result: ScanResult?
    let onMovementAction: (MovementType, String, String?, String?) -> Void
    let onScanAgain: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMovementType: MovementType = .pick
    @State private var fromLocation = ""
    @State private var toLocation = ""
    @State private var showingMovementOptions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let result = result {
                        scanResultHeader(result)
                        assetDetails(result)
                        actionButtons
                    } else {
                        Text("Aucun résultat")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Résultat du scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingMovementOptions) {
            MovementActionSheet(
                selectedType: $selectedMovementType,
                fromLocation: $fromLocation,
                toLocation: $toLocation,
                onConfirm: {
                    if let asset = result?.asset {
                        onMovementAction(
                            selectedMovementType,
                            asset.assetId,
                            fromLocation.isEmpty ? nil : fromLocation,
                            toLocation.isEmpty ? nil : toLocation
                        )
                    }
                    dismiss()
                }
            )
        }
    }
    
    private func scanResultHeader(_ result: ScanResult) -> some View {
        VStack(spacing: 12) {
            // Icône basée sur le type
            Group {
                switch result.type {
                case .asset:
                    Image(systemName: "cube.box.fill")
                case .location:
                    Image(systemName: "location.fill")
                case .batch:
                    Image(systemName: "shippingbox.fill")
                case .unknown:
                    Image(systemName: "questionmark.circle.fill")
                }
            }
            .font(.system(size: 50))
            .foregroundColor(.accentColor)
            
            VStack(spacing: 4) {
                Text(result.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(result.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Badge de statut
            statusBadge(result.status, color: result.statusColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func statusBadge(_ status: String, color: String) -> some View {
        Text(status)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(color).opacity(0.2))
            )
            .foregroundColor(Color(color))
    }
    
    private func assetDetails(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Détails")
                .font(.headline)
            
            if let asset = result.asset {
                VStack(spacing: 12) {
                    detailRow("SKU", asset.sku)
                    detailRow("Catégorie", asset.category)
                    
                    if let serialNumber = asset.serialNumber {
                        detailRow("N° Série", serialNumber)
                    }
                    
                    detailRow("Poids", String(format: "%.2f kg", asset.weight))
                    detailRow("Volume", String(format: "%.2f m³", asset.volume))
                    detailRow("Valeur", String(format: "%.2f €", asset.value))
                    
                    if let location = asset.currentLocationId {
                        detailRow("Localisation", location)
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
    }
    
    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Bouton principal: Créer mouvement
            Button(action: {
                showingMovementOptions = true
            }) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Créer mouvement")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Boutons secondaires
            HStack(spacing: 12) {
                secondaryButton(
                    icon: "info.circle",
                    title: "Détails",
                    action: {
                        // TODO: Navigation vers détails de l'asset
                    }
                )
                
                secondaryButton(
                    icon: "clock.arrow.circlepath",
                    title: "Historique",
                    action: {
                        // TODO: Navigation vers historique
                    }
                )
                
                secondaryButton(
                    icon: "qrcode.viewfinder",
                    title: "Scanner",
                    action: {
                        dismiss()
                        onScanAgain()
                    }
                )
            }
        }
    }
    
    private func secondaryButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
            )
            .foregroundColor(.primary)
        }
    }
}

struct MovementActionSheet: View {
    @Binding var selectedType: MovementType
    @Binding var fromLocation: String
    @Binding var toLocation: String
    let onConfirm: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Type de mouvement") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(MovementType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(Color(type.color))
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section("Localisation") {
                    TextField("De (optionnel)", text: $fromLocation)
                    TextField("Vers (optionnel)", text: $toLocation)
                }
                
                Section {
                    Button("Confirmer le mouvement") {
                        onConfirm()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.white)
                    .listRowBackground(Color.accentColor)
                }
            }
            .navigationTitle("Nouveau mouvement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ScanResultView(
        result: ScanResult(
            type: .asset,
            asset: Asset(
                assetId: "A001",
                sku: "LED-SPOT-50W",
                name: "Projecteur LED 50W",
                category: "Éclairage",
                weight: 2.5,
                volume: 0.01,
                value: 150.0,
                qrPayload: "ASSET:A001"
            ),
            title: "Projecteur LED 50W",
            subtitle: "SKU: LED-SPOT-50W",
            status: "En état",
            statusColor: "green",
            rawPayload: "{\"v\":1,\"type\":\"asset\",\"id\":\"A001\"}"
        ),
        onMovementAction: { _, _, _, _ in },
        onScanAgain: { }
    )
}

//
//  StockItemDetailView.swift
//  LogiScan
//
//  Created by Demeulemeester on 01/10/2025.
//

import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

struct StockItemDetailView: View {
    @Bindable var stockItem: StockItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingTagEditor = false
    @State private var showingQRShare = false
    @State private var showingLocationHistory = false
    @State private var qrCodeImage: UIImage?
    
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
                    // En-tête avec image et infos principales
                    headerSection
                    
                    // Code QR
                    qrCodeSection
                    
                    // Étiquettes
                    tagsSection
                    
                    // Détails techniques
                    detailsSection
                    
                    // Localisation et disponibilité
                    availabilitySection
                    
                    // Assets individuels (si sérialisés)
                    if !filteredAssets.isEmpty {
                        serializedAssetsSection
                    }
                    
                    // Historique des mouvements récents
                    movementHistorySection
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
                        Button("Modifier les étiquettes", systemImage: "tag") {
                            showingTagEditor = true
                        }
                        
                        Button("Partager QR Code", systemImage: "square.and.arrow.up") {
                            showingQRShare = true
                        }
                        
                        Button("Historique complet", systemImage: "clock") {
                            showingLocationHistory = true
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
            generateQRCode()
        }
        .sheet(isPresented: $showingTagEditor) {
            TagEditorView(stockItem: stockItem)
        }
        .sheet(isPresented: $showingQRShare) {
            QRCodeShareView(qrImage: qrCodeImage, itemName: stockItem.name, sku: stockItem.sku)
        }
        .sheet(isPresented: $showingLocationHistory) {
            LocationHistoryView(sku: stockItem.sku)
        }
    }
    
    private var headerSection: some View {
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
            
            VStack(spacing: 8) {
                Text(stockItem.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("SKU: \(stockItem.sku)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                categoryBadge
            }
        }
    }
    
    private var categoryBadge: some View {
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
    
    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Code QR")
                    .font(.headline)
                
                Spacer()
                
                Button("Partager") {
                    showingQRShare = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if let qrImage = qrCodeImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 2)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 150, height: 150)
                    .overlay(
                        ProgressView()
                    )
            }
            
            Text("SKU: \(stockItem.sku)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var tagsSection: some View {
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
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80), spacing: 8)
                ], spacing: 8) {
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
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Détails techniques")
                .font(.headline)
            
            VStack(spacing: 12) {
                detailRow("Poids unitaire", String(format: "%.2f kg", stockItem.unitWeight))
                detailRow("Volume unitaire", String(format: "%.3f m³", stockItem.unitVolume))
                detailRow("Valeur unitaire", String(format: "%.2f €", stockItem.unitValue))
                
                if !stockItem.substituables.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Articles substituables")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
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
    
    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Disponibilité")
                .font(.headline)
            
            HStack(spacing: 24) {
                availabilityCard(
                    title: "Total",
                    count: stockItem.totalQuantity,
                    color: .blue
                )
                
                availabilityCard(
                    title: "Disponible",
                    count: stockItem.availableQuantity,
                    color: stockItem.availableQuantity > 0 ? .green : .red
                )
                
                if stockItem.maintenanceQuantity > 0 {
                    availabilityCard(
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
    
    private var serializedAssetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Assets individuels (\(filteredAssets.count))")
                    .font(.headline)
                
                Spacer()
                
                Button("Voir tout") {
                    // TODO: Navigation vers liste complète
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(Array(filteredAssets.prefix(5)), id: \.assetId) { asset in
                    AssetRow(asset: asset)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var movementHistorySection: some View {
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
            
            if relatedMovements.isEmpty {
                Text("Aucun mouvement enregistré")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(relatedMovements.prefix(5)), id: \.movementId) { movement in
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
    
    private func detailRow(_ title: String, _ value: String) -> some View {
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
    
    private func availabilityCard(title: String, count: Int, color: Color) -> some View {
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
    
    private func generateQRCode() {
        let qrPayload = """
        {
            "v": 1,
            "type": "stock",
            "sku": "\(stockItem.sku)",
            "name": "\(stockItem.name)",
            "category": "\(stockItem.category)"
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
}

struct AssetRow: View {
    let asset: Asset
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cube.box")
                .font(.title3)
                .foregroundColor(Color(asset.status.color))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.assetId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let serialNumber = asset.serialNumber {
                    Text("S/N: \(serialNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(asset.status.color))
                
                if let location = asset.currentLocationId {
                    Text(location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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

#Preview {
    let container = try! ModelContainer(
        for: StockItem.self, Asset.self, Movement.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let sampleItem = StockItem(
        sku: "LED-SPOT-50W",
        name: "Projecteur LED 50W",
        category: "Éclairage",
        totalQuantity: 25,
        unitWeight: 2.5,
        unitVolume: 0.01,
        unitValue: 150.0,
        tags: ["LED", "Éclairage", "50W", "Extérieur"]
    )
    
    return StockItemDetailView(stockItem: sampleItem)
        .modelContainer(container)
}

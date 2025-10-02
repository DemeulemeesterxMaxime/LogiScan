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
    @State private var showingEditForm = false
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
                    HeaderSectionView(stockItem: stockItem)
                    
                    // Code QR
                    QRCodeSectionView(
                        qrCodeImage: qrCodeImage,
                        sku: stockItem.sku,
                        showingQRShare: $showingQRShare
                    )
                    
                    // Étiquettes
                    TagsSectionView(
                        stockItem: stockItem,
                        showingTagEditor: $showingTagEditor
                    )
                    
                    // Détails techniques
                    DetailsSectionView(stockItem: stockItem)
                    
                    // Localisation et disponibilité
                    AvailabilitySectionView(stockItem: stockItem)
                    
                    // Assets individuels (si sérialisés)
                    if !filteredAssets.isEmpty {
                        SerializedAssetsSectionView(assets: Array(filteredAssets.prefix(5)))
                    }
                    
                    // Historique des mouvements récents
                    MovementHistorySectionView(
                        movements: Array(relatedMovements.prefix(5)),
                        showingLocationHistory: $showingLocationHistory
                    )
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
                        Button("Modifier l'article", systemImage: "pencil") {
                            showingEditForm = true
                        }
                        
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
        .sheet(isPresented: $showingEditForm) {
            StockItemFormView(editingItem: stockItem)
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
    
    func generateQRCode() {
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

// MARK: - Header Section

struct HeaderSectionView: View {
    let stockItem: StockItem
    
    var body: some View {
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
        }
    }
}

// MARK: - QR Code Section

struct QRCodeSectionView: View {
    let qrCodeImage: UIImage?
    let sku: String
    @Binding var showingQRShare: Bool
    
    var body: some View {
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
                    .frame(width: 189, height: 189)  // 5cm à 72 DPI
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 2)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 189, height: 189)  // 5cm à 72 DPI
                    .overlay(
                        ProgressView()
                    )
            }
            
            Text("SKU: \(sku)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Tags Section

struct TagsSectionView: View {
    let stockItem: StockItem
    @Binding var showingTagEditor: Bool
    
    var body: some View {
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
}

// MARK: - Details Section

struct DetailsSectionView: View {
    let stockItem: StockItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Détails techniques")
                .font(.headline)
            
            VStack(spacing: 12) {
                DetailRow(title: "Poids unitaire", value: String(format: "%.2f kg", stockItem.unitWeight))
                DetailRow(title: "Volume unitaire", value: String(format: "%.3f m³", stockItem.unitVolume))
                DetailRow(title: "Valeur unitaire", value: String(format: "%.2f €", stockItem.unitValue))
                
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
}

struct DetailRow: View {
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

// MARK: - Availability Section

struct AvailabilitySectionView: View {
    let stockItem: StockItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Disponibilité")
                .font(.headline)
            
            HStack(spacing: 24) {
                AvailabilityCard(
                    title: "Total",
                    count: stockItem.totalQuantity,
                    color: .blue
                )
                
                AvailabilityCard(
                    title: "Disponible",
                    count: stockItem.availableQuantity,
                    color: stockItem.availableQuantity > 0 ? .green : .red
                )
                
                if stockItem.maintenanceQuantity > 0 {
                    AvailabilityCard(
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
}

struct AvailabilityCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
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
}

// MARK: - Serialized Assets Section

struct SerializedAssetsSectionView: View {
    let assets: [Asset]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Assets individuels (\(assets.count))")
                    .font(.headline)
                
                Spacer()
                
                Button("Voir tout") {
                    // TODO: Navigation vers liste complète
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(assets, id: \.assetId) { asset in
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

// MARK: - Movement History Section

struct MovementHistorySectionView: View {
    let movements: [Movement]
    @Binding var showingLocationHistory: Bool
    
    var body: some View {
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
            
            if movements.isEmpty {
                Text("Aucun mouvement enregistré")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(movements, id: \.movementId) { movement in
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
        tags: ["LED", "Éclairage", "50W", "Extérieur"]
    )
    
    StockItemDetailView(stockItem: sampleItem)
        .modelContainer(for: [StockItem.self, Asset.self, Movement.self], inMemory: true)
}

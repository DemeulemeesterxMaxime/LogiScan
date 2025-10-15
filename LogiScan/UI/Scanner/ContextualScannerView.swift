//
//  ContextualScannerView.swift
//  LogiScan
//
//  Created by Assistant on 15/10/2025.
//

import SwiftUI
import AVFoundation

struct ContextualScannerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let scanList: ScanList
    let onScanComplete: (ScannedAssetResult) -> Void
    
    @State private var isScanning = true
    @State private var scannedCode: String? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Items en attente de scan
    private var pendingItems: [PreparationListItem] {
        scanList.items.filter { !$0.isComplete }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Scanner
                if isScanning {
                    QRScannerView(
                        scannedCode: $scannedCode,
                        isScanning: $isScanning,
                        onCodeScanned: { code in
                            handleScan(code)
                        }
                    )
                    .ignoresSafeArea()
                }
                
                VStack {
                    Spacer()
                    
                    // Overlay avec infos contextuelles
                    contextualOverlay
                        .padding()
                }
            }
            .navigationTitle("Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .alert("Erreur de scan", isPresented: $showError) {
                Button("OK") {
                    scannedCode = nil
                    isScanning = true
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Contextual Overlay
    
    private var contextualOverlay: some View {
        VStack(spacing: 16) {
            // Progression
            HStack {
                Text("Progression")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(scanList.scannedItems)/\(scanList.totalItems)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // Barre de progression
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * scanList.progress)
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
            
            // Articles en attente
            if !pendingItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Articles à scanner :")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(pendingItems.prefix(3), id: \.preparationListItemId) { item in
                                HStack {
                                    Image(systemName: item.status.icon)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text(item.name)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(item.remainingQuantity) restant")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            if pendingItems.count > 3 {
                                Text("+ \(pendingItems.count - 3) autres")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            } else {
                // Tous les articles sont scannés
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Tous les articles sont scannés !")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
                .shadow(radius: 10)
        )
    }
    
    // MARK: - Scan Handling
    
    private func handleScan(_ code: String) {
        print("📱 [ContextualScannerView] Code scanné: \(code)")
        
        isScanning = false
        
        // Parser le QR code (format: "ASSET:assetId:sku")
        let components = code.split(separator: ":").map(String.init)
        
        guard components.count >= 3,
              components[0] == "ASSET" else {
            errorMessage = "Format de QR code invalide. Scannez un QR code d'asset."
            showError = true
            return
        }
        
        let assetId = components[1]
        let sku = components[2]
        
        // Créer le résultat
        let result = ScannedAssetResult(assetId: assetId, sku: sku)
        
        // Callback
        onScanComplete(result)
        
        // Fermer
        dismiss()
    }
}

// Modèle pour le résultat de scan d'asset
struct ScannedAssetResult {
    let assetId: String
    let sku: String
}

#Preview {
    NavigationStack {
        ContextualScannerView(
            scanList: ScanList(
                eventId: "1",
                eventName: "Concert Test",
                totalItems: 10,
                scannedItems: 3
            ),
            onScanComplete: { result in
                print("Scanné: \(result.assetId)")
            }
        )
    }
    .modelContainer(for: [ScanList.self], inMemory: true)
}

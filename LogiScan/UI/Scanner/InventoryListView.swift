//
//  InventoryListView.swift
//  LogiScan
//
//  Created by Assistant on 13/11/2025.
//

import SwiftUI
import SwiftData

/// Vue pour afficher la liste des articles scannés en inventaire
struct InventoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allAssets: [Asset]
    
    let session: InventorySession
    @StateObject private var service = InventorySessionService()
    
    @State private var showCompleteAlert = false
    @State private var showShareSheet = false
    @State private var csvData: String = ""
    
    var scannedAssets: [Asset] {
        allAssets.filter { session.scannedAssetIds.contains($0.assetId) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header avec stats
                headerSection
                
                // Liste des articles
                if scannedAssets.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(scannedAssets, id: \.assetId) { asset in
                                NavigationLink(destination: AssetDetailView(asset: asset)) {
                                    assetRow(asset)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
                
                // Boutons d'actions
                if !session.isCompleted {
                    actionButtons
                }
            }
            .navigationTitle("Inventaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
                
                if !scannedAssets.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            exportToCSV()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .alert("Terminer l'inventaire ?", isPresented: $showCompleteAlert) {
                Button("Annuler", role: .cancel) {}
                Button("Terminer") {
                    completeSession()
                }
            } message: {
                Text("Cela marquera la session comme complétée et vous ne pourrez plus ajouter d'articles.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [csvData])
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session d'inventaire")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(session.createdAt, style: .date)
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(session.totalCount)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    
                    Text("articles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if session.isCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Session terminée")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                    if let completedAt = session.completedAt {
                        Text(completedAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Asset Row
    
    private func assetRow(_ asset: Asset) -> some View {
        HStack(spacing: 12) {
            // Icône
            ZStack {
                Circle()
                    .fill(asset.status.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "cube.box.fill")
                    .foregroundColor(asset.status.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("SKU: \(asset.sku)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(asset.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Statut
            Text(asset.status.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(asset.status.color.opacity(0.15))
                .foregroundColor(asset.status.color)
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Aucun article scanné")
                .font(.headline)
            
            Text("Commencez à scanner des articles pour les voir apparaître ici")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showCompleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Terminer l'inventaire")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(scannedAssets.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Actions
    
    private func completeSession() {
        Task {
            do {
                try await service.completeSession(session: session, modelContext: modelContext)
            } catch {
                print("❌ Erreur complétion session: \(error)")
            }
        }
    }
    
    private func exportToCSV() {
        csvData = service.exportToCSV(session: session, assets: scannedAssets)
        showShareSheet = true
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    let session = InventorySession(createdBy: "user123")
    session.addAsset("asset1")
    session.addAsset("asset2")
    session.addAsset("asset3")
    
    return InventoryListView(session: session)
        .modelContainer(for: [InventorySession.self, Asset.self])
}

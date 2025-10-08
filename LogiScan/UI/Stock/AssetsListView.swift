//
//  AssetsListView.swift
//  LogiScan
//
//  Created by Demeulemeester on 02/10/2025.
//

import SwiftData
import SwiftUI

struct AssetsListView: View {
    let assets: [Asset]
    @Binding var selectedAsset: Asset?
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedStatus: AssetStatus?
    @State private var localSelectedAsset: Asset? = nil

    var filteredAssets: [Asset] {
        var result = assets

        // Filtrer par recherche
        if !searchText.isEmpty {
            result = result.filter { asset in
                asset.assetId.lowercased().contains(searchText.lowercased())
                    || asset.name.lowercased().contains(searchText.lowercased())
                    || (asset.serialNumber?.lowercased().contains(searchText.lowercased()) ?? false)
                    || (asset.currentLocationId?.lowercased().contains(searchText.lowercased())
                        ?? false)
            }
        }

        // Filtrer par statut
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }

        return result.sorted { $0.assetId < $1.assetId }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Statistiques rapides
                HStack(spacing: 12) {
                    StatusBadge(
                        status: .available, count: assets.filter { $0.status == .available }.count)
                    StatusBadge(
                        status: .reserved, count: assets.filter { $0.status == .reserved }.count)
                    StatusBadge(status: .inUse, count: assets.filter { $0.status == .inUse }.count)
                    StatusBadge(
                        status: .maintenance,
                        count: assets.filter { $0.status == .maintenance }.count)
                }
                .padding()
                .background(Color(.systemGray6))

                // Filtres par statut
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterChip(title: "Tous", isSelected: selectedStatus == nil) {
                            selectedStatus = nil
                        }

                        ForEach(AssetStatus.allCases, id: \.self) { status in
                            FilterChip(
                                title: status.displayName,
                                icon: status.icon,
                                isSelected: selectedStatus == status
                            ) {
                                selectedStatus = status
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))

                Divider()

                // Liste des assets
                if filteredAssets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("Aucun asset trouvé")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if !searchText.isEmpty {
                            Text("Essayez de modifier votre recherche")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredAssets, id: \.assetId) { asset in
                            Button {
                                localSelectedAsset = asset
                            } label: {
                                AssetListRow(asset: asset)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.visible)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Références individuelles (\(assets.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher une référence...")
            .sheet(item: $localSelectedAsset) { asset in
                AssetDetailView(asset: asset)
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: AssetStatus
    let count: Int

    var body: some View {
        VStack(spacing: 6) {
            // Nombre
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(status.swiftUIColor)

            // Icône + Nom
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.caption2)
                    .foregroundColor(status.swiftUIColor)
                
                Text(status.shortDisplayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status.swiftUIColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(status.swiftUIColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Asset List Row

struct AssetListRow: View {
    let asset: Asset

    var body: some View {
        HStack(spacing: 12) {
            // ID de la référence
            Text(asset.assetId)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .leading)
            
            // STATUT - Badge compact
            HStack(spacing: 4) {
                Image(systemName: asset.status.icon)
                    .font(.caption2)
                    .foregroundColor(.white)
                
                Text(asset.status.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(asset.status.swiftUIColor)
            )
            
            // LOCALISATION
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Text(asset.currentLocationId ?? "—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selectedAsset: Asset? = nil

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Asset.self, configurations: config)

    let sampleAssets = (1...20).map { i in
        let asset = Asset(
            assetId: "LED-50W-\(String(format: "%03d", i))",
            sku: "LED-SPOT-50W",
            name: "Projecteur LED 50W",
            category: "Éclairage",
            serialNumber: "SN-2025-\(String(format: "%03d", i))",
            status: [AssetStatus.available, .reserved, .inUse, .maintenance].randomElement()!,
            weight: 2.5,
            volume: 0.01,
            value: 150.0,
            qrPayload: "LED-50W-\(String(format: "%03d", i))",
            tags: i % 3 == 0 ? ["LED", "Urgent"] : ["LED"]
        )
        asset.currentLocationId = ["Entrepôt A", "Entrepôt B", "En transit"].randomElement()
        return asset
    }

    for asset in sampleAssets {
        container.mainContext.insert(asset)
    }

    return AssetsListView(assets: sampleAssets, selectedAsset: $selectedAsset)
        .modelContainer(container)
}

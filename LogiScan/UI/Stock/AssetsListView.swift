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
                                selectedAsset = asset
                                dismiss()
                            } label: {
                                AssetListRow(asset: asset)
                            }
                            .buttonStyle(.plain)
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
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: AssetStatus
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Color(status.color))

            Image(systemName: status.icon)
                .font(.caption)
                .foregroundColor(Color(status.color))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(status.color).opacity(0.15))
        )
    }
}

// MARK: - Asset List Row

struct AssetListRow: View {
    let asset: Asset

    var body: some View {
        HStack(spacing: 14) {
            // Icône statut
            ZStack {
                Circle()
                    .fill(Color(asset.status.color).opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "cube.box.fill")
                    .font(.title3)
                    .foregroundColor(Color(asset.status.color))
            }

            VStack(alignment: .leading, spacing: 6) {
                // Asset ID + Badge statut
                HStack(spacing: 8) {
                    Text(asset.assetId)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(asset.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(asset.status.color).opacity(0.2))
                        )
                        .foregroundColor(Color(asset.status.color))
                }

                // Numéro de série
                if let serialNumber = asset.serialNumber {
                    HStack(spacing: 4) {
                        Image(systemName: "barcode")
                            .font(.caption2)
                        Text("S/N: \(serialNumber)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                // Localisation
                if let location = asset.currentLocationId {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.blue)
                }

                // Tags (max 3)
                if !asset.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(asset.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange.opacity(0.2))
                                )
                                .foregroundColor(.orange)
                        }

                        if asset.tags.count > 3 {
                            Text("+\(asset.tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
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

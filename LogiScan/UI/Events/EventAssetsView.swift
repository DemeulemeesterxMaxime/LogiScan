//
//  EventAssetsView.swift
//  LogiScan
//
//  Created by Demeulemeester on 08/10/2025.
//

import SwiftData
import SwiftUI

struct EventAssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assets: [Asset]
    @Query private var reservations: [AssetReservation]

    let event: Event
    let quoteItem: QuoteItem

    @State private var assignedAssets: [Asset] = []
    @State private var showingAssetSelector = false
    @State private var showingScanner = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var itemReservations: [AssetReservation] {
        reservations.filter {
            $0.eventId == event.eventId && quoteItem.assignedAssets.contains($0.assetId)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // En-tête
                VStack(alignment: .leading, spacing: 8) {
                    Text(quoteItem.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack {
                        Label("SKU: \(quoteItem.sku)", systemImage: "barcode")
                        Spacer()
                        Text("\(quoteItem.quantity) unités")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                // Assets assignés
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Assets assignés")
                            .font(.headline)

                        Spacer()

                        Text("\(assignedAssets.count)/\(quoteItem.quantity)")
                            .font(.subheadline)
                            .foregroundColor(
                                assignedAssets.count == quoteItem.quantity ? .green : .orange)
                    }

                    if assignedAssets.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)

                            Text("Aucun asset assigné")
                                .font(.headline)

                            Text("Sélectionnez des assets pour cet article du devis")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(assignedAssets) { asset in
                            AssignedAssetRow(
                                asset: asset,
                                reservation: itemReservations.first { $0.assetId == asset.assetId },
                                onRemove: {
                                    removeAsset(asset)
                                },
                                onScanLoaded: {
                                    updateReservationStatus(for: asset, status: .loaded)
                                },
                                onScanReturned: {
                                    updateReservationStatus(for: asset, status: .returned)
                                }
                            )
                        }
                    }
                }

                // Actions
                VStack(spacing: 12) {
                    Button(action: { showingAssetSelector = true }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Modifier la sélection")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: { showingScanner = true }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scanner pour charger/retourner")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Gestion des assets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAssignedAssets()
        }
        .sheet(isPresented: $showingAssetSelector) {
            AssetSelectorView(
                sku: quoteItem.sku,
                quantity: quoteItem.quantity,
                selectedAssets: assignedAssets,
                onSave: { selectedAssets in
                    updateAssignedAssets(selectedAssets)
                }
            )
        }
        .sheet(isPresented: $showingScanner) {
            SimpleScannerView { result in
                handleScanResult(result)
            }
        }
        .alert("Information", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Actions

    private func loadAssignedAssets() {
        assignedAssets = assets.filter { quoteItem.assignedAssets.contains($0.assetId) }
    }

    private func removeAsset(_ asset: Asset) {
        assignedAssets.removeAll { $0.assetId == asset.assetId }

        // Mettre à jour le QuoteItem
        quoteItem.assignedAssets.removeAll { $0 == asset.assetId }

        // Supprimer la réservation
        if let reservation = itemReservations.first(where: { $0.assetId == asset.assetId }) {
            modelContext.delete(reservation)
        }

        try? modelContext.save()
    }

    private func updateAssignedAssets(_ selectedAssets: [Asset]) {
        assignedAssets = selectedAssets
        quoteItem.assignedAssets = selectedAssets.map { $0.assetId }

        // Créer/mettre à jour les réservations
        for asset in selectedAssets {
            if !itemReservations.contains(where: { $0.assetId == asset.assetId }) {
                let reservation = AssetReservation(
                    reservationId: UUID().uuidString,
                    assetId: asset.assetId,
                    eventId: event.eventId,
                    startDate: event.startDate,
                    endDate: event.endDate
                )
                modelContext.insert(reservation)
            }
        }

        try? modelContext.save()
    }

    private func updateReservationStatus(for asset: Asset, status: ReservationStatus) {
        if let reservation = itemReservations.first(where: { $0.assetId == asset.assetId }) {
            reservation.status = status
            try? modelContext.save()

            alertMessage =
                status == .loaded ? "Asset chargé avec succès" : "Asset retourné avec succès"
            showAlert = true
        }
    }

    private func handleScanResult(_ result: ScanResult) {
        // Extraire l'assetId depuis le rawPayload ou l'asset
        let assetId: String?
        if let asset = result.asset {
            assetId = asset.assetId
        } else {
            assetId = result.rawPayload
        }
        
        // Vérifier si l'asset scanné est dans la liste
        if let assetId = assetId,
            let asset = assignedAssets.first(where: { $0.assetId == assetId })
        {

            if let reservation = itemReservations.first(where: { $0.assetId == assetId }) {
                // Mettre à jour le statut selon l'état actuel
                switch reservation.status {
                case .pending, .confirmed:
                    updateReservationStatus(for: asset, status: .loaded)
                case .loaded, .delivered:
                    updateReservationStatus(for: asset, status: .returned)
                case .returned:
                    alertMessage = "Cet asset a déjà été retourné"
                    showAlert = true
                case .cancelled:
                    alertMessage = "Cette réservation a été annulée"
                    showAlert = true
                }
            }
        } else {
            alertMessage = "Cet asset n'est pas assigné à cet article"
            showAlert = true
        }
    }
}

// MARK: - Supporting Views

struct AssignedAssetRow: View {
    let asset: Asset
    let reservation: AssetReservation?
    let onRemove: () -> Void
    let onScanLoaded: () -> Void
    let onScanReturned: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Statut
                statusIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text("Asset #\(asset.assetId)")
                        .font(.headline)

                    Text("S/N: \(asset.serialNumber ?? "N/A")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Actions
                Menu {
                    Button(action: onScanLoaded) {
                        Label("Marquer comme chargé", systemImage: "checkmark.circle")
                    }

                    Button(action: onScanReturned) {
                        Label("Marquer comme retourné", systemImage: "arrow.uturn.left.circle")
                    }

                    Divider()

                    Button(role: .destructive, action: onRemove) {
                        Label("Retirer de la liste", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }

            // Localisation
            if let location = asset.currentLocationId {
                Label(location, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Statut réservation
            if let reservation = reservation {
                HStack {
                    Circle()
                        .fill(reservationStatusColor(reservation.status))
                        .frame(width: 8, height: 8)

                    Text(reservation.status.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var statusIcon: some View {
        Group {
            switch asset.status {
            case .available:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .reserved:
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
            case .inUse:
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
            case .inTransitToEvent:
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(.cyan)
            case .inTransitToStock:
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .foregroundColor(.teal)
            case .damaged:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            case .maintenance:
                Image(systemName: "wrench.fill")
                    .foregroundColor(.orange)
            case .lost:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .font(.title2)
    }

    private func reservationStatusColor(_ status: ReservationStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .confirmed: return .blue
        case .loaded: return .green
        case .delivered: return .purple
        case .returned: return .teal
        case .cancelled: return .red
        }
    }
}

struct AssetSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allAssets: [Asset]

    let sku: String
    let quantity: Int
    @State var selectedAssets: [Asset]
    let onSave: ([Asset]) -> Void

    private var availableAssets: [Asset] {
        allAssets.filter { $0.sku == sku && $0.status == .available }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Sélectionnez \(quantity) asset(s)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("Assets disponibles") {
                    ForEach(availableAssets) { asset in
                        Button(action: { toggleSelection(asset) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Asset #\(asset.assetId)")
                                        .font(.headline)

                                    if let serialNumber = asset.serialNumber {
                                        Text("S/N: \(serialNumber)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if selectedAssets.contains(where: { $0.assetId == asset.assetId }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Sélectionner des assets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        onSave(selectedAssets)
                        dismiss()
                    }
                    .disabled(selectedAssets.count != quantity)
                }
            }
        }
    }

    private func toggleSelection(_ asset: Asset) {
        if let index = selectedAssets.firstIndex(where: { $0.assetId == asset.assetId }) {
            selectedAssets.remove(at: index)
        } else if selectedAssets.count < quantity {
            selectedAssets.append(asset)
        }
    }
}

#Preview {
    NavigationStack {
        EventAssetsView(
            event: Event(
                eventId: "1",
                name: "Test Event",
                clientName: "Test Client",
                clientPhone: "123",
                clientEmail: "test@test.com",
                clientAddress: "Test Address",
                eventAddress: "Test Event Address",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400)
            ),
            quoteItem: QuoteItem(
                quoteItemId: "1",
                eventId: "1",
                sku: "TEST-001",
                name: "Test Item",
                category: "Test",
                quantity: 5,
                unitPrice: 100.0
            )
        )
    }
    .modelContainer(
        for: [Event.self, QuoteItem.self, Asset.self, AssetReservation.self], inMemory: true)
}

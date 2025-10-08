//
//  TrucksListView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftData
import SwiftUI

struct TrucksListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trucks: [Truck]
    @StateObject private var syncManager = SyncManager()
    @State private var selectedStatus: TruckStatus? = nil
    @State private var searchText = ""
    @State private var isRefreshing = false

    var filteredTrucks: [Truck] {
        var items = trucks

        if let status = selectedStatus {
            items = items.filter { $0.status == status }
        }

        let searchedItems = items.filteredBySearch(searchText)
        return searchedItems.sorted { $0.licensePlate < $1.licensePlate }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Résumé rapide
                trucksSummary

                // Filtres par statut
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "Tous",
                            isSelected: selectedStatus == nil,
                            action: { selectedStatus = nil }
                        )

                        ForEach(TruckStatus.allCases, id: \.self) { status in
                            FilterChip(
                                title: status.displayName,
                                isSelected: selectedStatus == status,
                                action: { selectedStatus = status }
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // Liste des camions
                List(filteredTrucks) { truck in
                    TruckRow(truck: truck)
                }
                .searchable(text: $searchText, prompt: "Rechercher un camion...")
                .listStyle(.plain)
                .refreshable {
                    await refreshData()
                }
                .overlay {
                    if syncManager.isSyncing {
                        VStack {
                            ProgressView("Synchronisation...")
                                .padding()
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                    }
                }
            }
            .navigationTitle("Flotte")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let lastSync = syncManager.lastSyncDate {
                        Text(lastSync.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await refreshData()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                        
                        Button(action: { /* TODO: Ajouter camion */  }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .onAppear {
                // Rafraîchissement automatique à l'arrivée sur la page
                Task {
                    await syncManager.syncFromFirebaseIfNeeded(modelContext: modelContext, forceRefresh: true)
                }
            }
        }
    }
    
    // MARK: - Refresh Function
    
    private func refreshData() async {
        print("🔄 [TrucksListView] Pull-to-refresh déclenché")
        isRefreshing = true
        await syncManager.syncFromFirebase(modelContext: modelContext)
        isRefreshing = false
    }

    private var trucksSummary: some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: "Disponibles",
                count: trucks.filter { $0.status == .available }.count,
                color: .green
            )

            SummaryCard(
                title: "En mission",
                count: trucks.filter { [.loading, .enRoute, .atSite].contains($0.status) }.count,
                color: .blue
            )

            SummaryCard(
                title: "Maintenance",
                count: trucks.filter { $0.status == .maintenance }.count,
                color: .red
            )
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

struct TruckRow: View {
    let truck: Truck

    var body: some View {
        HStack(spacing: 16) {
            // Icône et plaque
            VStack(spacing: 4) {
                Image(systemName: "truck.box")
                    .font(.title2)
                    .foregroundColor(Color(truck.status.color))

                Text(truck.licensePlate)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(width: 80)

            // Infos principales
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Camion \(truck.truckId)")
                        .font(.headline)

                    Spacer()

                    statusBadge(truck.status)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Capacité")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(String(format: "%.0f kg", truck.maxWeight))
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Volume")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(String(format: "%.0f m³", truck.maxVolume))
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }

                if let driverId = truck.currentDriverId {
                    Label("Chauffeur: \(driverId)", systemImage: "person.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func statusBadge(_ status: TruckStatus) -> some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(status.color).opacity(0.2))
            )
            .foregroundColor(Color(status.color))
    }
}

struct SummaryCard: View {
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

#Preview {
    TrucksListView()
        .modelContainer(for: [Truck.self], inMemory: true)
}

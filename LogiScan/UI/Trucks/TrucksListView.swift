//
//  TrucksListView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftUI
import SwiftData

struct TrucksListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trucks: [Truck]
    @State private var selectedStatus: TruckStatus? = nil
    @State private var searchText = ""
    
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
            }
            .navigationTitle("Flotte")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addSampleData) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            if trucks.isEmpty {
                addSampleData()
            }
        }
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
    
    private func addSampleData() {
        let sampleTrucks = [
            Truck(
                truckId: "T001",
                licensePlate: "AB-123-CD",
                maxVolume: 25.0,
                maxWeight: 3500.0,
                status: .available
            ),
            Truck(
                truckId: "T002",
                licensePlate: "EF-456-GH",
                maxVolume: 40.0,
                maxWeight: 7500.0,
                status: .loading
            ),
            Truck(
                truckId: "T003",
                licensePlate: "IJ-789-KL",
                maxVolume: 30.0,
                maxWeight: 5000.0,
                status: .enRoute
            ),
            Truck(
                truckId: "T004",
                licensePlate: "MN-012-OP",
                maxVolume: 35.0,
                maxWeight: 6000.0,
                status: .maintenance
            )
        ]
        
        for truck in sampleTrucks {
            modelContext.insert(truck)
        }
        
        try? modelContext.save()
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
    let container = try! ModelContainer(
        for: Truck.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    return TrucksListView()
        .modelContainer(container)
}

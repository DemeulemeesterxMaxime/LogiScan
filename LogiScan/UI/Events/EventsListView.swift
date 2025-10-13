//
//  EventsListView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftData
import SwiftUI

struct EventsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @StateObject private var syncManager = SyncManager()
    @State private var selectedStatus: EventStatus? = nil
    @State private var searchText = ""
    @State private var showingEventForm = false
    @State private var isRefreshing = false

    var filteredEvents: [Event] {
        var items = events

        if let status = selectedStatus {
            items = items.filter { $0.status == status }
        }

        let searchedItems = items.filteredBySearch(searchText)
        return searchedItems.sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Filtres par statut
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "Tous",
                            isSelected: selectedStatus == nil,
                            action: { selectedStatus = nil }
                        )

                        ForEach(EventStatus.allCases, id: \.self) { status in
                            FilterChip(
                                title: status.displayName,
                                isSelected: selectedStatus == status,
                                action: { selectedStatus = status }
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // Liste des événements
                List(filteredEvents) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventRow(event: event)
                    }
                }
                .searchable(text: $searchText, prompt: "Rechercher un événement...")
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
            .navigationTitle("Événements")
            .refreshable {
                await syncManager.syncFromFirebase(modelContext: modelContext)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEventForm = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                    .requiresPermission(.writeEvents)
                }
            }
            .sheet(isPresented: $showingEventForm) {
                CreateEventView()
            }
            .onAppear {
                // Rafraîchissement automatique immédiat à l'arrivée
                Task {
                    print("🔄 [EventsListView] Rafraîchissement automatique au chargement")
                    await syncManager.syncFromFirebase(modelContext: modelContext)
                }
            }
        }
    }

    // MARK: - Refresh Function

    private func refreshData() async {
        print("🔄 [EventsListView] Pull-to-refresh déclenché")
        isRefreshing = true
        await syncManager.syncFromFirebase(modelContext: modelContext)
        isRefreshing = false
    }
}

struct EventRow: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // En-tête avec nom et statut
            HStack {
                Text(event.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                statusBadge(event.status)
            }

            // Client
            Label(event.clientName, systemImage: "person.circle")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Dates
            HStack {
                Label("", systemImage: "calendar")
                    .labelStyle(.iconOnly)
                    .foregroundColor(.secondary)

                Text("\(event.startDate.formatted(date: .abbreviated, time: .omitted))")

                if !Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
                    Text("→ \(event.endDate.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Date de modification
            HStack {
                Label("", systemImage: "clock")
                    .labelStyle(.iconOnly)
                    .foregroundColor(.secondary)
                
                Text("Modifié: \(event.updatedAt.formatted(date: .abbreviated, time: .shortened))")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Lieu
            Label(event.eventAddress, systemImage: "location")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ status: EventStatus) -> some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(status.swiftUIColor.opacity(0.2))
            )
            .foregroundColor(status.swiftUIColor)
    }
}

#Preview {
    EventsListView()
        .modelContainer(for: [Event.self], inMemory: true)
}

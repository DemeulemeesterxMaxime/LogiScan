//
//  EventsListView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftUI
import SwiftData

struct EventsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @State private var selectedStatus: EventStatus? = nil
    @State private var searchText = ""
    
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
                    EventRow(event: event)
                }
                .searchable(text: $searchText, prompt: "Rechercher un événement...")
                .listStyle(.plain)
            }
            .navigationTitle("Événements")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addSampleData) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            if events.isEmpty {
                addSampleData()
            }
        }
    }
    
    private func addSampleData() {
        let calendar = Calendar.current
        let today = Date()
        
        let sampleEvents = [
            Event(
                eventId: "EVT001",
                name: "Concert Jazz Festival",
                clientName: "Ville de Paris",
                clientPhone: "01 42 76 40 40",
                clientEmail: "contact@paris.fr",
                clientAddress: "Hôtel de Ville, Place de l'Hôtel-de-Ville, 75004 Paris",
                eventAddress: "Place de la République, 75003 Paris",
                startDate: calendar.date(byAdding: .day, value: 5, to: today)!,
                endDate: calendar.date(byAdding: .day, value: 7, to: today)!,
                status: .confirmed,
                notes: "Événement en plein air, prévoir bâches de protection"
            ),
            Event(
                eventId: "EVT002",
                name: "Mariage Château de Versailles",
                clientName: "Martin & Sophie",
                clientPhone: "06 12 34 56 78",
                clientEmail: "martin.sophie@email.fr",
                clientAddress: "12 Rue des Lilas, 78000 Versailles",
                eventAddress: "Château de Versailles, 78000 Versailles",
                startDate: calendar.date(byAdding: .day, value: 12, to: today)!,
                endDate: calendar.date(byAdding: .day, value: 13, to: today)!,
                status: .preparation,
                notes: "Événement privé, accès limité"
            ),
            Event(
                eventId: "EVT003",
                name: "Salon Professionnel TechExpo",
                clientName: "TechExpo SAS",
                clientPhone: "01 56 78 90 12",
                clientEmail: "contact@techexpo.fr",
                clientAddress: "45 Avenue de la Grande Armée, 75016 Paris",
                eventAddress: "Porte de Versailles, 75015 Paris",
                startDate: calendar.date(byAdding: .day, value: -2, to: today)!,
                endDate: calendar.date(byAdding: .day, value: 1, to: today)!,
                status: .inProgress,
                notes: "Salon sur 3 jours, montage/démontage inclus"
            )
        ]
        
        for event in sampleEvents {
            modelContext.insert(event)
        }
        
        try? modelContext.save()
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
                    .fill(Color(status.color).opacity(0.2))
            )
            .foregroundColor(Color(status.color))
    }
}

#Preview {
    EventsListView()
        .modelContainer(for: [Event.self], inMemory: true)
}

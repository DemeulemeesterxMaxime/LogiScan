//
//  TruckDetailView.swift
//  LogiScan
//
//  Created by Demeulemeester on 09/10/2025.
//

import SwiftUI
import SwiftData
import UIKit

struct TruckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var events: [Event]
    
    let truck: Truck
    
    @State private var showDeleteConfirmation = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedPeriod: CalendarPeriod = .week
    @State private var showEditNameSheet = false
    @State private var editingName: String = ""
    
    var truckEvents: [Event] {
        events.filter { $0.assignedTruckId == truck.truckId }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // En-tête
                headerSection
                
                // Informations du camion
                truckInfoSection
                
                // Sélecteur de période
                periodSelector
                
                // Agenda
                agendaSection
                
                // Bouton supprimer
                Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Supprimer le camion")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.horizontal)
                .requiresPermission(.manageTrucks)
            }
            .padding(.vertical)
        }
        .navigationTitle(truck.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Êtes-vous sûr de vouloir supprimer ce camion ?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                deleteTruck()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est irréversible.")
        }
        .alert("Information", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showEditNameSheet) {
            editNameSheet
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "truck.box")
                .font(.system(size: 48))
                .foregroundColor(truck.status.swiftUIColor)
            
            HStack(spacing: 8) {
                Text(truck.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                
                Button(action: {
                    editingName = truck.name ?? ""
                    showEditNameSheet = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .requiresPermission(.manageTrucks)
            }
            
            if truck.name == nil || truck.name?.isEmpty == true {
                Text("Plaque: \(truck.licensePlate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(truck.status.displayName)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(truck.status.swiftUIColor.opacity(0.2))
                )
                .foregroundColor(truck.status.swiftUIColor)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var truckInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("characteristics".localized())
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Volume maximum", systemImage: "cube")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f m³", truck.maxVolume))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Poids maximum", systemImage: "scalemass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f kg", truck.maxWeight))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var periodSelector: some View {
        Picker("Période", selection: $selectedPeriod) {
            Text("week".localized()).tag(CalendarPeriod.week)
            Text("month".localized()).tag(CalendarPeriod.month)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("agenda".localized())
                    .font(.headline)
                
                Spacer()
                
                Text("\(truckEvents.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if selectedPeriod == .week {
                weekView
            } else {
                monthView
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var weekView: some View {
        let today = Date()
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let weekDays = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        
        return VStack(spacing: 6) {
            ForEach(weekDays, id: \.self) { day in
                let dayEvents = eventsForDate(day)
                if !dayEvents.isEmpty {
                    DayAgendaRow(date: day, events: dayEvents)
                }
            }
            
            if weekDays.filter({ !eventsForDate($0).isEmpty }).isEmpty {
                Text("Aucun événement cette semaine")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }
    
    private var monthView: some View {
        let today = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: startOfMonth) }
        
        return VStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                let dayEvents = eventsForDate(day)
                if !dayEvents.isEmpty {
                    DayAgendaRow(date: day, events: dayEvents)
                }
            }
            
            if days.filter({ !eventsForDate($0).isEmpty }).isEmpty {
                Text("Aucun événement ce mois-ci")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func eventsForDate(_ date: Date) -> [Event] {
        let calendar = Calendar.current
        return truckEvents.filter { event in
            calendar.isDate(event.setupStartTime, inSameDayAs: date) ||
            calendar.isDate(event.startDate, inSameDayAs: date) ||
            (event.setupStartTime...event.endDate).contains(date)
        }
    }
    
    // MARK: - Edit Name Sheet
    
    private var editNameSheet: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Nom du camion (optionnel)", text: $editingName)
                    
                    Text("Plaque d'immatriculation: \(truck.licensePlate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("identification".localized())
                } footer: {
                    Text("Si vous ajoutez un nom, celui-ci remplacera la plaque d'immatriculation dans l'application.")
                }
                
                Section {
                    Button(action: {
                        editingName = ""
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Supprimer le nom")
                        }
                        .foregroundColor(.red)
                    }
                } footer: {
                    Text("Le camion sera identifié par sa plaque d'immatriculation.")
                }
            }
            .navigationTitle("Modifier le nom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        showEditNameSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveTruckName()
                    }
                }
            }
        }
    }
    
    private func saveTruckName() {
        Task {
            do {
                // Mettre à jour SwiftData
                truck.name = editingName.isEmpty ? nil : editingName
                truck.updatedAt = Date()
                try modelContext.save()
                
                // Mettre à jour Firebase
                let firebaseService = FirebaseService()
                await firebaseService.updateTruck(truck)
                
                await MainActor.run {
                    showEditNameSheet = false
                    alertMessage = "Nom du camion mis à jour avec succès"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Erreur lors de la mise à jour: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func deleteTruck() {
        Task {
            do {
                // Supprimer de Firebase
                let firebaseService = FirebaseService()
                await firebaseService.deleteTruck(truck.truckId)
                
                // Supprimer de SwiftData
                modelContext.delete(truck)
                try modelContext.save()
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Erreur lors de la suppression: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum CalendarPeriod {
    case week
    case month
}

struct DayAgendaRow: View {
    let date: Date
    let events: [Event]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Date compacte
                HStack(spacing: 4) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(date.formatted(.dateTime.day()))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .frame(width: 50, alignment: .leading)
                
                Spacer()
                
                if events.isEmpty {
                    Text("free".localized())
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Text("\(events.count)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange.opacity(0.15))
                        )
                }
            }
            
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(events) { event in
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(event.status.swiftUIColor)
                                .frame(width: 2)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text("\(event.setupStartTime.formatted(date: .omitted, time: .shortened)) - \(event.endDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(6)
    }
}

#Preview {
    NavigationStack {
        TruckDetailView(truck: Truck(
            truckId: "TRUCK-001",
            licensePlate: "AB-123-CD",
            maxVolume: 40.0,
            maxWeight: 3500.0,
            status: .available
        ))
    }
    .modelContainer(for: [Truck.self, Event.self], inMemory: true)
}

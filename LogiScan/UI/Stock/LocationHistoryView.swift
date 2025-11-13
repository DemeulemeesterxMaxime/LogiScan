//
//  LocationHistoryView.swift
//  LogiScan
//
//  Created by Demeulemeester on 01/10/2025.
//

import SwiftData
import SwiftUI

struct LocationHistoryView: View {
    let sku: String
    @Environment(\.dismiss) private var dismiss

    @Query private var movements: [Movement]
    @State private var selectedPeriod: HistoryPeriod = .all
    @State private var selectedMovementType: MovementType? = nil

    var filteredMovements: [Movement] {
        var filtered = movements.filter { $0.sku == sku }

        // Filtrer par période
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            filtered = filtered.filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
        case .week:
            let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            filtered = filtered.filter { $0.timestamp >= oneWeekAgo }
        case .month:
            let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            filtered = filtered.filter { $0.timestamp >= oneMonthAgo }
        case .quarter:
            let oneQuarterAgo = calendar.date(byAdding: .month, value: -3, to: now)!
            filtered = filtered.filter { $0.timestamp >= oneQuarterAgo }
        case .all:
            break
        }

        // Filtrer par type de mouvement
        if let type = selectedMovementType {
            filtered = filtered.filter { $0.type == type }
        }

        return filtered.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filtres
                filtersSection

                // Statistiques rapides
                statisticsSection

                Divider()

                // Liste des mouvements
                movementsList
            }
            .navigationTitle("Historique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Exporter CSV", systemImage: "doc.text") {
                            exportToCSV()
                        }

                        Button("Partager", systemImage: "square.and.arrow.up") {
                            shareHistory()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var filtersSection: some View {
        VStack(spacing: 16) {
            // Sélecteur de période
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HistoryPeriod.allCases, id: \.self) { period in
                        Button(action: {
                            selectedPeriod = period
                        }) {
                            Text(period.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            selectedPeriod == period
                                                ? Color.blue : Color(.systemGray5))
                                )
                                .foregroundColor(selectedPeriod == period ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Sélecteur de type de mouvement
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "Tous les types",
                        isSelected: selectedMovementType == nil,
                        action: {
                            selectedMovementType = nil
                        }
                    )

                    ForEach(MovementType.allCases, id: \.self) { type in
                        FilterChip(
                            title: type.displayName,
                            isSelected: selectedMovementType == type,
                            action: {
                                selectedMovementType = type
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }

    private var statisticsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total",
                value: "\(filteredMovements.count)",
                subtitle: "mouvements"
            )

            StatCard(
                title: "Quantité",
                value: "\(filteredMovements.reduce(0) { $0 + $1.quantity })",
                subtitle: "articles"
            )

            StatCard(
                title: "Période",
                value: selectedPeriod.displayName,
                subtitle: "sélectionnée"
            )
        }
        .padding()
    }

    private var movementsList: some View {
        Group {
            if filteredMovements.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    Text("no_movement".localized())
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Aucun mouvement trouvé pour les critères sélectionnés")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupMovementsByDate(), id: \.date) { group in
                        Section(header: Text(group.date.formatted(date: .complete, time: .omitted)))
                        {
                            ForEach(group.movements, id: \.movementId) { movement in
                                DetailedMovementRow(movement: movement)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func groupMovementsByDate() -> [MovementGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredMovements) { movement in
            calendar.startOfDay(for: movement.timestamp)
        }

        return grouped.map { date, movements in
            MovementGroup(date: date, movements: movements.sorted { $0.timestamp > $1.timestamp })
        }.sorted { $0.date > $1.date }
    }

    private func exportToCSV() {
        // TODO: Implémenter l'export CSV
        print("Export CSV des mouvements")
    }

    private func shareHistory() {
        // TODO: Implémenter le partage de l'historique
        print("Partage de l'historique")
    }
}

struct DetailedMovementRow: View {
    let movement: Movement

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Icône et type
                HStack(spacing: 8) {
                    Image(systemName: movement.type.icon)
                        .font(.title3)
                        .foregroundColor(Color(movement.type.color))
                        .frame(width: 24)

                    Text(movement.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                // Heure
                Text(movement.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Détails du mouvement
            VStack(alignment: .leading, spacing: 4) {
                if let fromLocation = movement.fromLocationId,
                    let toLocation = movement.toLocationId
                {
                    HStack {
                        Label(fromLocation, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Label(toLocation, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let location = movement.fromLocationId ?? movement.toLocationId {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("Quantité: \(movement.quantity)", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let performedBy = movement.performedBy {
                        Label("Par: \(performedBy)", systemImage: "person")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !movement.notes.isEmpty {
                    Text(movement.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(.leading, 32)  // Alignement avec l'icône
        }
        .padding(.vertical, 4)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
}

struct MovementGroup {
    let date: Date
    let movements: [Movement]
}

enum HistoryPeriod: String, CaseIterable {
    case today = "today"
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case all = "all"

    var displayName: String {
        switch self {
        case .today: return "Aujourd'hui"
        case .week: return "7 jours"
        case .month: return "30 jours"
        case .quarter: return "3 mois"
        case .all: return "Tout"
        }
    }
}

#Preview {
    LocationHistoryView(sku: "LED-SPOT-50W")
        .modelContainer(for: [Movement.self], inMemory: true)
}

//
//  MovementRepository.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

@MainActor
protocol MovementRepositoryProtocol {
    func createMovement(_ movement: Movement) async throws
    func getMovementsByAsset(_ assetId: String) async throws -> [Movement]
    func getMovementsByEvent(_ eventId: String) async throws -> [Movement]
    func getUnsyncedMovements() async throws -> [Movement]
    func markMovementAsSynced(_ movementId: String) async throws
    func getRecentMovements(limit: Int) async throws -> [Movement]
}

@MainActor
class MovementRepository: ObservableObject, MovementRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createMovement(_ movement: Movement) async throws {
        modelContext.insert(movement)
        try modelContext.save()

        // Déclencher la sync en arrière-plan si possible
        Task {
            await attemptSync()
        }
    }

    func getMovementsByAsset(_ assetId: String) async throws -> [Movement] {
        let descriptor = FetchDescriptor<Movement>(
            predicate: #Predicate { $0.assetId == assetId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func getMovementsByEvent(_ eventId: String) async throws -> [Movement] {
        let descriptor = FetchDescriptor<Movement>(
            predicate: #Predicate { $0.eventId == eventId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func getUnsyncedMovements() async throws -> [Movement] {
        let descriptor = FetchDescriptor<Movement>(
            predicate: #Predicate { !$0.isSynced },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try modelContext.fetch(descriptor)
    }

    func markMovementAsSynced(_ movementId: String) async throws {
        let descriptor = FetchDescriptor<Movement>(
            predicate: #Predicate { $0.movementId == movementId }
        )
        guard let movement = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.assetNotFound
        }

        movement.isSynced = true
        try modelContext.save()
    }

    func getRecentMovements(limit: Int = 50) async throws -> [Movement] {
        var descriptor = FetchDescriptor<Movement>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    private func attemptSync() async {
        // TODO: Implémenter la synchronisation avec l'API
        do {
            let unsyncedMovements = try await getUnsyncedMovements()
            for movement in unsyncedMovements {
                // Tentative de sync avec l'API
                // Si succès, marquer comme synchronisé
                try await markMovementAsSynced(movement.movementId)
            }
        } catch {
            print("Sync failed: \(error)")
        }
    }
}

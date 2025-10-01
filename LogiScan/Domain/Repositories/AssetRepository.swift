//
//  AssetRepository.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

protocol AssetRepositoryProtocol {
    func getAllAssets() async throws -> [Asset]
    func getAssetById(_ id: String) async throws -> Asset?
    func getAssetsByLocation(_ locationId: String) async throws -> [Asset]
    func getAssetsByEvent(_ eventId: String) async throws -> [Asset]
    func saveAsset(_ asset: Asset) async throws
    func deleteAsset(_ asset: Asset) async throws
    func updateAssetLocation(_ assetId: String, locationId: String?) async throws
    func updateAssetStatus(_ assetId: String, status: AssetStatus) async throws
    func searchAssets(_ query: String) async throws -> [Asset]
}

@MainActor
class AssetRepository: ObservableObject, AssetRepositoryProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func getAllAssets() async throws -> [Asset] {
        let descriptor = FetchDescriptor<Asset>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func getAssetById(_ id: String) async throws -> Asset? {
        let descriptor = FetchDescriptor<Asset>(
            predicate: #Predicate { $0.assetId == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func getAssetsByLocation(_ locationId: String) async throws -> [Asset] {
        let descriptor = FetchDescriptor<Asset>(
            predicate: #Predicate { $0.currentLocationId == locationId },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func getAssetsByEvent(_ eventId: String) async throws -> [Asset] {
        // Logique pour récupérer les assets associés à un événement
        // via les commandes et mouvements
        let descriptor = FetchDescriptor<Asset>(
            sortBy: [SortDescriptor(\.name)]
        )
        let allAssets = try modelContext.fetch(descriptor)
        
        // TODO: Implémenter la logique de filtrage par événement
        // en croisant avec les tables Movement et Order
        return allAssets
    }
    
    func saveAsset(_ asset: Asset) async throws {
        asset.updatedAt = Date()
        modelContext.insert(asset)
        try modelContext.save()
    }
    
    func deleteAsset(_ asset: Asset) async throws {
        modelContext.delete(asset)
        try modelContext.save()
    }
    
    func updateAssetLocation(_ assetId: String, locationId: String?) async throws {
        guard let asset = try await getAssetById(assetId) else {
            throw RepositoryError.assetNotFound
        }
        
        asset.currentLocationId = locationId
        asset.updatedAt = Date()
        try modelContext.save()
    }
    
    func updateAssetStatus(_ assetId: String, status: AssetStatus) async throws {
        guard let asset = try await getAssetById(assetId) else {
            throw RepositoryError.assetNotFound
        }
        
        asset.status = status
        asset.updatedAt = Date()
        try modelContext.save()
    }
    
    func searchAssets(_ query: String) async throws -> [Asset] {
        let descriptor = FetchDescriptor<Asset>(
            sortBy: [SortDescriptor(\.name)]
        )
        let allAssets = try modelContext.fetch(descriptor)
        return allAssets.filteredBySearch(query)
    }
}

enum RepositoryError: Error, LocalizedError {
    case assetNotFound
    case invalidData
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            return "Asset non trouvé"
        case .invalidData:
            return "Données invalides"
        case .syncFailed:
            return "Échec de la synchronisation"
        }
    }
}

//
//  PreviewHelpers.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import Foundation

// MARK: - Preview Repository Implementations

class PreviewAssetRepository: AssetRepositoryProtocol {
    func getAllAssets() async throws -> [Asset] { [] }
    func getAssetById(_ id: String) async throws -> Asset? { nil }
    func getAssetsByLocation(_ locationId: String) async throws -> [Asset] { [] }
    func getAssetsByEvent(_ eventId: String) async throws -> [Asset] { [] }
    func saveAsset(_ asset: Asset) async throws { }
    func deleteAsset(_ asset: Asset) async throws { }
    func updateAssetLocation(_ assetId: String, locationId: String?) async throws { }
    func updateAssetStatus(_ assetId: String, status: AssetStatus) async throws { }
    func searchAssets(_ query: String) async throws -> [Asset] { [] }
}

class PreviewMovementRepository: MovementRepositoryProtocol {
    func createMovement(_ movement: Movement) async throws { }
    func getMovementsByAsset(_ assetId: String) async throws -> [Movement] { [] }
    func getMovementsByEvent(_ eventId: String) async throws -> [Movement] { [] }
    func getUnsyncedMovements() async throws -> [Movement] { [] }
    func markMovementAsSynced(_ movementId: String) async throws { }
    func getRecentMovements(limit: Int) async throws -> [Movement] { [] }
}

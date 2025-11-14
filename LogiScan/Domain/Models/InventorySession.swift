//
//  InventorySession.swift
//  LogiScan
//
//  Created by Assistant on 13/11/2025.
//

import Foundation
import SwiftData

/// Session d'inventaire avec tous les articles scannés
@Model
final class InventorySession {
    @Attribute(.unique) var sessionId: String
    var createdAt: Date
    var completedAt: Date?
    var createdBy: String  // userId
    var notes: String?
    
    // Items scannés (stocké comme JSON ou relation)
    var scannedAssetIds: [String]
    var totalCount: Int
    
    // Statut
    var isCompleted: Bool
    
    init(
        sessionId: String = UUID().uuidString,
        createdBy: String,
        notes: String? = nil
    ) {
        self.sessionId = sessionId
        self.createdAt = Date()
        self.createdBy = createdBy
        self.notes = notes
        self.scannedAssetIds = []
        self.totalCount = 0
        self.isCompleted = false
    }
    
    /// Ajoute un asset à la session
    func addAsset(_ assetId: String) {
        if !scannedAssetIds.contains(assetId) {
            scannedAssetIds.append(assetId)
            totalCount = scannedAssetIds.count
        }
    }
    
    /// Complète la session
    func complete() {
        isCompleted = true
        completedAt = Date()
    }
}

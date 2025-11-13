//
//  ScannerViewModel+ScanList.swift
//  LogiScan
//
//  Created by Assistant on 12/11/2025.
//

import Foundation
import SwiftData

/// Extension du ScannerViewModel pour gérer les listes de scan événementielles
extension ScannerViewModel {
    
    /// Active le mode événementiel avec une liste de scan spécifique
    /// - Parameters:
    ///   - scanList: La liste de scan à utiliser
    ///   - event: L'événement associé
    ///   - modelContext: Le contexte SwiftData
    func activateEventMode(
        with scanList: ScanList,
        event: Event,
        modelContext: ModelContext
    ) {
        print("📋 [Scanner] Activation mode événementiel")
        print("   Événement: \(event.name)")
        print("   Liste: \(scanList.displayName)")
        print("   Items: \(scanList.totalItems)")
        
        selectedEvent = event
        currentActiveScanList = scanList
        
        // Déterminer le mode de scan selon la direction
        let scanMode = getScanModeForDirection(scanList.scanDirection)
        
        // Créer une session de scan
        let userId = "CURRENT_USER_ID" // TODO: Récupérer du AuthService
        currentSession = ScanSession(
            mode: scanMode,
            expectedAssets: nil,  // Sera géré par la scanList
            truckId: event.assignedTruckId,
            eventId: event.eventId,
            userId: userId
        )
        
        currentMode = scanMode
        
        // Marquer la liste comme "en cours" si elle est en attente
        if scanList.status == .pending {
            scanList.status = .inProgress
            scanList.updatedAt = Date()
            try? modelContext.save()
        }
        
        startScanning()
    }
    
    /// Traite un scan dans le contexte d'une liste de scan événementielle
    /// - Parameters:
    ///   - asset: L'asset scanné
    ///   - scanList: La liste de scan active
    ///   - modelContext: Le contexte SwiftData
    func processScanForList(
        asset: Asset,
        scanList: ScanList,
        modelContext: ModelContext
    ) async throws {
        
        print("📦 [Scanner] Traitement scan pour liste '\(scanList.displayName)'")
        
        // 1. Vérifier que l'asset est attendu dans cette liste
        let prepItemDescriptor = FetchDescriptor<PreparationListItem>(
            predicate: #Predicate { item in
                item.scanList?.scanListId == scanList.scanListId &&
                item.sku == asset.sku &&
                !item.scanned
            }
        )
        
        let prepItems = try modelContext.fetch(prepItemDescriptor)
        
        guard let prepItem = prepItems.first else {
            // Asset non attendu ou déjà scanné
            if prepItems.isEmpty {
                throw ScanListError.assetNotExpected(assetName: asset.name)
            } else {
                throw ScanListError.assetAlreadyScanned(assetName: asset.name)
            }
        }
        
        // 2. Marquer l'item comme scanné
        prepItem.scanned = true
        prepItem.scannedAt = Date()
        prepItem.scannedAssetId = asset.assetId
        
        // 3. Mettre à jour le compteur de la liste
        scanList.scannedItems += 1
        scanList.updatedAt = Date()
        
        print("   ✅ Item scanné: \(asset.name)")
        print("   Progression: \(scanList.scannedItems)/\(scanList.totalItems)")
        
        // 4. Mettre à jour le statut de l'asset selon la direction
        let scanListService = ScanListGenerationService()
        try scanListService.updateAssetStatusAfterScan(
            asset: asset,
            scanList: scanList,
            modelContext: modelContext
        )
        
        // 5. Créer un mouvement de traçabilité
        let movementType = getMovementTypeForDirection(scanList.scanDirection)
        let locations = getLocationsForDirection(scanList.scanDirection, event: selectedEvent)
        
        await createMovement(
            type: movementType,
            assetId: asset.assetId,
            fromLocation: locations.from,
            toLocation: locations.to
        )
        
        // 6. Vérifier si la liste est complète
        if scanList.isComplete {
            print("🎉 [Scanner] Liste complète!")
            try await completeScanList(scanList: scanList, modelContext: modelContext)
        }
        
        try modelContext.save()
    }
    
    /// Complète une liste de scan et déclenche les actions associées
    private func completeScanList(
        scanList: ScanList,
        modelContext: ModelContext
    ) async throws {
        
        print("✅ [Scanner] Complétion de la liste '\(scanList.displayName)'")
        
        let scanListService = ScanListGenerationService()
        try scanListService.completeScanList(scanList: scanList, modelContext: modelContext)
        
        // Si c'est la liste "Stock → Camion", geler définitivement les assets
        if scanList.scanDirection == .stockToTruck, let event = selectedEvent {
            let quoteValidationService = QuoteValidationService()
            try await quoteValidationService.freezeAssetsAfterLoading(
                event: event,
                scanList: scanList,
                modelContext: modelContext
            )
        }
        
        // Si c'est la liste "Camion → Stock", libérer les assets
        if scanList.scanDirection == .truckToStock, let event = selectedEvent {
            let quoteValidationService = QuoteValidationService()
            try await quoteValidationService.releaseAssetsAfterReturn(
                event: event,
                scanList: scanList,
                modelContext: modelContext
            )
        }
        
        print("✅ [Scanner] Liste et actions associées complétées")
    }
    
    /// Obtient le prochain item à scanner dans la liste
    func getNextItemToScan(
        from scanList: ScanList,
        modelContext: ModelContext
    ) -> PreparationListItem? {
        
        let descriptor = FetchDescriptor<PreparationListItem>(
            predicate: #Predicate { item in
                item.scanList?.scanListId == scanList.scanListId &&
                !item.scanned
            },
            sortBy: [SortDescriptor(\.category), SortDescriptor(\.name)]
        )
        
        guard let items = try? modelContext.fetch(descriptor),
              let nextItem = items.first else {
            return nil
        }
        
        return nextItem
    }
    
    // MARK: - Helper Methods
    
    private func getScanModeForDirection(_ direction: ScanDirection) -> ScanMode {
        switch direction {
        case .stockToTruck:
            return .stockToTruck
        case .truckToEvent:
            return .truckToEvent
        case .eventToTruck:
            return .eventToTruck
        case .truckToStock:
            return .truckToStock
        }
    }
    
    private func getMovementTypeForDirection(_ direction: ScanDirection) -> MovementType {
        switch direction {
        case .stockToTruck:
            return .load
        case .truckToEvent:
            return .unload
        case .eventToTruck:
            return .reload
        case .truckToStock:
            return .return
        }
    }
    
    private func getLocationsForDirection(
        _ direction: ScanDirection,
        event: Event?
    ) -> (from: String?, to: String?) {
        
        switch direction {
        case .stockToTruck:
            return ("STOCK", event?.assignedTruckId)
        case .truckToEvent:
            return (event?.assignedTruckId, "EVENT_\(event?.eventId ?? "")")
        case .eventToTruck:
            return ("EVENT_\(event?.eventId ?? "")", event?.assignedTruckId)
        case .truckToStock:
            return (event?.assignedTruckId, "STOCK")
        }
    }
}

// MARK: - Published Properties Extension

extension ScannerViewModel {
    /// Liste de scan active en mode événementiel
    private static var _currentActiveScanList: ScanList?
    
    var currentActiveScanList: ScanList? {
        get { Self._currentActiveScanList }
        set { Self._currentActiveScanList = newValue }
    }
}

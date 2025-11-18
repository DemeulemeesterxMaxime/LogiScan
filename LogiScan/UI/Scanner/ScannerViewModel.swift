//
//  ScannerViewModel.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//  Refactored on 13/10/2025 - Multi-mode scanner
//

import Foundation
import SwiftUI
import SwiftData
import AVFoundation

@MainActor
class ScannerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var scannedCode: String?
    @Published var isScanning = false
    @Published var scanResult: ScanResult?
    @Published var showResult = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Scan Mode
    @Published var currentMode: ScanMode = .free
    @Published var showModeSelector = false
    
    // MARK: - Scan Session
    @Published var currentSession: ScanSession?
    @Published var scanList: [ScanListItem] = []
    @Published var showScanList = false
    
    // MARK: - Inventory Session
    @Published var currentInventorySession: InventorySession?
    @Published var showInventoryList = false
    
    // MARK: - Context
    @Published var selectedTruck: Truck?
    @Published var selectedEvent: Event?
    
    // MARK: - Statistics
    @Published var sessionStats: SessionStats = SessionStats()
    
    // MARK: - Services
    private let inventoryService = InventorySessionService()
    
    // MARK: - Animation & Feedback
    @Published var showSuccessAnimation = false
    @Published var showDuplicateWarning = false
    @Published var lastScanTimestamp: Date?
    
    // Throttling pour éviter les scans trop rapides
    private var lastScanTime: Date?
    private let minimumScanInterval: TimeInterval = 1.0 // 1 seconde entre chaque scan
    
    private let assetRepository: AssetRepositoryProtocol
    private let movementRepository: MovementRepositoryProtocol
    private var modelContext: ModelContext?  // Context pour les opérations SwiftData
    
    init(
        assetRepository: AssetRepositoryProtocol,
        movementRepository: MovementRepositoryProtocol,
        modelContext: ModelContext? = nil
    ) {
        self.assetRepository = assetRepository
        self.movementRepository = movementRepository
        self.modelContext = modelContext
    }
    
    /// Définit le ModelContext pour les opérations SwiftData
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Scan Control
    
    func startScanning() {
        isScanning = true
        scannedCode = nil
        scanResult = nil
        errorMessage = nil
    }
    
    func stopScanning() {
        isScanning = false
    }
    
    func handleScannedCode(_ code: String) {
        // Vérifier le throttling (1 scan par seconde max)
        let now = Date()
        if let lastTime = lastScanTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed < minimumScanInterval {
                print("⏱️ Scan ignoré : trop rapide (\(String(format: "%.2f", elapsed))s)")
                return
            }
        }
        
        // Mettre à jour le timestamp
        lastScanTime = now
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        scannedCode = code
        lastScanTimestamp = Date()
        
        Task {
            await processScannedCode(code)
        }
    }
    
    // MARK: - Mode Selection
    
    func selectMode(_ mode: ScanMode, truck: Truck? = nil, event: Event? = nil, expectedAssets: [Asset]? = nil) {
        currentMode = mode
        selectedTruck = truck
        selectedEvent = event
        
        // ✅ Mode inventaire : créer ou récupérer session
        if mode == .inventory, let context = modelContext {
            do {
                // Essayer de récupérer une session active
                if let activeSession = try inventoryService.fetchActiveSession(modelContext: context) {
                    currentInventorySession = activeSession
                    print("✅ [Scanner] Session inventaire récupérée: \(activeSession.totalCount) items")
                } else {
                    // Créer nouvelle session
                    let userId = "CURRENT_USER_ID" // TODO: Récupérer du AuthService
                    currentInventorySession = inventoryService.createSession(
                        createdBy: userId,
                        notes: "Session du \(Date().formatted())",
                        modelContext: context
                    )
                    print("✅ [Scanner] Nouvelle session inventaire créée")
                }
            } catch {
                print("❌ [Scanner] Erreur session inventaire: \(error)")
            }
        }
        
        // Créer une session classique si mode avec workflow (non-inventory)
        if mode != .free && mode != .inventory {
            let userId = "CURRENT_USER_ID" // TODO: Récupérer du AuthService
            currentSession = ScanSession(
                mode: mode,
                expectedAssets: expectedAssets?.map { $0.assetId },
                truckId: truck?.truckId,
                eventId: event?.eventId,
                userId: userId
            )
            
            // Créer la liste de scan si on a des assets attendus
            if let expected = expectedAssets {
                scanList = expected.map { ScanListItem(asset: $0) }
            }
        }
    }
    
    func resetMode() {
        currentMode = .free
        selectedTruck = nil
        selectedEvent = nil
        currentSession = nil
        scanList = []
        sessionStats = SessionStats()
        stopScanning()
    }
    
    // MARK: - Session Management
    
    func startNewSession(mode: ScanMode, expectedAssets: [Asset]? = nil) {
        let userId = "CURRENT_USER_ID" // TODO: Récupérer du AuthService
        
        currentSession = ScanSession(
            mode: mode,
            expectedAssets: expectedAssets?.map { $0.assetId },
            truckId: selectedTruck?.truckId,
            eventId: selectedEvent?.eventId,
            userId: userId
        )
        
        if let expected = expectedAssets {
            scanList = expected.map { ScanListItem(asset: $0) }
        }
        
        sessionStats = SessionStats()
        startScanning()
    }
    
    func endCurrentSession() {
        guard var session = currentSession else { return }
        session.endedAt = Date()
        currentSession = session
        
        // TODO: Sauvegarder la session en base
        
        stopScanning()
    }
    
    // MARK: - QR Code Processing
    
    private func processScannedCode(_ code: String) async {
        do {
            // D'abord, vérifier si c'est un SKU simple (code-barres)
            // Format SKU simple: pas de ':' ou de '{'
            if !code.contains(":") && !code.contains("{") {
                await handleDirectSKUScan(code)
                return
            }
            
            // Analyser le payload QR pour déterminer le type
            let payload = try parseQRPayload(code)
            
            switch payload.type {
            case "asset":
                await handleAssetScan(payload)
            case "location", "loc":
                await handleLocationScan(payload)
            case "batch", "box":
                await handleBatchScan(payload)
            default:
                await showErrorMessage("Type de QR code non reconnu: \(payload.type)")
            }
            
        } catch {
            await showErrorMessage(error.localizedDescription)
        }
    }
    
    // MARK: - Direct SKU Scan
    
    private func handleDirectSKUScan(_ sku: String) async {
        do {
            print("🔍 [Scanner] Scan direct SKU: '\(sku)'")
            print("   - Longueur: \(sku.count) caractères")
            print("   - Mode actuel: \(currentMode)")
            
            // Rechercher tous les assets avec ce SKU
            let assets = try await assetRepository.searchAssets(sku)
            
            print("📦 [Scanner] Trouvé \(assets.count) asset(s) avec SKU '\(sku)'")
            
            guard !assets.isEmpty else {
                print("❌ [Scanner] Aucun asset trouvé pour SKU: '\(sku)'")
                print("   💡 Vérifiez que:")
                print("      1. Le SKU existe dans la base de données (Catalogue → Assets)")
                print("      2. La casse est correcte (ex: 'SPK-12' != 'spk-12')")
                print("      3. Il n'y a pas d'espaces avant/après le SKU")
                await showErrorMessage("❌ Aucun asset trouvé pour le SKU: '\(sku)'\n\n💡 Vérifiez que le SKU existe dans votre catalogue")
                playErrorSound()
                return
            }
            
            print("📦 [Scanner] Trouvé \(assets.count) asset(s) avec SKU '\(sku)'")
            
            // Si un seul asset, le traiter directement
            if assets.count == 1 {
                let asset = assets[0]
                await handleSingleAssetScan(asset, fromSKU: sku)
                return
            }
            
            // Si plusieurs assets, selon le mode:
            switch currentMode {
            case .free:
                // Mode libre: afficher la liste pour choisir
                await showAssetSelectionSheet(assets: assets, sku: sku)
                
            case .inventory:
                // Mode inventaire: scanner tous les assets de ce SKU
                await handleMultipleAssetsScan(assets, fromSKU: sku)
                
            default:
                // Modes workflow: chercher le premier disponible dans la liste attendue
                if let expectedAssets = currentSession?.expectedAssets {
                    let availableAsset = assets.first { expectedAssets.contains($0.assetId) }
                    if let asset = availableAsset {
                        await handleSingleAssetScan(asset, fromSKU: sku)
                    } else {
                        await showErrorMessage("Asset \(sku) non attendu dans cette liste")
                        playErrorSound()
                    }
                } else {
                    // Pas de liste: prendre le premier disponible
                    let availableAsset = assets.first { $0.status == .available }
                    if let asset = availableAsset {
                        await handleSingleAssetScan(asset, fromSKU: sku)
                    } else {
                        await showErrorMessage("Aucun asset \(sku) disponible")
                        playErrorSound()
                    }
                }
            }
        } catch {
            await showErrorMessage("Erreur lors de la recherche SKU: \(error.localizedDescription)")
            playErrorSound()
        }
    }
    
    private func handleSingleAssetScan(_ asset: Asset, fromSKU sku: String) async {
        do {
            // Créer un payload virtuel pour réutiliser la logique existante
            let payload = QRPayload(
                v: 1,
                type: "asset",
                id: asset.assetId,
                sku: sku,
                sn: asset.serialNumber,
                skus: nil
            )
            
            await handleAssetScan(payload)
        }
    }
    
    private func handleMultipleAssetsScan(_ assets: [Asset], fromSKU sku: String) async {
        // Mode inventaire: scanner tous les assets
        for asset in assets {
            await handleSingleAssetScan(asset, fromSKU: sku)
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s entre chaque
        }
    }
    
    @Published var showAssetSelection = false
    @Published var assetsForSelection: [Asset] = []
    @Published var skuForSelection: String = ""
    
    private func showAssetSelectionSheet(assets: [Asset], sku: String) async {
        assetsForSelection = assets
        skuForSelection = sku
        showAssetSelection = true
        stopScanning()
    }
    
    func selectAssetFromSheet(_ asset: Asset) {
        showAssetSelection = false
        Task {
            await handleSingleAssetScan(asset, fromSKU: skuForSelection)
        }
    }
    
    private func parseQRPayload(_ code: String) throws -> QRPayload {
        // Essayer d'abord le format JSON moderne
        if let data = code.data(using: .utf8),
           let jsonPayload = try? JSONDecoder().decode(QRPayload.self, from: data) {
            return jsonPayload
        }
        
        // Fallback vers le format simple: TYPE:ID:ADDITIONAL_INFO
        let components = code.components(separatedBy: ":")
        guard components.count >= 2 else {
            throw ScannerError.invalidQRFormat
        }
        
        let typeString = components[0]
        let id = components[1]
        
        return QRPayload(
            v: 1,
            type: typeString.lowercased(),
            id: id,
            sku: nil,
            sn: nil,
            skus: nil
        )
    }
    
    private func handleAssetScan(_ payload: QRPayload) async {
        do {
            // Chercher l'asset par ID ou SKU
            var asset: Asset?
            
            if let foundById = try await assetRepository.getAssetById(payload.id) {
                asset = foundById
            } else if let sku = payload.sku {
                // Chercher par SKU
                let results = try await assetRepository.searchAssets(sku)
                asset = results.first
            }
            
            guard let foundAsset = asset else {
                await showErrorMessage("Asset non trouvé (ID: \(payload.id))")
                playErrorSound()
                return
            }
            
            // 🆕 MODE ÉVÉNEMENTIEL : Utiliser la logique de liste de scan
            if let scanList = currentActiveScanList, let context = modelContext {
                do {
                    try await processScanForList(
                        asset: foundAsset,
                        scanList: scanList,
                        modelContext: context
                    )
                    
                    // Animation de succès
                    showSuccessAnimation = true
                    playSuccessSound()
                    
                    // Attendre puis arrêter l'animation
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    showSuccessAnimation = false
                    
                    // Vérifier si la liste est complète
                    if scanList.isComplete {
                        endCurrentSession()
                        showSessionComplete()
                    }
                    
                    // ✅ Ne pas redémarrer automatiquement - attendre le prochain hold
                    return
                    
                } catch let scanListError as ScanListError {
                    await showErrorMessage(scanListError.localizedDescription)
                    playErrorSound()
                    
                    // Attendre puis réinitialiser
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    // ✅ Ne pas redémarrer automatiquement - attendre le prochain hold
                    return
                    
                } catch {
                    await showErrorMessage("Erreur scan liste: \(error.localizedDescription)")
                    playErrorSound()
                    
                    // Attendre puis réinitialiser
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    // ✅ Ne pas redémarrer automatiquement - attendre le prochain hold
                    return
                }
            }
            
            // MODE CLASSIQUE : Logique existante
            
            // ✅ En mode LIBRE, toujours afficher les infos de l'asset (pas de gestion de duplicata)
            if currentMode == .free {
                // Créer le résultat de scan avec toutes les infos
                scanResult = ScanResult(
                    type: .asset,
                    asset: foundAsset,
                    title: foundAsset.name,
                    subtitle: "SKU: \(foundAsset.sku)",
                    status: foundAsset.status.displayName,
                    statusColor: foundAsset.status.color,
                    rawPayload: scannedCode ?? ""
                )
                
                // ✅ PAS d'animation de succès en mode libre - uniquement les infos
                playSuccessSound()
                
                // Afficher le résultat
                showResult = true
                stopScanning()
                return
            }
            
            // ✅ MODE INVENTAIRE : sauvegarder dans la session et Firebase
            if currentMode == .inventory {
                if let invSession = currentInventorySession, let context = modelContext {
                    // Vérifier si déjà scanné
                    if invSession.scannedAssetIds.contains(foundAsset.assetId) {
                        showDuplicateWarning = true
                        playWarningSound()
                        
                        // Attendre puis réinitialiser
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        showDuplicateWarning = false
                        return
                    }
                    
                    // Ajouter à la session et sauvegarder
                    try await inventoryService.addAssetToSession(
                        session: invSession,
                        assetId: foundAsset.assetId,
                        modelContext: context
                    )
                    
                    sessionStats.totalScanned = invSession.totalCount
                    
                    // Animation de succès
                    showSuccessAnimation = true
                    playSuccessSound()
                    
                    // Attendre puis arrêter l'animation
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    showSuccessAnimation = false
                    
                    return
                } else {
                    await showErrorMessage("Session inventaire non initialisée")
                    playErrorSound()
                    return
                }
            }
            
            // Pour autres modes workflow : vérifier duplicata
            // Vérifier si déjà scanné dans cette session
            if let session = currentSession, session.scannedAssets.contains(foundAsset.assetId) {
                showDuplicateWarning = true
                playWarningSound()
                
                // Attendre 1 seconde puis reprendre le scan
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                showDuplicateWarning = false
                return  // ✅ Ne pas restart automatiquement, attendre le hold
            }
            
            // Ajouter à la session
            if var session = currentSession {
                session.scannedAssets.append(foundAsset.assetId)
                currentSession = session
                
                // Mettre à jour la liste de scan
                if let index = scanList.firstIndex(where: { $0.id == foundAsset.assetId }) {
                    scanList[index].isScanned = true
                    scanList[index].scannedAt = Date()
                }
                
                sessionStats.totalScanned += 1
            }
            
            // Créer le mouvement automatique selon le mode
            if let movementType = currentMode.autoMovementType {
                let locations = currentMode.getAutoLocations(
                    truckId: selectedTruck?.truckId,
                    eventId: selectedEvent?.eventId
                )
                
                await createMovement(
                    type: movementType,
                    assetId: foundAsset.assetId,
                    fromLocation: locations.from,
                    toLocation: locations.to
                )
                
                // Mettre à jour la localisation de l'asset
                if let toLocation = locations.to {
                    try await assetRepository.updateAssetLocation(foundAsset.assetId, locationId: toLocation)
                }
                
                // Mettre à jour le statut selon le mode
                let newStatus = getAssetStatusForMode(currentMode)
                if let status = newStatus {
                    try await assetRepository.updateAssetStatus(foundAsset.assetId, status: status)
                }
            }
            
            // Créer le résultat de scan
            scanResult = ScanResult(
                type: .asset,
                asset: foundAsset,
                title: foundAsset.name,
                subtitle: "SKU: \(foundAsset.sku)",
                status: foundAsset.status.displayName,
                statusColor: foundAsset.status.color,
                rawPayload: scannedCode ?? ""
            )
            
            // Animation de succès
            showSuccessAnimation = true
            playSuccessSound()
            
            // Mode inventaire et workflow: feedback visuel puis attendre le prochain hold
            try? await Task.sleep(nanoseconds: 800_000_000)
            showSuccessAnimation = false
            
            // ✅ Ne pas redémarrer automatiquement - attendre le prochain hold
            
        } catch {
            await showErrorMessage("Erreur lors de la recherche de l'asset: \(error.localizedDescription)")
            playErrorSound()
        }
    }
    
    private func handleLocationScan(_ payload: QRPayload) async {
        // TODO: Implémenter la logique de scan de location
        scanResult = ScanResult(
            type: .location,
            title: "Location: \(payload.id)",
            subtitle: "Scan de location détecté",
            status: "Active",
            statusColor: "green",
            rawPayload: scannedCode ?? ""
        )
        
        if currentMode == .free {
            showResult = true
            stopScanning()
        } else {
            playSuccessSound()
            try? await Task.sleep(nanoseconds: 500_000_000)
            startScanning()
        }
    }
    
    private func handleBatchScan(_ payload: QRPayload) async {
        // TODO: Implémenter la logique de scan de lot
        scanResult = ScanResult(
            type: .batch,
            title: "Lot: \(payload.id)",
            subtitle: "Scan de lot détecté",
            status: "Disponible",
            statusColor: "blue",
            rawPayload: scannedCode ?? ""
        )
        
        if currentMode == .free {
            showResult = true
            stopScanning()
        } else {
            playSuccessSound()
            try? await Task.sleep(nanoseconds: 500_000_000)
            startScanning()
        }
    }
    
    // MARK: - Movement Creation
    
    func createMovement(type: MovementType, assetId: String, fromLocation: String?, toLocation: String?) async {
        do {
            let movement = Movement(
                type: type,
                assetId: assetId,
                fromLocationId: fromLocation,
                toLocationId: toLocation,
                timestamp: Date(),
                scanPayload: scannedCode
            )
            
            try await movementRepository.createMovement(movement)
            sessionStats.movementsCreated += 1
            
        } catch {
            await showErrorMessage("Erreur lors de la création du mouvement: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAssetStatusForMode(_ mode: ScanMode) -> AssetStatus? {
        switch mode {
        case .stockToTruck:
            return .inUse // En cours de transport
        case .truckToEvent:
            return .inUse // En utilisation sur site
        case .eventToTruck:
            return .inUse // En retour
        case .truckToStock:
            return .available // De retour au dépôt
        case .free, .inventory:
            return nil // Pas de changement de statut
        }
    }
    
    private func showSessionComplete() {
        // TODO: Afficher une alerte/sheet de fin de session
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func showErrorMessage(_ message: String) async {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Sound & Haptics
    
    private func playSuccessSound() {
        AudioServicesPlaySystemSound(1057) // Success sound
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func playErrorSound() {
        AudioServicesPlaySystemSound(1053) // Error sound
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    private func playWarningSound() {
        AudioServicesPlaySystemSound(1104) // Warning sound
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Supporting Types

enum ScannerError: Error, LocalizedError {
    case invalidQRFormat
    case unknownQRType
    case assetNotFound
    case duplicateScan
    
    var errorDescription: String? {
        switch self {
        case .invalidQRFormat:
            return "Format de QR code invalide"
        case .unknownQRType:
            return "Type de QR code non reconnu"
        case .assetNotFound:
            return "Asset non trouvé"
        case .duplicateScan:
            return "Cet asset a déjà été scanné"
        }
    }
}

struct SessionStats {
    var totalScanned: Int = 0
    var movementsCreated: Int = 0
    var errors: Int = 0
    var duplicates: Int = 0
    
    var scanRate: Double {
        // Scans par minute (à calculer avec le temps réel)
        return 0.0
    }
}

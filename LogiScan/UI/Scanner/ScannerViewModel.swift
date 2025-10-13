//
//  ScannerViewModel.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//  Refactored on 13/10/2025 - Multi-mode scanner
//

import Foundation
import SwiftUI
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
    
    // MARK: - Context
    @Published var selectedTruck: Truck?
    @Published var selectedEvent: Event?
    
    // MARK: - Statistics
    @Published var sessionStats: SessionStats = SessionStats()
    
    // MARK: - Animation & Feedback
    @Published var showSuccessAnimation = false
    @Published var showDuplicateWarning = false
    @Published var lastScanTimestamp: Date?
    
    private let assetRepository: AssetRepositoryProtocol
    private let movementRepository: MovementRepositoryProtocol
    
    init(
        assetRepository: AssetRepositoryProtocol,
        movementRepository: MovementRepositoryProtocol
    ) {
        self.assetRepository = assetRepository
        self.movementRepository = movementRepository
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
        
        // Créer une nouvelle session si mode avec workflow
        if mode != .free {
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
        
        // Démarrer le scan automatiquement
        startScanning()
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
            
            // Vérifier si déjà scanné dans cette session
            if let session = currentSession, session.scannedAssets.contains(foundAsset.assetId) {
                showDuplicateWarning = true
                playWarningSound()
                
                // Attendre 1 seconde puis reprendre le scan
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                showDuplicateWarning = false
                startScanning()
                return
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
            
            // Selon le mode, afficher le résultat ou reprendre le scan
            if currentMode == .free {
                // Mode libre: afficher le résultat
                showResult = true
                stopScanning()
            } else {
                // Modes workflow: reprendre le scan après 0.5s
                try? await Task.sleep(nanoseconds: 500_000_000)
                showSuccessAnimation = false
                
                // Vérifier si la session est complète
                if let session = currentSession, session.isComplete {
                    endCurrentSession()
                    showSessionComplete()
                } else {
                    startScanning()
                }
            }
            
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

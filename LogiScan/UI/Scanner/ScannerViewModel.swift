//
//  ScannerViewModel.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftUI

@MainActor
class ScannerViewModel: ObservableObject {
    @Published var scannedCode: String?
    @Published var isScanning = false
    @Published var scanResult: ScanResult?
    @Published var showResult = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let assetRepository: AssetRepositoryProtocol
    private let movementRepository: MovementRepositoryProtocol
    
    init(
        assetRepository: AssetRepositoryProtocol,
        movementRepository: MovementRepositoryProtocol
    ) {
        self.assetRepository = assetRepository
        self.movementRepository = movementRepository
    }
    
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
        scannedCode = code
        stopScanning()
        
        Task {
            await processScannedCode(code)
        }
    }
    
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
            guard let asset = try await assetRepository.getAssetById(payload.id) else {
                await showErrorMessage("Asset \(payload.id) non trouvé")
                return
            }
            
            scanResult = ScanResult(
                type: .asset,
                asset: asset,
                title: asset.name,
                subtitle: "SKU: \(asset.sku)",
                status: asset.status.displayName,
                statusColor: asset.status.color,
                rawPayload: scannedCode ?? ""
            )
            showResult = true
            
        } catch {
            await showErrorMessage("Erreur lors de la recherche de l'asset: \(error.localizedDescription)")
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
        showResult = true
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
        showResult = true
    }
    
    private func showErrorMessage(_ message: String) async {
        errorMessage = message
        showError = true
    }
    
    func createMovement(type: MovementType, fromLocation: String?, toLocation: String?) async {
        guard let result = scanResult else { return }
        
        do {
            let movement = Movement(
                type: type,
                assetId: result.asset?.assetId,
                fromLocationId: fromLocation,
                toLocationId: toLocation,
                timestamp: Date(),
                scanPayload: scannedCode
            )
            
            try await movementRepository.createMovement(movement)
            
            // Mettre à jour la location de l'asset si nécessaire
            if let assetId = result.asset?.assetId {
                try await assetRepository.updateAssetLocation(assetId, locationId: toLocation)
            }
            
        } catch {
            await showErrorMessage("Erreur lors de la création du mouvement: \(error.localizedDescription)")
        }
    }
}

enum ScannerError: Error, LocalizedError {
    case invalidQRFormat
    case unknownQRType
    case assetNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidQRFormat:
            return "Format de QR code invalide"
        case .unknownQRType:
            return "Type de QR code non reconnu"
        case .assetNotFound:
            return "Asset non trouvé"
        }
    }
}

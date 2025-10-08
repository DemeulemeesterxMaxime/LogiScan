//
//  DistributionConfig.swift
//  LogiScan
//
//  Created by Demeulemeester on 01/10/2025.
//

import Foundation
import CoreGraphics

/// Configuration globale pour l'application de distribution LogiScan
struct DistributionConfig {
    
    // MARK: - Informations Entreprise
    static let companyName = "LogiScan Distribution"
    static let companyAddress = "Zone Industrielle, 83000 Toulon"
    static let companyPhone = "+33 4 94 XX XX XX"
    static let companyEmail = "contact@logiscan-distribution.fr"
    
    // MARK: - Délais et Buffers (en heures)
    static let defaultPrepLeadHours = 24        // Délai de préparation standard
    static let defaultReturnBufferHours = 12    // Marge de retour standard
    static let urgentPrepLeadHours = 4          // Délai de préparation urgent
    static let weekendBufferHours = 48          // Marge supplémentaire week-end
    
    // MARK: - Limites Opérationnelles
    static let maxItemsPerScan = 50             // Limite de scan par batch
    static let maxDailyOrders = 20              // Commandes max par jour
    static let maxAssetValue = 10000.0          // Valeur max d'un asset (€)
    static let minNotificationDelay = 2         // Heures avant alerte
    
    // MARK: - Configuration QR Codes
    static let qrCodeVersion = 1
    static let qrCodePrefix = "sb://"           // ScanBart prefix
    static let qrCodeSize: CGFloat = 512        // Taille image QR
    
    // MARK: - Catégories Matériel Distribution
    static let materialCategories = [
        "Audio": ["Enceintes", "Micros", "Consoles", "Processeurs"],
        "Éclairage": ["PAR", "Laser", "Stroboscope", "Poursuite", "DMX"],
        "Support": ["Pieds", "Structures", "Charpente", "Treuils"],
        "Câblage": ["Audio", "Éclairage", "Alimentation", "Réseau"],
        "Transport": ["Flight Cases", "Housses", "Sangles", "Roulettes"],
        "Vidéo": ["Écrans", "Projecteurs", "Caméras", "Mélangeurs"]
    ]
    
    // MARK: - Tags Prédéfinis par Catégorie
    static let predefinedTags: [String: [String]] = [
        "Audio": ["Active", "Passive", "Sub", "Monitor", "Line Array", "HF", "Filaire"],
        "Éclairage": ["LED", "Halogène", "RGB", "RGBW", "DMX", "Standalone", "Master/Slave"],
        "Support": ["Léger", "Renforcé", "Telescopique", "Fixe", "Mobile", "Antivol"],
        "Transport": ["Roulettes", "Étanche", "Antichoc", "Empilable", "Sur mesure"],
        "Câblage": ["XLR", "Jack", "RCA", "Speakon", "PowerCon", "5m", "10m", "20m"],
        "Vidéo": ["HD", "4K", "HDMI", "SDI", "VGA", "Sans fil", "Enregistreur"]
    ]
    
    // MARK: - Statuts et Couleurs
    static let statusColors: [String: String] = [
        "Disponible": "green",
        "Réservé": "blue", 
        "En préparation": "orange",
        "Chargé": "purple",
        "En transit": "yellow",
        "Sur site": "indigo",
        "En retour": "brown",
        "Maintenance": "red",
        "Perdu": "gray"
    ]
    
    // MARK: - Configuration Notifications
    static let notificationSettings = [
        "conflictReservation": true,        // Conflit de réservation
        "materialReturned": true,           // Matériel de retour
        "maintenanceNeeded": true,          // Maintenance requise
        "orderStatusChanged": false,        // Changement statut commande
        "truckDeparture": true,             // Départ camion
        "lowStock": true                    // Stock faible
    ]
    
    // MARK: - Format d'Export
    static let exportFormats = ["PDF", "Excel", "CSV"]
    static let printFormats = ["A4", "A5", "Étiquettes"]
    
    // MARK: - Paramètres Offline
    static let maxOfflineMovements = 1000    // Mouvements en cache max
    static let syncIntervalSeconds = 30      // Intervalle de sync auto
    static let offlineRetentionDays = 7      // Rétention cache offline
    
    // MARK: - URLs & API (si nécessaire)
    static let apiBaseURL = "https://api.logiscan-distribution.fr/v1"
    static let documentationURL = "https://docs.logiscan-distribution.fr"
    static let supportEmail = "support@logiscan-distribution.fr"
}

// MARK: - Extensions Utilitaires
extension DistributionConfig {
    
    /// Calcule le délai total incluant préparation et buffers
    static func totalLeadTime(prep: Int, buffer: Int, isWeekend: Bool = false) -> Int {
        let weekend = isWeekend ? weekendBufferHours : 0
        return prep + buffer + weekend
    }
    
    /// Vérifie si une valeur d'asset est dans les limites
    static func isAssetValueValid(_ value: Double) -> Bool {
        return value > 0 && value <= maxAssetValue
    }
    
    /// Génère un QR payload standard
    static func generateQRPayload(type: String, id: String, sku: String?, serialNumber: String?) -> String {
        var payload: [String: Any] = [
            "v": qrCodeVersion,
            "type": type,
            "id": id
        ]
        
        if let sku = sku {
            payload["sku"] = sku
        }
        
        if let sn = serialNumber {
            payload["sn"] = sn
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    /// Retourne les tags suggérés pour une catégorie
    static func suggestedTags(for category: String) -> [String] {
        return predefinedTags[category] ?? []
    }
}

//
//  LogisticsStatus.swift
//  LogiScan
//
//  Created by Copilot on 16/10/2025.
//

import Foundation
import SwiftUI

/// Statut logistique suivant le flux physique des équipements
enum LogisticsStatus: String, CaseIterable, Codable {
    case inStock = "EN_STOCK"
    case loadingToTruck = "CHARGEMENT_CAMION"
    case inTransitToEvent = "TRANSIT_EVENT"
    case onSite = "SUR_SITE"
    case loadingFromEvent = "CHARGEMENT_RETOUR"
    case inTransitToStock = "TRANSIT_DEPOT"
    case returned = "RETOUR_COMPLET"
    
    var displayName: String {
        switch self {
        case .inStock:
            return "En stock"
        case .loadingToTruck:
            return "Chargement camion"
        case .inTransitToEvent:
            return "En route vers l'événement"
        case .onSite:
            return "Sur site"
        case .loadingFromEvent:
            return "Chargement retour"
        case .inTransitToStock:
            return "En route vers le dépôt"
        case .returned:
            return "Retour complet"
        }
    }
    
    var icon: String {
        switch self {
        case .inStock:
            return "building.2.fill"
        case .loadingToTruck:
            return "arrow.up.bin.fill"
        case .inTransitToEvent:
            return "truck.box.fill"
        case .onSite:
            return "location.fill"
        case .loadingFromEvent:
            return "arrow.down.bin.fill"
        case .inTransitToStock:
            return "truck.box.badge.clock.fill"
        case .returned:
            return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .inStock:
            return .gray
        case .loadingToTruck:
            return .orange
        case .inTransitToEvent:
            return .blue
        case .onSite:
            return .green
        case .loadingFromEvent:
            return .orange
        case .inTransitToStock:
            return .blue
        case .returned:
            return .green
        }
    }
    
    /// Phase de scan recommandée pour ce statut
    var recommendedScanMode: ScanMode? {
        switch self {
        case .inStock, .loadingToTruck:
            return .stockToTruck
        case .inTransitToEvent:
            return .truckToEvent
        case .onSite:
            return .eventToTruck
        case .loadingFromEvent, .inTransitToStock:
            return .truckToStock
        case .returned:
            return nil // Terminé
        }
    }
    
    /// Description de la phase actuelle
    var phaseDescription: String {
        switch self {
        case .inStock:
            return "Le matériel est au dépôt. Prochaine étape : charger dans le camion."
        case .loadingToTruck:
            return "Chargement en cours. Scannez les articles en les plaçant dans le camion."
        case .inTransitToEvent:
            return "Le camion est en route. Prochaine étape : décharger sur le site."
        case .onSite:
            return "Le matériel est sur le site de l'événement."
        case .loadingFromEvent:
            return "Chargement retour en cours. Scannez les articles en les remettant dans le camion."
        case .inTransitToStock:
            return "Le camion retourne au dépôt. Prochaine étape : ranger le matériel."
        case .returned:
            return "Tout le matériel est rangé au dépôt. Événement terminé."
        }
    }
    
    /// Progression en pourcentage du flux logistique complet
    var progressPercentage: Double {
        switch self {
        case .inStock: return 0.0
        case .loadingToTruck: return 16.6
        case .inTransitToEvent: return 33.3
        case .onSite: return 50.0
        case .loadingFromEvent: return 66.6
        case .inTransitToStock: return 83.3
        case .returned: return 100.0
        }
    }
    
    /// Transition vers le statut suivant basé sur le mode de scan
    func nextStatus(for scanMode: ScanMode, scanCompleted: Bool) -> LogisticsStatus? {
        switch (self, scanMode, scanCompleted) {
        // Stock → Camion
        case (.inStock, .stockToTruck, false):
            return .loadingToTruck
        case (.loadingToTruck, .stockToTruck, true):
            return .inTransitToEvent
            
        // Camion → Event
        case (.inTransitToEvent, .truckToEvent, false):
            return .onSite
        case (.onSite, .truckToEvent, true):
            return .onSite // Reste sur site
            
        // Event → Camion
        case (.onSite, .eventToTruck, false):
            return .loadingFromEvent
        case (.loadingFromEvent, .eventToTruck, true):
            return .inTransitToStock
            
        // Camion → Stock
        case (.inTransitToStock, .truckToStock, false):
            return .inTransitToStock // Reste en transit
        case (.inTransitToStock, .truckToStock, true):
            return .returned
            
        default:
            return nil // Pas de transition
        }
    }
}

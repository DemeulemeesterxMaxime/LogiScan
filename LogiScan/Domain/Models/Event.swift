//
//  Event.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Event {
    var eventId: String  // Retiré @Attribute(.unique) pour éviter les conflits
    var name: String

    // Informations client
    var clientName: String
    var clientPhone: String
    var clientEmail: String
    var clientAddress: String  // Adresse de facturation

    // Informations événement
    var eventAddress: String  // Adresse de l'événement
    var setupStartTime: Date  // Heure de début du montage
    var startDate: Date  // Début de l'événement
    var endDate: Date  // Fin de l'événement
    var status: EventStatus
    var _logisticsStatus: LogisticsStatus?  // Privé, optionnel pour compatibilité
    var notes: String
    var contactInfo: ContactInfo?
    
    // Computed property pour toujours avoir une valeur
    var logisticsStatus: LogisticsStatus {
        get { _logisticsStatus ?? .inStock }
        set { _logisticsStatus = newValue }
    }

    // Devis et facturation
    var assignedTruckId: String?
    var totalAmount: Double  // Calculé depuis les QuoteItems
    var discountPercent: Double  // Remise globale en pourcentage
    var finalAmount: Double  // Montant final après remise
    var quoteStatus: QuoteStatus
    var paymentStatus: PaymentStatus
    
    // Frais supplémentaires du devis
    var deliveryFee: Double  // Frais de déplacement
    var assemblyFee: Double  // Frais de montage
    var disassemblyFee: Double  // Frais de démontage
    var tvaRate: Double  // Taux de TVA (ex: 20.0 pour 20%)

    var createdAt: Date
    var updatedAt: Date

    init(
        eventId: String,
        name: String,
        clientName: String = "",
        clientPhone: String = "",
        clientEmail: String = "",
        clientAddress: String = "",
        eventAddress: String = "",
        setupStartTime: Date = Date(),
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(86400),
        status: EventStatus = .planning,
        logisticsStatus: LogisticsStatus = .inStock,
        notes: String = "",
        contactInfo: ContactInfo? = nil,
        assignedTruckId: String? = nil,
        totalAmount: Double = 0.0,
        discountPercent: Double = 0.0,
        quoteStatus: QuoteStatus = .draft,
        paymentStatus: PaymentStatus = .pending,
        deliveryFee: Double = 0.0,
        assemblyFee: Double = 0.0,
        disassemblyFee: Double = 0.0,
        tvaRate: Double = 20.0
    ) {
        self.eventId = eventId
        self.name = name
        self.clientName = clientName
        self.clientPhone = clientPhone
        self.clientEmail = clientEmail
        self.clientAddress = clientAddress
        self.eventAddress = eventAddress
        self.setupStartTime = setupStartTime
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self._logisticsStatus = logisticsStatus
        self.notes = notes
        self.contactInfo = contactInfo
        self.assignedTruckId = assignedTruckId
        self.totalAmount = totalAmount
        self.discountPercent = discountPercent
        self.finalAmount = totalAmount * (1 - discountPercent / 100)
        self.quoteStatus = quoteStatus
        self.paymentStatus = paymentStatus
        self.deliveryFee = deliveryFee
        self.assemblyFee = assemblyFee
        self.disassemblyFee = disassemblyFee
        self.tvaRate = tvaRate
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // Calcule le montant final avec remise
    func calculateFinalAmount() {
        self.finalAmount = totalAmount * (1 - discountPercent / 100)
        self.updatedAt = Date()
    }

    // Met à jour le total depuis les QuoteItems
    func updateTotalAmount(_ newTotal: Double) {
        self.totalAmount = newTotal
        calculateFinalAmount()
    }
}

enum EventStatus: String, CaseIterable, Codable {
    case planning = "PLANIFICATION"       // Création, devis en cours
    case confirmed = "CONFIRME"           // Contrat signé
    case inProgress = "EN_COURS"          // Préparation/événement en cours
    case completed = "TERMINE"            // Tout est rangé
    case cancelled = "ANNULE"             // Annulé

    // Décodage personnalisé pour gérer la migration depuis PREPARATION
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // Migration : PREPARATION → PLANIFICATION
        if rawValue == "PREPARATION" {
            self = .planning
        } else if let status = EventStatus(rawValue: rawValue) {
            self = status
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot initialize EventStatus from invalid String value \(rawValue)"
                )
            )
        }
    }

    var displayName: String {
        switch self {
        case .planning: return "Planification"
        case .confirmed: return "Confirmé"
        case .inProgress: return "En cours"
        case .completed: return "Terminé"
        case .cancelled: return "Annulé"
        }
    }

    var color: String {
        switch self {
        case .planning: return "gray"
        case .confirmed: return "blue"
        case .inProgress: return "green"
        case .completed: return "teal"
        case .cancelled: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .planning: return "calendar.badge.clock"
        case .confirmed: return "checkmark.seal.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .planning: return .gray
        case .confirmed: return .blue
        case .inProgress: return .green
        case .completed: return .teal
        case .cancelled: return .red
        }
    }
}

enum QuoteStatus: String, Codable, CaseIterable {
    case draft = "BROUILLON"
    case finalized = "FINALISE"
    case sent = "ENVOYE"
    case accepted = "ACCEPTE"
    case refused = "REFUSE"

    var displayName: String {
        switch self {
        case .draft: return "Brouillon"
        case .finalized: return "Finalisé"
        case .sent: return "Envoyé"
        case .accepted: return "Accepté"
        case .refused: return "Refusé"
        }
    }
}

enum PaymentStatus: String, Codable, CaseIterable {
    case pending = "EN_ATTENTE"
    case deposit = "ACOMPTE"
    case paid = "PAYE"
    case refunded = "REMBOURSE"

    var displayName: String {
        switch self {
        case .pending: return "En attente"
        case .deposit: return "Acompte versé"
        case .paid: return "Payé"
        case .refunded: return "Remboursé"
        }
    }
}

struct ContactInfo: Codable {
    var name: String
    var phone: String?
    var email: String?

    init(name: String, phone: String? = nil, email: String? = nil) {
        self.name = name
        self.phone = phone
        self.email = email
    }
}

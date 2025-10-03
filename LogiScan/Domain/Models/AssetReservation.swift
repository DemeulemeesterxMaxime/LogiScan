//
//  AssetReservation.swift
//  LogiScan
//
//  Created by Demeulemeester on 02/10/2025.
//

import Foundation
import SwiftData

enum ReservationStatus: String, Codable, CaseIterable {
    case pending = "EN_ATTENTE"
    case confirmed = "CONFIRME"
    case loaded = "CHARGE"
    case delivered = "LIVRE"
    case returned = "RETOURNE"
    case cancelled = "ANNULE"

    var displayName: String {
        switch self {
        case .pending: return "En attente"
        case .confirmed: return "Confirmé"
        case .loaded: return "Chargé"
        case .delivered: return "Livré"
        case .returned: return "Retourné"
        case .cancelled: return "Annulé"
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .confirmed: return "blue"
        case .loaded: return "purple"
        case .delivered: return "green"
        case .returned: return "teal"
        case .cancelled: return "red"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .confirmed: return "checkmark.circle"
        case .loaded: return "shippingbox"
        case .delivered: return "location.circle"
        case .returned: return "arrow.uturn.left.circle"
        case .cancelled: return "xmark.circle"
        }
    }
}

@Model
final class AssetReservation {
    var reservationId: String
    var assetId: String
    var eventId: String
    var startDate: Date
    var endDate: Date
    var status: ReservationStatus
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        reservationId: String,
        assetId: String,
        eventId: String,
        startDate: Date,
        endDate: Date,
        status: ReservationStatus = .pending,
        notes: String = ""
    ) {
        self.reservationId = reservationId
        self.assetId = assetId
        self.eventId = eventId
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // Vérifie si la réservation est active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate && status != .cancelled
    }

    // Vérifie si la réservation chevauche une période
    func overlaps(startDate: Date, endDate: Date) -> Bool {
        return self.startDate < endDate && self.endDate > startDate
    }

    // Met à jour le statut
    func updateStatus(_ newStatus: ReservationStatus) {
        self.status = newStatus
        self.updatedAt = Date()
    }
}

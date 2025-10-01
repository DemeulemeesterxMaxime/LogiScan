//
//  Event.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation
import SwiftData

@Model
final class Event {
    @Attribute(.unique) var eventId: String
    var name: String
    var client: String
    var address: String
    var startDate: Date
    var endDate: Date
    var status: EventStatus
    var notes: String
    var contactInfo: ContactInfo?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        eventId: String,
        name: String,
        client: String,
        address: String,
        startDate: Date,
        endDate: Date,
        status: EventStatus = .planning,
        notes: String = "",
        contactInfo: ContactInfo? = nil
    ) {
        self.eventId = eventId
        self.name = name
        self.client = client
        self.address = address
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.notes = notes
        self.contactInfo = contactInfo
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum EventStatus: String, CaseIterable, Codable {
    case planning = "PLANIFICATION"
    case confirmed = "CONFIRME"
    case preparation = "PREPARATION"
    case inProgress = "EN_COURS"
    case completed = "TERMINE"
    case cancelled = "ANNULE"
    
    var displayName: String {
        switch self {
        case .planning: return "Planification"
        case .confirmed: return "Confirmé"
        case .preparation: return "En préparation"
        case .inProgress: return "En cours"
        case .completed: return "Terminé"
        case .cancelled: return "Annulé"
        }
    }
    
    var color: String {
        switch self {
        case .planning: return "gray"
        case .confirmed: return "blue"
        case .preparation: return "orange"
        case .inProgress: return "green"
        case .completed: return "teal"
        case .cancelled: return "red"
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

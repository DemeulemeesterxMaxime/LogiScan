//
//  FirestoreEvent.swift
//  LogiScan
//
//  Created by Demeulemeester on 12/10/2025.
//

import Foundation

/// Représentation Firestore d'un Event
struct FirestoreEvent: Codable {
    var eventId: String
    var name: String
    var clientName: String
    var clientPhone: String
    var clientEmail: String
    var clientAddress: String
    var eventAddress: String
    var setupStartTime: Date
    var startDate: Date
    var endDate: Date
    var status: String
    var logisticsStatus: String?  // Optionnel pour compatibilité avec anciens événements
    var notes: String
    var assignedTruckId: String?
    var totalAmount: Double
    var discountPercent: Double
    var finalAmount: Double
    var quoteStatus: String
    var paymentStatus: String
    var deliveryFee: Double
    var assemblyFee: Double
    var disassemblyFee: Double
    var tvaRate: Double
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case eventId
        case name
        case clientName
        case clientPhone
        case clientEmail
        case clientAddress
        case eventAddress
        case setupStartTime
        case startDate
        case endDate
        case status
        case logisticsStatus
        case notes
        case assignedTruckId
        case totalAmount
        case discountPercent
        case finalAmount
        case quoteStatus
        case paymentStatus
        case deliveryFee
        case assemblyFee
        case disassemblyFee
        case tvaRate
        case createdAt
        case updatedAt
    }
}

// MARK: - Extensions de conversion

extension Event {
    /// Convertir vers Firestore
    func toFirestoreEvent() -> FirestoreEvent {
        FirestoreEvent(
            eventId: eventId,
            name: name,
            clientName: clientName,
            clientPhone: clientPhone,
            clientEmail: clientEmail,
            clientAddress: clientAddress,
            eventAddress: eventAddress,
            setupStartTime: setupStartTime,
            startDate: startDate,
            endDate: endDate,
            status: status.rawValue,
            logisticsStatus: logisticsStatus.rawValue,
            notes: notes,
            assignedTruckId: assignedTruckId,
            totalAmount: totalAmount,
            discountPercent: discountPercent,
            finalAmount: finalAmount,
            quoteStatus: quoteStatus.rawValue,
            paymentStatus: paymentStatus.rawValue,
            deliveryFee: deliveryFee,
            assemblyFee: assemblyFee,
            disassemblyFee: disassemblyFee,
            tvaRate: tvaRate,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension FirestoreEvent {
    /// Convertir vers SwiftData Event
    func toEvent() -> Event {
        Event(
            eventId: eventId,
            name: name,
            clientName: clientName,
            clientPhone: clientPhone,
            clientEmail: clientEmail,
            clientAddress: clientAddress,
            eventAddress: eventAddress,
            setupStartTime: setupStartTime,
            startDate: startDate,
            endDate: endDate,
            status: EventStatus(rawValue: status) ?? .planning,
            logisticsStatus: logisticsStatus.flatMap { LogisticsStatus(rawValue: $0) } ?? .inStock,
            notes: notes,
            assignedTruckId: assignedTruckId,
            totalAmount: totalAmount,
            discountPercent: discountPercent,
            quoteStatus: QuoteStatus(rawValue: quoteStatus) ?? .draft,
            paymentStatus: PaymentStatus(rawValue: paymentStatus) ?? .pending,
            deliveryFee: deliveryFee,
            assemblyFee: assemblyFee,
            disassemblyFee: disassemblyFee,
            tvaRate: tvaRate
        )
    }
}

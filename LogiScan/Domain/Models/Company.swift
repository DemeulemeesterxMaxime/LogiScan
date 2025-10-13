//
//  Company.swift
//  LogiScan
//
//  Created by Demeulemeester on 12/10/2025.
//

import Foundation
import SwiftData

@Model
final class Company {
    @Attribute(.unique) var companyId: String
    var name: String
    var logoURL: String?
    var address: String?  // Optionnel
    var phone: String?    // Optionnel
    var email: String
    var siret: String?    // Optionnel car pas obligatoire
    var createdAt: Date
    var ownerId: String   // User ID de l'admin principal
    
    init(
        companyId: String = UUID().uuidString,
        name: String,
        logoURL: String? = nil,
        address: String? = nil,
        phone: String? = nil,
        email: String,
        siret: String? = nil,
        createdAt: Date = Date(),
        ownerId: String
    ) {
        self.companyId = companyId
        self.name = name
        self.logoURL = logoURL
        self.address = address
        self.phone = phone
        self.email = email
        self.siret = siret
        self.createdAt = createdAt
        self.ownerId = ownerId
    }
}

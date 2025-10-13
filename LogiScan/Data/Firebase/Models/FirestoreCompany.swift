//
//  FirestoreCompany.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import FirebaseFirestore
import Foundation

struct FirestoreCompany: Codable {
    let companyId: String
    let name: String
    let logoURL: String?
    let address: String?  // Optionnel
    let phone: String?    // Optionnel
    let email: String
    let siret: String?    // Optionnel
    let createdAt: Timestamp
    let ownerId: String
    
    // Conversion vers SwiftData
    func toSwiftData() -> Company {
        return Company(
            companyId: companyId,
            name: name,
            logoURL: logoURL,
            address: address,
            phone: phone,
            email: email,
            siret: siret,
            createdAt: createdAt.dateValue(),
            ownerId: ownerId
        )
    }
}

// Extension Company pour conversion vers Firestore
extension Company {
    func toFirestoreCompany() -> FirestoreCompany {
        return FirestoreCompany(
            companyId: companyId,
            name: name,
            logoURL: logoURL,
            address: address,
            phone: phone,
            email: email,
            siret: siret,
            createdAt: Timestamp(date: createdAt),
            ownerId: ownerId
        )
    }
}

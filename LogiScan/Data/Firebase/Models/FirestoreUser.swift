//
//  FirestoreUser.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import FirebaseFirestore
import Foundation

struct FirestoreUser: Codable {
    var userId: String
    var email: String
    var displayName: String
    var photoURL: String?
    var accountType: String  // "company" ou "employee"
    var companyId: String?
    var role: String?  // "admin", "manager", "standardEmployee", "limitedEmployee"
    var joinedAt: Timestamp?
    var createdAt: Timestamp
    var updatedAt: Timestamp
    
    // Conversion vers SwiftData
    func toSwiftData() -> User {
        let accountTypeEnum = User.AccountType(rawValue: accountType) ?? .employee
        let roleEnum = role != nil ? User.UserRole(rawValue: role!) : nil
        
        return User(
            userId: userId,
            email: email,
            displayName: displayName,
            photoURL: photoURL,
            accountType: accountTypeEnum,
            companyId: companyId,
            role: roleEnum
        )
    }
}

// Extension User pour conversion vers Firestore
extension User {
    func toFirestoreUser() -> FirestoreUser {
        return FirestoreUser(
            userId: userId,
            email: email,
            displayName: displayName,
            photoURL: photoURL,
            accountType: accountType.rawValue,
            companyId: companyId,
            role: role?.rawValue,
            joinedAt: joinedAt != nil ? Timestamp(date: joinedAt!) : nil,
            createdAt: Timestamp(date: createdAt),
            updatedAt: Timestamp(date: updatedAt)
        )
    }
}

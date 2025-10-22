//
//  FirestoreInvitationCode.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import FirebaseFirestore
import Foundation

struct FirestoreInvitationCode: Codable {
    var codeId: String
    var code: String
    var customName: String?  // Nom personnalisé
    var companyId: String
    var companyName: String
    var role: String  // "admin", "manager", "standardEmployee", "limitedEmployee"
    var createdBy: String
    var createdAt: Timestamp
    var expiresAt: Timestamp
    var maxUses: Int
    var usedCount: Int
    var isActive: Bool
    var isArchived: Bool  // Archivé quand maxUses atteint
    
    // Conversion vers SwiftData
    func toSwiftData() -> InvitationCode {
        let roleEnum = User.UserRole(rawValue: role) ?? .limitedEmployee
        
        let invitation = InvitationCode(
            codeId: codeId,
            companyId: companyId,
            companyName: companyName,
            customName: customName,
            role: roleEnum,
            createdBy: createdBy,
            validityDays: 7,
            maxUses: maxUses
        )
        
        // Override generated values with Firestore values
        invitation.code = code
        invitation.createdAt = createdAt.dateValue()
        invitation.expiresAt = expiresAt.dateValue()
        invitation.usedCount = usedCount
        invitation.isActive = isActive
        invitation.isArchived = isArchived
        
        return invitation
    }
}

// Extension InvitationCode pour conversion vers Firestore
extension InvitationCode {
    func toFirestoreInvitationCode() -> FirestoreInvitationCode {
        return FirestoreInvitationCode(
            codeId: codeId,
            code: code,
            customName: customName,
            companyId: companyId,
            companyName: companyName,
            role: role.rawValue,
            createdBy: createdBy,
            createdAt: Timestamp(date: createdAt),
            expiresAt: Timestamp(date: expiresAt),
            maxUses: maxUses,
            usedCount: usedCount,
            isActive: isActive,
            isArchived: isArchived
        )
    }
}

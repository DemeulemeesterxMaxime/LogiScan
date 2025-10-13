//
//  InvitationCode.swift
//  LogiScan
//
//  Created by Demeulemeester on 12/10/2025.
//

import Foundation
import SwiftData

@Model
final class InvitationCode {
    @Attribute(.unique) var codeId: String
    var code: String  // Format: COMPANY-2025-X7K9
    var companyId: String
    var companyName: String
    var role: User.UserRole
    var createdBy: String  // userId de l'admin
    var createdAt: Date
    var expiresAt: Date
    var maxUses: Int
    var usedCount: Int
    var isActive: Bool
    
    var isValid: Bool {
        return isActive &&
               usedCount < maxUses &&
               expiresAt > Date()
    }
    
    init(
        codeId: String = UUID().uuidString,
        companyId: String,
        companyName: String,
        role: User.UserRole,
        createdBy: String,
        validityDays: Int = 7,
        maxUses: Int = 10
    ) {
        self.codeId = codeId
        self.code = Self.generateCode(companyName: companyName)
        self.companyId = companyId
        self.companyName = companyName
        self.role = role
        self.createdBy = createdBy
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(TimeInterval(validityDays * 86400))
        self.maxUses = maxUses
        self.usedCount = 0
        self.isActive = true
    }
    
    static func generateCode(companyName: String) -> String {
        let prefix = companyName
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
            .prefix(8)
        let year = Calendar.current.component(.year, from: Date())
        let random = String((0..<4).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        return "\(prefix)-\(year)-\(random)"
    }
}

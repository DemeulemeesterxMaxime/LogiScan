//
//  InvitationCode.swift
//  LogiScan
//
//  Created by Demeulemeester on 12/10/2025.
//

import Foundation
import SwiftData

@Model
final class InvitationCode: @unchecked Sendable {
    @Attribute(.unique) var codeId: String
    var code: String  // Format: COMPANY-2025-X7K9
    var customName: String?  // Nom personnalisé optionnel (ex: "Code Équipe Livraison")
    var companyId: String
    var companyName: String
    var role: User.UserRole
    var createdBy: String  // userId de l'admin
    var createdAt: Date
    var expiresAt: Date
    var maxUses: Int
    var usedCount: Int
    var isActive: Bool
    var isArchived: Bool  // Archivé automatiquement quand utilisé complètement
    
    var isValid: Bool {
        return isActive &&
               !isArchived &&
               usedCount < maxUses &&
               expiresAt > Date()
    }
    
    /// Nom d'affichage : customName si défini, sinon le code
    var displayName: String {
        return customName ?? code
    }
    
    /// Statut du code pour l'affichage
    var status: CodeStatus {
        if isArchived { return .archived }
        if !isActive { return .inactive }
        if expiresAt < Date() { return .expired }
        if usedCount >= maxUses { return .exhausted }
        return .active
    }
    
    enum CodeStatus: String {
        case active = "Actif"
        case inactive = "Inactif"
        case expired = "Expiré"
        case exhausted = "Épuisé"
        case archived = "Archivé"
        
        var color: String {
            switch self {
            case .active: return "green"
            case .inactive: return "orange"
            case .expired: return "red"
            case .exhausted: return "gray"
            case .archived: return "gray"
            }
        }
    }
    
    init(
        codeId: String = UUID().uuidString,
        companyId: String,
        companyName: String,
        customCode: String? = nil,  // Code personnalisé optionnel
        customName: String? = nil,
        role: User.UserRole,
        createdBy: String,
        validityDays: Int = 7,
        maxUses: Int = 10
    ) {
        self.codeId = codeId
        // Utiliser le code personnalisé si fourni, sinon générer automatiquement
        self.code = customCode?.uppercased() ?? Self.generateCode(companyName: companyName)
        self.customName = customName
        self.companyId = companyId
        self.companyName = companyName
        self.role = role
        self.createdBy = createdBy
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(TimeInterval(validityDays * 86400))
        self.maxUses = maxUses
        self.usedCount = 0
        self.isActive = true
        self.isArchived = false
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

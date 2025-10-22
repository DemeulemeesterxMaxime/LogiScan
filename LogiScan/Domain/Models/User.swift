//
//  User.swift
//  LogiScan
//
//  Created by Demeulemeester on 12/10/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class User {
    @Attribute(.unique) var userId: String
    var email: String
    var displayName: String
    var photoURL: String?
    var accountType: AccountType
    
    // Informations entreprise (si employé)
    var companyId: String?
    var role: UserRole?
    var joinedAt: Date?
    
    var createdAt: Date
    var updatedAt: Date
    
    init(
        userId: String,
        email: String,
        displayName: String,
        photoURL: String? = nil,
        accountType: AccountType,
        companyId: String? = nil,
        role: UserRole? = nil
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.accountType = accountType
        self.companyId = companyId
        self.role = role
        self.joinedAt = role != nil ? Date() : nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func hasPermission(_ permission: Permission) -> Bool {
        guard let role = role else { return false }
        return role.permissions.contains(permission)
    }
}

// MARK: - Account Type

extension User {
    enum AccountType: String, Codable {
        case company    // Admin d'entreprise
        case employee   // Employé
        
        var displayName: String {
            switch self {
            case .company: return "Entreprise"
            case .employee: return "Employé"
            }
        }
    }
}

// MARK: - User Role

extension User {
    enum UserRole: String, Codable, CaseIterable {
        case admin           // Propriétaire
        case manager         // Manager
        case standardEmployee // Employé standard
        case limitedEmployee  // Employé limité
        
        var displayName: String {
            switch self {
            case .admin: return "Admin"
            case .manager: return "Manager"
            case .standardEmployee: return "Employé"
            case .limitedEmployee: return "Employé limité"
            }
        }
        
        var icon: String {
            switch self {
            case .admin: return "crown.fill"
            case .manager: return "person.2.fill"
            case .standardEmployee: return "person.fill"
            case .limitedEmployee: return "person.crop.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .admin: return .purple
            case .manager: return .blue
            case .standardEmployee: return .green
            case .limitedEmployee: return .orange
            }
        }
        
        var permissions: [Permission] {
            switch self {
            case .admin:
                return Permission.allCases
            case .manager:
                return [.readEvents, .writeEvents, .readStock, .writeStock,
                        .readQuotes, .writeQuotes, .manageTrucks, .scanQR,
                        .updateAssetStatus, .readTasks, .writeTasks, .assignTasks,
                        .manageTasks]
            case .standardEmployee:
                return [.readEvents, .readStock, .readQuotes, .scanQR,
                        .updateAssetStatus, .readTasks]
            case .limitedEmployee:
                return [.scanQR, .readStock, .readTasks]
            }
        }
    }
}

// MARK: - Permission

extension User {
    enum Permission: String, CaseIterable, Codable {
        case readEvents
        case writeEvents
        case readStock
        case writeStock
        case readQuotes
        case writeQuotes
        case manageTrucks
        case manageMembers
        case editCompany
        case scanQR
        case updateAssetStatus
        case readTasks
        case writeTasks
        case assignTasks
        case manageTasks
        
        var displayName: String {
            switch self {
            case .readEvents: return "Consulter les événements"
            case .writeEvents: return "Gérer les événements"
            case .readStock: return "Consulter le stock"
            case .writeStock: return "Gérer le stock"
            case .readQuotes: return "Consulter les devis"
            case .writeQuotes: return "Gérer les devis"
            case .manageTrucks: return "Gérer les camions"
            case .manageMembers: return "Gérer les membres"
            case .editCompany: return "Modifier l'entreprise"
            case .scanQR: return "Scanner les QR codes"
            case .updateAssetStatus: return "Mettre à jour le matériel"
            case .readTasks: return "Consulter les tâches"
            case .writeTasks: return "Créer des tâches"
            case .assignTasks: return "Attribuer des tâches"
            case .manageTasks: return "Gérer toutes les tâches"
            }
        }
    }
}

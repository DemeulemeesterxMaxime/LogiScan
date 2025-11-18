//
//  Task.swift
//  LogiScan
//
//  Created by Demeulemeester on 18/10/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class TodoTask {
    @Attribute(.unique) var taskId: String
    var title: String?  // Optionnel : utilise le nom du type si nil
    var taskDescription: String?
    var type: TaskType
    var status: TaskStatus
    var priority: TaskPriority
    
    // Computed property pour obtenir le titre affiché
    var displayTitle: String {
        return title ?? type.displayName
    }
    
    // Relations
    var eventId: String?
    var scanListId: String?
    var truckId: String?
    
    // Attribution
    var assignedToUserId: String?
    var assignedToUserName: String?
    var createdBy: String  // userId du créateur
    var companyId: String
    
    // Workflow (chaînage de tâches)
    var nextTaskId: String?
    var previousTaskId: String?
    var triggerNotification: Bool
    
    // Timestamps
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var dueDate: Date?
    
    // Métadonnées
    var estimatedDuration: Int?  // En minutes
    var location: String?  // Ex: "Stock", "Event", "Camion A"
    
    init(
        taskId: String = UUID().uuidString,
        title: String? = nil,  // Optionnel maintenant
        taskDescription: String? = nil,
        type: TaskType,
        status: TaskStatus = .pending,
        priority: TaskPriority = .medium,
        eventId: String? = nil,
        scanListId: String? = nil,
        truckId: String? = nil,
        assignedToUserId: String? = nil,
        assignedToUserName: String? = nil,
        createdBy: String,
        companyId: String,
        nextTaskId: String? = nil,
        previousTaskId: String? = nil,
        triggerNotification: Bool = false,
        dueDate: Date? = nil,
        estimatedDuration: Int? = nil,
        location: String? = nil
    ) {
        self.taskId = taskId
        self.title = title
        self.taskDescription = taskDescription
        self.type = type
        self.status = status
        self.priority = priority
        self.eventId = eventId
        self.scanListId = scanListId
        self.truckId = truckId
        self.assignedToUserId = assignedToUserId
        self.assignedToUserName = assignedToUserName
        self.createdBy = createdBy
        self.companyId = companyId
        self.nextTaskId = nextTaskId
        self.previousTaskId = previousTaskId
        self.triggerNotification = triggerNotification
        self.createdAt = Date()
        self.dueDate = dueDate
        self.estimatedDuration = estimatedDuration
        self.location = location
    }
}

// MARK: - Task Type

extension TodoTask {
    enum TaskType: String, Codable, CaseIterable {
        // Inventaire
        case inventoryCheck = "inventory_check"
        
        // Stock
        case organizeStock = "organize_stock"
        case prepareItems = "prepare_items"
        
        // Listes de scan
        case createScanList = "create_scan_list"
        
        // Camion - Chargement
        case loadTruckFromStock = "load_truck_from_stock"
        case unloadTruckAtEvent = "unload_truck_at_event"
        
        // Camion - Retour
        case loadTruckAtEvent = "load_truck_at_event"
        case unloadTruckAtStock = "unload_truck_at_stock"
        case returnItemsToPlace = "return_items_to_place"
        
        // Transport
        case transportToEvent = "transport_to_event"
        case transportReturn = "transport_return"
        
        // Événement
        case eventSetup = "event_setup"
        case eventOperation = "event_operation"
        case eventTeardown = "event_teardown"
        
        // Scan
        case scanPreparation = "scan_preparation"
        case scanLoading = "scan_loading"
        case scanUnloading = "scan_unloading"
        case scanReturn = "scan_return"
        
        // Autres
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .inventoryCheck: return "Faire inventaire"
            case .organizeStock: return "Ranger le stock"
            case .prepareItems: return "Préparer les articles"
            case .createScanList: return "Créer liste de scan"
            case .loadTruckFromStock: return "Charger camion (stock)"
            case .unloadTruckAtEvent: return "Décharger camion (event)"
            case .loadTruckAtEvent: return "Charger camion (event)"
            case .unloadTruckAtStock: return "Décharger camion (stock)"
            case .returnItemsToPlace: return "Remettre à sa place"
            case .transportToEvent: return "Transport vers événement"
            case .transportReturn: return "Transport retour stock"
            case .eventSetup: return "Montage événement"
            case .eventOperation: return "Opération événement"
            case .eventTeardown: return "Démontage événement"
            case .scanPreparation: return "Scanner préparation"
            case .scanLoading: return "Scanner chargement"
            case .scanUnloading: return "Scanner déchargement"
            case .scanReturn: return "Scanner retour"
            case .custom: return "Tâche personnalisée"
            }
        }
        
        var icon: String {
            switch self {
            case .inventoryCheck: return "list.bullet.clipboard"
            case .organizeStock: return "square.stack.3d.up"
            case .prepareItems: return "shippingbox"
            case .createScanList: return "list.bullet.rectangle"
            case .loadTruckFromStock: return "arrow.up.bin"
            case .unloadTruckAtEvent: return "arrow.down.circle"
            case .loadTruckAtEvent: return "arrow.up.bin.fill"
            case .unloadTruckAtStock: return "arrow.down.circle.fill"
            case .returnItemsToPlace: return "arrow.turn.up.left"
            case .transportToEvent: return "truck.box"
            case .transportReturn: return "arrow.uturn.left"
            case .eventSetup: return "hammer"
            case .eventOperation: return "play.circle"
            case .eventTeardown: return "wrench.and.screwdriver"
            case .scanPreparation: return "qrcode.viewfinder"
            case .scanLoading: return "qrcode"
            case .scanUnloading: return "qrcode"
            case .scanReturn: return "qrcode"
            case .custom: return "star"
            }
        }
        
        var suggestedLocation: String {
            switch self {
            case .inventoryCheck, .organizeStock, .prepareItems, .returnItemsToPlace:
                return "Stock"
            case .createScanList:
                return "Bureau"
            case .loadTruckFromStock, .unloadTruckAtStock:
                return "Stock"
            case .loadTruckAtEvent, .unloadTruckAtEvent:
                return "Événement"
            case .transportToEvent, .transportReturn:
                return "En déplacement"
            case .eventSetup, .eventOperation, .eventTeardown:
                return "Événement"
            case .scanPreparation:
                return "Stock"
            case .scanLoading, .scanReturn:
                return "Stock"
            case .scanUnloading:
                return "Événement"
            case .custom:
                return "Variable"
            }
        }
    }
}

// MARK: - Task Status

extension TodoTask {
    enum TaskStatus: String, Codable, CaseIterable {
        case pending = "pending"
        case inProgress = "in_progress"
        case completed = "completed"
        case cancelled = "cancelled"
        case blocked = "blocked"
        
        var displayName: String {
            switch self {
            case .pending: return "En attente"
            case .inProgress: return "En cours"
            case .completed: return "Terminée"
            case .cancelled: return "Annulée"
            case .blocked: return "Bloquée"
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .inProgress: return "arrow.clockwise"
            case .completed: return "checkmark.circle.fill"
            case .cancelled: return "xmark.circle.fill"
            case .blocked: return "lock.fill"
            }
        }
        
        var color: String {
            switch self {
            case .pending: return "orange"
            case .inProgress: return "blue"
            case .completed: return "green"
            case .cancelled: return "red"
            case .blocked: return "gray"
            }
        }
    }
}

// MARK: - Task Priority

extension TodoTask {
    enum TaskPriority: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case urgent = "urgent"
        
        var displayName: String {
            switch self {
            case .low: return "Basse"
            case .medium: return "Moyenne"
            case .high: return "Haute"
            case .urgent: return "Urgente"
            }
        }
        
        var icon: String {
            switch self {
            case .low: return "arrow.down"
            case .medium: return "minus"
            case .high: return "arrow.up"
            case .urgent: return "exclamationmark.2"
            }
        }
        
        var color: String {
            switch self {
            case .low: return "gray"
            case .medium: return "blue"
            case .high: return "orange"
            case .urgent: return "red"
            }
        }
        
        // Conversion vers SwiftUI Color
        var swiftUIColor: Color {
            switch self {
            case .low: return .gray
            case .medium: return .blue
            case .high: return .orange
            case .urgent: return .red
            }
        }
    }
}

// MARK: - Color Extension for Status

extension TodoTask.TaskStatus {
    // Conversion vers SwiftUI Color
    var swiftUIColor: Color {
        switch self {
        case .pending: return .blue
        case .inProgress: return .green
        case .completed: return .gray
        case .cancelled: return .red
        case .blocked: return .orange
        }
    }
}

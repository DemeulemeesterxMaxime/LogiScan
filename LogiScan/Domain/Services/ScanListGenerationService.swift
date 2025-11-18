//
//  ScanListGenerationService.swift
//  LogiScan
//
//  Created by Assistant on 12/11/2025.
//

import Foundation
import SwiftData

/// Service pour générer automatiquement les listes de scan et tâches associées lors de la validation d'un devis
@MainActor
class ScanListGenerationService: ObservableObject {
    
    /// Génère les listes de scan pour un événement selon les directions sélectionnées
    /// - Parameters:
    ///   - event: L'événement pour lequel générer les listes
    ///   - quoteItems: Les articles du devis
    ///   - generateTasks: Si true, génère aussi les tâches associées
    ///   - userId: L'ID de l'utilisateur qui génère les listes
    ///   - modelContext: Le contexte SwiftData
    /// - Returns: Les listes de scan créées
    func generateScanLists(
        for event: Event,
        quoteItems: [QuoteItem],
        generateTasks: Bool,
        userId: String,
        modelContext: ModelContext
    ) throws -> [ScanList] {
        
        print("📋 [ScanListGeneration] Génération des listes de scan pour l'événement '\(event.name)'")
        print("   Directions sélectionnées: \(event.selectedScanDirections)")
        print("   Générer tâches: \(generateTasks)")
        
        guard !event.selectedScanDirections.isEmpty else {
            print("⚠️ [ScanListGeneration] Aucune direction sélectionnée, pas de liste générée")
            return []
        }
        
        var createdLists: [ScanList] = []
        var previousTask: TodoTask? = nil
        
        // Pour chaque direction sélectionnée, créer une liste de scan
        for directionRaw in event.selectedScanDirections {
            guard let direction = ScanDirection(rawValue: directionRaw) else {
                print("⚠️ [ScanListGeneration] Direction inconnue: \(directionRaw)")
                continue
            }
            
            // Créer la liste de scan
            let scanList = ScanList(
                eventId: event.eventId,
                eventName: event.name,
                scanDirection: direction,
                totalItems: quoteItems.reduce(0) { $0 + $1.quantity },
                scannedItems: 0,
                status: .pending
            )
            
            modelContext.insert(scanList)
            createdLists.append(scanList)
            
            print("   ✅ Liste créée: \(direction.displayName) (\(scanList.totalItems) items)")
            
            // Créer les items de préparation pour chaque article du devis
            for quoteItem in quoteItems {
                for _ in 0..<quoteItem.quantity {
                    let prepItem = PreparationListItem(
                        scanListId: scanList.scanListId,
                        sku: quoteItem.sku,
                        name: quoteItem.name,
                        category: quoteItem.category,
                        quantityRequired: 1
                    )
                    modelContext.insert(prepItem)
                }
            }
            
            // Générer une tâche associée si demandé
            if generateTasks {
                let task = try createTaskForScanList(
                    scanList: scanList,
                    event: event,
                    userId: userId,
                    previousTask: previousTask,
                    modelContext: modelContext
                )
                
                // Chaîner avec la tâche précédente
                if let prev = previousTask {
                    prev.nextTaskId = task.taskId
                    task.previousTaskId = prev.taskId
                }
                
                previousTask = task
                print("   ✅ Tâche créée: \(task.displayTitle)")
            }
        }
        
        // Sauvegarder toutes les modifications
        try modelContext.save()
        
        print("✅ [ScanListGeneration] \(createdLists.count) liste(s) de scan créée(s)")
        if generateTasks {
            print("✅ [ScanListGeneration] \(createdLists.count) tâche(s) créée(s) et chaînée(s)")
        }
        
        return createdLists
    }
    
    /// Crée une tâche associée à une liste de scan
    private func createTaskForScanList(
        scanList: ScanList,
        event: Event,
        userId: String,
        previousTask: TodoTask?,
        modelContext: ModelContext
    ) throws -> TodoTask {
        
        // Déterminer le type de tâche selon la direction du scan
        let taskType = getTaskType(for: scanList.scanDirection)
        
        // Déterminer le lieu
        let location = getTaskLocation(for: scanList.scanDirection)
        
        // Créer la tâche
        let task = TodoTask(
            title: scanList.displayName,
            taskDescription: scanList.scanDirection.description,
            type: taskType,
            status: previousTask != nil ? .blocked : .pending,  // Bloquée si dépend d'une autre
            priority: .medium,
            eventId: event.eventId,
            scanListId: scanList.scanListId,
            truckId: event.assignedTruckId,
            createdBy: userId,
            companyId: event.eventId,  // TODO: Utiliser le vrai companyId
            previousTaskId: previousTask?.taskId,
            triggerNotification: true,
            location: location
        )
        
        modelContext.insert(task)
        
        return task
    }
    
    /// Détermine le type de tâche selon la direction du scan
    private func getTaskType(for direction: ScanDirection) -> TodoTask.TaskType {
        switch direction {
        case .stockToTruck:
            return .loadTruckFromStock
        case .truckToEvent:
            return .unloadTruckAtEvent
        case .eventToTruck:
            return .loadTruckAtEvent
        case .truckToStock:
            return .unloadTruckAtStock
        }
    }
    
    /// Détermine le lieu de la tâche selon la direction du scan
    private func getTaskLocation(for direction: ScanDirection) -> String {
        switch direction {
        case .stockToTruck, .truckToStock:
            return "Stock"
        case .truckToEvent, .eventToTruck:
            return "Événement"
        }
    }
    
    /// Met à jour le statut d'une liste de scan après confirmation
    /// - Parameters:
    ///   - scanList: La liste de scan à mettre à jour
    ///   - modelContext: Le contexte SwiftData
    func completeScanList(
        scanList: ScanList,
        modelContext: ModelContext
    ) throws {
        
        print("✅ [ScanListGeneration] Complétion de la liste '\(scanList.displayName)'")
        
        // Marquer la liste comme complétée
        scanList.status = .completed
        scanList.completedAt = Date()
        scanList.updatedAt = Date()
        
        // Trouver la tâche associée (si existe)
        let scanListId = scanList.scanListId
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate { $0.scanListId == scanListId }
        )
        
        if let task = try modelContext.fetch(descriptor).first {
            print("   📋 Mise à jour de la tâche associée: \(task.displayTitle)")
            
            // Marquer la tâche comme terminée
            task.status = .completed
            task.completedAt = Date()
            
            // Notifier la complétion de la tâche
            if let nextTaskId = task.nextTaskId {
                // Trouver et débloquer la tâche suivante
                let nextTaskDescriptor = FetchDescriptor<TodoTask>(
                    predicate: #Predicate { $0.taskId == nextTaskId }
                )
                
                if let nextTask = try modelContext.fetch(nextTaskDescriptor).first {
                    print("   🔓 Déblocage de la tâche suivante: \(nextTask.displayTitle)")
                    nextTask.status = .pending
                    
                    // Envoyer notification
                    try TaskNotificationService.shared.notifyTaskCompleted(
                        task: task,
                        nextTask: nextTask,
                        modelContext: modelContext
                    )
                }
            } else {
                // Pas de tâche suivante, juste notifier la complétion
                try TaskNotificationService.shared.notifyTaskCompleted(
                    task: task,
                    nextTask: nil,
                    modelContext: modelContext
                )
            }
        }
        
        // Notification Apple pour la liste complète
        Task {
            await NotificationManager.shared.notifyScanListCompleted(
                scanList: scanList,
                eventName: scanList.eventName
            )
        }
        
        try modelContext.save()
        print("✅ [ScanListGeneration] Liste et tâche associée complétées")
    }
    
    /// Met à jour le statut d'un asset après scan dans une liste
    /// - Parameters:
    ///   - asset: L'asset scanné
    ///   - scanList: La liste de scan dans laquelle il a été scanné
    ///   - modelContext: Le contexte SwiftData
    func updateAssetStatusAfterScan(
        asset: Asset,
        scanList: ScanList,
        modelContext: ModelContext
    ) throws {
        
        let oldStatus = asset.status
        let newStatus = getAssetStatusForDirection(scanList.scanDirection)
        
        print("🔄 [ScanListGeneration] Mise à jour statut asset '\(asset.name)'")
        print("   Anciennent: \(oldStatus.displayName)")
        print("   Nouveau: \(newStatus.displayName)")
        
        asset.status = newStatus
        asset.updatedAt = Date()
        
        try modelContext.save()
    }
    
    /// Détermine le nouveau statut d'un asset selon la direction du scan
    private func getAssetStatusForDirection(_ direction: ScanDirection) -> AssetStatus {
        switch direction {
        case .stockToTruck:
            // Stock → Camion : en transit vers l'événement
            return .inTransitToEvent
        case .truckToEvent:
            // Camion → Événement : en utilisation sur site
            return .inUse
        case .eventToTruck:
            // Événement → Camion : en transit vers le stock
            return .inTransitToStock
        case .truckToStock:
            // Camion → Stock : de retour, disponible
            return .available
        }
    }
}

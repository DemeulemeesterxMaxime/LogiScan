//
//  FirestoreScanList.swift
//  LogiScan
//
//  Created by Assistant on 28/10/2025.
//

import Foundation
import FirebaseFirestore
import SwiftData

struct FirestoreScanList: Codable {
    @DocumentID var id: String?
    var scanListId: String
    var eventId: String
    var eventName: String
    var scanDirection: String // raw value of ScanDirection enum
    var totalItems: Int
    var scannedItems: Int
    var status: String // raw value of ScanListStatus enum
    var createdAt: Timestamp
    var updatedAt: Timestamp
    var completedAt: Timestamp?
    
    init(
        scanListId: String,
        eventId: String,
        eventName: String,
        scanDirection: String,
        totalItems: Int,
        scannedItems: Int,
        status: String,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date?
    ) {
        self.scanListId = scanListId
        self.eventId = eventId
        self.eventName = eventName
        self.scanDirection = scanDirection
        self.totalItems = totalItems
        self.scannedItems = scannedItems
        self.status = status
        self.createdAt = Timestamp(date: createdAt)
        self.updatedAt = Timestamp(date: updatedAt)
        self.completedAt = completedAt.map { Timestamp(date: $0) }
    }
}

struct FirestorePreparationListItem: Codable {
    var preparationListItemId: String
    var scanListId: String
    var sku: String
    var name: String
    var category: String
    var quantityRequired: Int
    var quantityScanned: Int
    var scannedAssets: [String]
    var status: String // raw value of ScanItemStatus enum
    var lastScannedAt: Timestamp?
    
    init(
        preparationListItemId: String,
        scanListId: String,
        sku: String,
        name: String,
        category: String,
        quantityRequired: Int,
        quantityScanned: Int,
        scannedAssets: [String],
        status: String,
        lastScannedAt: Date?
    ) {
        self.preparationListItemId = preparationListItemId
        self.scanListId = scanListId
        self.sku = sku
        self.name = name
        self.category = category
        self.quantityRequired = quantityRequired
        self.quantityScanned = quantityScanned
        self.scannedAssets = scannedAssets
        self.status = status
        self.lastScannedAt = lastScannedAt.map { Timestamp(date: $0) }
    }
}

// MARK: - Extensions de conversion

extension ScanList {
    func toFirestoreScanList() -> FirestoreScanList {
        return FirestoreScanList(
            scanListId: self.scanListId,
            eventId: self.eventId,
            eventName: self.eventName,
            scanDirection: self.scanDirection.rawValue,
            totalItems: self.totalItems,
            scannedItems: self.scannedItems,
            status: self.status.rawValue,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            completedAt: self.completedAt
        )
    }
}

extension FirestoreScanList {
    func toScanList() -> ScanList? {
        guard let direction = ScanDirection(rawValue: self.scanDirection),
              let status = ScanListStatus(rawValue: self.status) else {
            return nil
        }
        
        return ScanList(
            scanListId: self.scanListId,
            eventId: self.eventId,
            eventName: self.eventName,
            scanDirection: direction,
            totalItems: self.totalItems,
            scannedItems: self.scannedItems,
            status: status,
            createdAt: self.createdAt.dateValue(),
            updatedAt: self.updatedAt.dateValue(),
            completedAt: self.completedAt?.dateValue()
        )
    }
}

extension PreparationListItem {
    func toFirestorePreparationListItem() -> FirestorePreparationListItem {
        return FirestorePreparationListItem(
            preparationListItemId: self.preparationListItemId,
            scanListId: self.scanListId,
            sku: self.sku,
            name: self.name,
            category: self.category,
            quantityRequired: self.quantityRequired,
            quantityScanned: self.quantityScanned,
            scannedAssets: self.scannedAssets,
            status: self.status.rawValue,
            lastScannedAt: self.lastScannedAt
        )
    }
}

extension FirestorePreparationListItem {
    func toPreparationListItem() -> PreparationListItem? {
        guard let status = ScanItemStatus(rawValue: self.status) else {
            return nil
        }
        
        return PreparationListItem(
            preparationListItemId: self.preparationListItemId,
            scanListId: self.scanListId,
            sku: self.sku,
            name: self.name,
            category: self.category,
            quantityRequired: self.quantityRequired,
            quantityScanned: self.quantityScanned,
            scannedAssets: self.scannedAssets,
            status: status,
            lastScannedAt: self.lastScannedAt?.dateValue()
        )
    }
}


//
//  SearchExtensions.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import Foundation

extension Array where Element == StockItem {
    func filteredBySearch(_ searchText: String) -> [StockItem] {
        guard !searchText.isEmpty else { return self }

        let lowercaseQuery = searchText.lowercased()
        return filter { item in
            item.name.lowercased().contains(lowercaseQuery)
                || item.sku.lowercased().contains(lowercaseQuery)
                || item.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }

    func filteredByTag(_ tag: String) -> [StockItem] {
        guard !tag.isEmpty else { return self }
        return filter { $0.tags.contains(tag) }
    }

    func filteredByCategory(_ category: String) -> [StockItem] {
        guard category != "Tous" else { return self }
        return filter { $0.category == category }
    }
}

extension Array where Element == Event {
    func filteredBySearch(_ searchText: String) -> [Event] {
        guard !searchText.isEmpty else { return self }

        let lowercaseQuery = searchText.lowercased()
        return filter { event in
            event.name.lowercased().contains(lowercaseQuery)
                || event.clientName.lowercased().contains(lowercaseQuery)
                || event.eventAddress.lowercased().contains(lowercaseQuery)
        }
    }
}

extension Array where Element == Truck {
    func filteredBySearch(_ searchText: String) -> [Truck] {
        guard !searchText.isEmpty else { return self }

        let lowercaseQuery = searchText.lowercased()
        return filter { truck in
            truck.licensePlate.lowercased().contains(lowercaseQuery)
                || truck.truckId.lowercased().contains(lowercaseQuery)
        }
    }
}

extension Array where Element == Asset {
    func filteredBySearch(_ searchText: String) -> [Asset] {
        guard !searchText.isEmpty else { return self }

        let lowercaseQuery = searchText.lowercased()
        return filter { asset in
            asset.name.lowercased().contains(lowercaseQuery)
                || asset.sku.lowercased().contains(lowercaseQuery)
                || asset.assetId.lowercased().contains(lowercaseQuery)
                || (asset.serialNumber?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }
}

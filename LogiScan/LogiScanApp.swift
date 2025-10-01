//
//  LogiScanApp.swift
//  LogiScan
//
//  Created by Demeulemeester on 24/09/2025.
//

import SwiftUI
import SwiftData

@main
struct LogiScanApp: App {
    let sharedModelContainer: ModelContainer
    
    init() {
        do {
            sharedModelContainer = try ModelContainer(
                for: Asset.self,
                     StockItem.self,
                     Location.self,
                     Truck.self,
                     Event.self,
                     Order.self,
                     OrderLine.self,
                     OrderTimestamp.self,
                     Movement.self
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}

//
//  Item.swift
//  LogiScan
//
//  Created by Demeulemeester on 24/09/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

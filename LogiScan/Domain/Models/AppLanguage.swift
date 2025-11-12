//
//  AppLanguage.swift
//  LogiScan
//
//  Created by GitHub Copilot on 12/11/2025.
//

import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case french = "fr"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .french:
            return "Français"
        case .english:
            return "English"
        }
    }
    
    var flag: String {
        switch self {
        case .french:
            return "🇫🇷"
        case .english:
            return "🇬🇧"
        }
    }
    
    var locale: Locale {
        switch self {
        case .french:
            return Locale(identifier: "fr_FR")
        case .english:
            return Locale(identifier: "en_US")
        }
    }
}

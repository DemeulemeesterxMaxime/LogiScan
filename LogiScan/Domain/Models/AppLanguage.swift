//
//  AppLanguage.swift
//  LogiScan
//
//  Created by GitHub Copilot on 12/11/2025.
//

import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case english = "en"
    case mandarin = "zh"
    case hindi = "hi"
    case spanish = "es"
    case french = "fr"
    case arabic = "ar"
    case russian = "ru"
    case portuguese = "pt"
    case bengali = "bn"
    case german = "de"
    
    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .mandarin:
            return "中文"
        case .hindi:
            return "हिन्दी"
        case .spanish:
            return "Español"
        case .french:
            return "Français"
        case .arabic:
            return "العربية"
        case .russian:
            return "Русский"
        case .portuguese:
            return "Português"
        case .bengali:
            return "বাংলা"
        case .german:
            return "Deutsch"
        }
    }
    
    var flag: String {
        switch self {
        case .english:
            return "🇬🇧"
        case .mandarin:
            return "🇨🇳"
        case .hindi:
            return "🇮🇳"
        case .spanish:
            return "🇪🇸"
        case .french:
            return "🇫🇷"
        case .arabic:
            return "🇸🇦"
        case .russian:
            return "🇷🇺"
        case .portuguese:
            return "🇵🇹"
        case .bengali:
            return "🇧🇩"
        case .german:
            return "🇩🇪"
        }
    }
    
    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en_US")
        case .mandarin:
            return Locale(identifier: "zh_CN")
        case .hindi:
            return Locale(identifier: "hi_IN")
        case .spanish:
            return Locale(identifier: "es_ES")
        case .french:
            return Locale(identifier: "fr_FR")
        case .arabic:
            return Locale(identifier: "ar_SA")
        case .russian:
            return Locale(identifier: "ru_RU")
        case .portuguese:
            return Locale(identifier: "pt_PT")
        case .bengali:
            return Locale(identifier: "bn_BD")
        case .german:
            return Locale(identifier: "de_DE")
        }
    }
}

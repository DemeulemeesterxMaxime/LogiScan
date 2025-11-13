//
//  ScanListError.swift
//  LogiScan
//
//  Created by Assistant on 13/11/2025.
//

import Foundation

/// Erreurs liées aux listes de scan
enum ScanListError: LocalizedError {
    // Erreurs de validation
    case eventNotFinalized
    case noItemsInQuote
    
    // Erreurs de scan
    case assetNotFound
    case assetNotExpected(assetName: String)
    case assetAlreadyScanned(assetName: String)
    case assetNotScanned
    case skuMismatch(expected: String, found: String)
    case itemNotInList
    case quantityExceeded
    
    // Erreurs d'état
    case listNotActive
    case listAlreadyCompleted
    
    var errorDescription: String? {
        switch self {
        case .eventNotFinalized:
            return "❌ L'événement n'est pas finalisé. Veuillez d'abord finaliser le devis."
        case .noItemsInQuote:
            return "❌ Le devis ne contient aucun article."
        case .assetNotFound:
            return "❌ Asset introuvable\n\nVeuillez vérifier le QR code scanné."
        case .assetNotExpected(let name):
            return "❌ '\(name)' n'est pas attendu dans cette liste de scan"
        case .assetAlreadyScanned(let name):
            return "⚠️ '\(name)' a déjà été scanné dans cette liste"
        case .assetNotScanned:
            return "❌ Cet asset n'a pas été scanné"
        case .skuMismatch(let expected, let found):
            return """
⚠️ Mauvais article scanné

Attendu : \(expected)
Scanné : \(found)

💡 Scannez le bon article
"""
        case .itemNotInList:
            return """
❌ Article hors liste

Cet article n'est pas dans la liste de préparation actuelle.

💡 Vérifiez la liste active
"""
        case .quantityExceeded:
            return "✅ Quantité déjà atteinte pour cet article"
        case .listNotActive:
            return "❌ Aucune liste de scan active"
        case .listAlreadyCompleted:
            return "✅ Cette liste est déjà complète"
        }
    }
}

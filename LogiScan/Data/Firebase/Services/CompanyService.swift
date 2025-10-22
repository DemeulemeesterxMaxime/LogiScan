//
//  CompanyService.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import FirebaseFirestore
import FirebaseStorage
import Foundation
import UIKit

final class CompanyService {
    private let db = Firestore.firestore()
    private let storage: Storage
    
    // MARK: - Init
    
    init() {
        // Initialiser Storage avec le bucket correct (nouveau format Firebase)
        storage = Storage.storage(url: "gs://logiscan-cf3fa.firebasestorage.app")
        print("✅ [CompanyService] Storage initialisé avec bucket: logiscan-cf3fa.firebasestorage.app")
    }
    
    // MARK: - Company CRUD
    
    /// Créer une nouvelle entreprise
    func createCompany(_ company: Company) async throws {
        let firestoreCompany = company.toFirestoreCompany()
        
        try db.collection("companies")
            .document(company.companyId)
            .setData(from: firestoreCompany)
        
        print("✅ [CompanyService] Entreprise créée: \(company.name)")
    }
    
    /// Récupérer une entreprise par ID
    func fetchCompany(companyId: String) async throws -> Company {
        let document = try await db.collection("companies")
            .document(companyId)
            .getDocument()
        
        guard let firestoreCompany = try? document.data(as: FirestoreCompany.self) else {
            throw CompanyServiceError.companyNotFound
        }
        
        return firestoreCompany.toSwiftData()
    }
    
    /// Mettre à jour une entreprise
    func updateCompany(_ company: Company) async throws {
        let firestoreCompany = company.toFirestoreCompany()
        
        try db.collection("companies")
            .document(company.companyId)
            .setData(from: firestoreCompany, merge: true)
        
        print("✅ [CompanyService] Entreprise mise à jour: \(company.name)")
    }
    
    /// Supprimer une entreprise
    func deleteCompany(companyId: String) async throws {
        try await db.collection("companies")
            .document(companyId)
            .delete()
        
        print("✅ [CompanyService] Entreprise supprimée: \(companyId)")
    }
    
    // MARK: - Logo Upload
    
    /// Upload le logo de l'entreprise et retourne l'URL
    func uploadLogo(_ image: UIImage, companyId: String) async throws -> String {
        // Compresser l'image en JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw CompanyServiceError.imageCompressionFailed
        }
        
        // Référence vers le fichier dans Storage
        let storageRef = storage.reference()
        let logoPath = "companies/\(companyId)/logo.jpg"
        let logoRef = storageRef.child(logoPath)
        
        // Upload
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            let _ = try await logoRef.putDataAsync(imageData, metadata: metadata)
            
            // Récupérer l'URL de téléchargement
            let downloadURL = try await logoRef.downloadURL()
            
            print("✅ [CompanyService] Logo uploadé: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("❌ [CompanyService] Erreur upload logo: \(error)")
            throw CompanyServiceError.uploadFailed
        }
    }
    
    /// Supprimer le logo de l'entreprise
    func deleteLogo(companyId: String) async throws {
        let storageRef = storage.reference()
        let logoPath = "companies/\(companyId)/logo.jpg"
        let logoRef = storageRef.child(logoPath)
        
        do {
            try await logoRef.delete()
            print("✅ [CompanyService] Logo supprimé")
        } catch {
            print("⚠️ [CompanyService] Erreur suppression logo: \(error)")
            // Ne pas throw l'erreur si le fichier n'existe pas
        }
    }
    
    // MARK: - Errors
    
    enum CompanyServiceError: Error, LocalizedError {
        case companyNotFound
        case imageCompressionFailed
        case uploadFailed
        
        var errorDescription: String? {
            switch self {
            case .companyNotFound:
                return "Entreprise introuvable"
            case .imageCompressionFailed:
                return "Impossible de compresser l'image"
            case .uploadFailed:
                return "Échec de l'upload"
            }
        }
    }
}

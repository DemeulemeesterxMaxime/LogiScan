//
//  AuthService.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import Combine
import FirebaseAuth
import Foundation

/// Service d'authentification Firebase
@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var errorMessage: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        // Écouter les changements d'état d'authentification
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.userEmail = user?.email
            }
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Authentication Methods

    /// Connexion avec email/mot de passe
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ Connexion réussie : \(result.user.email ?? "")")
        } catch {
            errorMessage = "Erreur de connexion : \(error.localizedDescription)"
            throw error
        }
    }

    /// Inscription avec email/mot de passe
    func signUp(email: String, password: String, name: String?) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Mettre à jour le profil avec le nom
            if let name = name {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = name
                try await changeRequest.commitChanges()
            }

            print("✅ Inscription réussie : \(result.user.email ?? "")")
        } catch {
            errorMessage = "Erreur d'inscription : \(error.localizedDescription)"
            throw error
        }
    }

    /// Déconnexion
    func signOut() {
        do {
            try Auth.auth().signOut()
            print("✅ Déconnexion réussie")
        } catch {
            errorMessage = "Erreur de déconnexion : \(error.localizedDescription)"
        }
    }

    /// Réinitialiser le mot de passe
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("✅ Email de réinitialisation envoyé à \(email)")
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
            throw error
        }
    }

    /// Obtenir l'ID utilisateur actuel
    var currentUserId: String? {
        currentUser?.uid
    }

    /// Obtenir le nom d'affichage
    var displayName: String? {
        currentUser?.displayName
    }
}

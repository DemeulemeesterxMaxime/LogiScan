//
//  LoginView.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingSignUp = false
    @State private var showingResetPassword = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient de fond
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    // Logo et titre
                    VStack(spacing: 16) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .shadow(radius: 10)

                        Text("LogiScan")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Gestion d'inventaire intelligente")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    // Formulaire de connexion
                    VStack(spacing: 20) {
                        // Email
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)

                            TextField("Email", text: $email)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)

                        // Mot de passe
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)

                            SecureField("Mot de passe", text: $password)
                                .textFieldStyle(.plain)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)

                        // Mot de passe oublié
                        HStack {
                            Spacer()
                            Button {
                                showingResetPassword = true
                            } label: {
                                Text("Mot de passe oublié ?")
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                        }

                        // Bouton de connexion
                        Button {
                            signIn()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Se connecter")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                        }
                        .disabled(email.isEmpty || password.isEmpty || isLoading)

                        // Bouton d'inscription
                        Button {
                            showingSignUp = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Pas encore de compte ?")
                                    .foregroundColor(.white.opacity(0.9))
                                Text("S'inscrire")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingResetPassword) {
                ResetPasswordView()
                    .environmentObject(authService)
            }
            .alert("Erreur", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.signIn(email: email, password: password)
                
                // Charger l'utilisateur et le définir dans le PermissionService
                guard let userId = authService.currentUserId else {
                    throw LoginError.userIdNotFound
                }
                
                let firebaseService = FirebaseService()
                let user = try await firebaseService.fetchUser(userId: userId)
                
                await MainActor.run {
                    PermissionService.shared.setCurrentUser(user)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    enum LoginError: LocalizedError {
        case userIdNotFound
        
        var errorDescription: String? {
            switch self {
            case .userIdNotFound:
                return "Impossible de récupérer l'ID utilisateur"
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}

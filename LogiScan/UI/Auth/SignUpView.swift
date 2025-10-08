//
//  SignUpView.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // En-tête
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.white)

                            Text("Créer un compte")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("Rejoignez LogiScan")
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 40)

                        // Formulaire
                        VStack(spacing: 16) {
                            // Nom
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("Nom complet", text: $name)
                                    .textFieldStyle(.plain)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)

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

                            // Confirmation mot de passe
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                SecureField("Confirmer le mot de passe", text: $confirmPassword)
                                    .textFieldStyle(.plain)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)

                            // Validation mot de passe
                            if !password.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    PasswordRequirement(
                                        text: "Au moins 6 caractères",
                                        isMet: password.count >= 6
                                    )
                                    PasswordRequirement(
                                        text: "Les mots de passe correspondent",
                                        isMet: !confirmPassword.isEmpty
                                            && password == confirmPassword
                                    )
                                }
                                .padding(.horizontal, 4)
                            }

                            // Bouton d'inscription
                            Button {
                                signUp()
                            } label: {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(
                                                CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("S'inscrire")
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
                            .disabled(!isFormValid || isLoading)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
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

    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 6 && password == confirmPassword
    }

    private func signUp() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.signUp(email: email, password: password, name: name)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct PasswordRequirement: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .white.opacity(0.6))
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthService())
}

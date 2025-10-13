//
//  SignUpView.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import PhotosUI
import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    // Étape 1 : Choix du type de compte
    @State private var accountChoice: AccountChoice? = nil
    
    // Formulaire commun
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // Création d'entreprise
    @State private var companyName = ""
    @State private var companyAddress = ""
    @State private var companyPhone = ""
    @State private var companyEmail = ""
    @State private var companySiret = ""
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var selectedLogoImage: UIImage?
    
    // Rejoindre une entreprise
    @State private var invitationCode = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentStep = 1
    
    enum AccountChoice {
        case createCompany
        case joinCompany
    }

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
                        headerView
                        
                        // Contenu selon l'étape
                        if currentStep == 1 {
                            accountChoiceView
                        } else if currentStep == 2 {
                            userInfoFormView
                        } else if currentStep == 3 {
                            if accountChoice == .createCompany {
                                companyFormView
                            } else {
                                invitationCodeView
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if currentStep > 1 {
                            currentStep -= 1
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: currentStep > 1 ? "chevron.left" : "xmark")
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
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: headerIcon)
                .font(.system(size: 60))
                .foregroundColor(.white)

            Text(headerTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(headerSubtitle)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    private var headerIcon: String {
        switch currentStep {
        case 1: return "person.crop.circle.badge.plus"
        case 2: return "person.fill"
        case 3: return accountChoice == .createCompany ? "building.2.fill" : "envelope.badge.fill"
        default: return "person.crop.circle.badge.plus"
        }
    }
    
    private var headerTitle: String {
        switch currentStep {
        case 1: return "Créer un compte"
        case 2: return "Vos informations"
        case 3: return accountChoice == .createCompany ? "Votre entreprise" : "Code d'invitation"
        default: return "Créer un compte"
        }
    }
    
    private var headerSubtitle: String {
        switch currentStep {
        case 1: return "Choisissez votre type de compte"
        case 2: return "Entrez vos informations personnelles"
        case 3: 
            if accountChoice == .createCompany {
                return "Créez votre entreprise"
            } else {
                return "Entrez le code fourni par votre employeur"
            }
        default: return ""
        }
    }
    
    // MARK: - Step 1: Account Choice
    
    private var accountChoiceView: some View {
        VStack(spacing: 16) {
            // Option 1: Créer une entreprise
            Button {
                accountChoice = .createCompany
                withAnimation {
                    currentStep = 2
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Créer une entreprise")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Vous êtes propriétaire")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(20)
                .background(Color.white.opacity(0.2))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Option 2: Rejoindre une entreprise
            Button {
                accountChoice = .joinCompany
                withAnimation {
                    currentStep = 2
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rejoindre une entreprise")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Vous êtes employé")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(20)
                .background(Color.white.opacity(0.2))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Step 2: User Info Form
    
    private var userInfoFormView: some View {
        VStack(spacing: 16) {
            // Nom
            SignUpFormField(
                icon: "person.fill",
                placeholder: "Nom complet",
                text: $name
            )
            
            // Email
            SignUpFormField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                keyboardType: .emailAddress,
                autocapitalization: .never
            )
            
            // Mot de passe
            SignUpFormField(
                icon: "lock.fill",
                placeholder: "Mot de passe",
                text: $password,
                isSecure: true
            )
            
            // Confirmation mot de passe
            SignUpFormField(
                icon: "lock.fill",
                placeholder: "Confirmer le mot de passe",
                text: $confirmPassword,
                isSecure: true
            )
            
            // Validation mot de passe
            if !password.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    PasswordRequirement(
                        text: "Au moins 6 caractères",
                        isMet: password.count >= 6
                    )
                    PasswordRequirement(
                        text: "Les mots de passe correspondent",
                        isMet: !confirmPassword.isEmpty && password == confirmPassword
                    )
                }
                .padding(.horizontal, 4)
            }
            
            // Bouton suivant
            Button {
                withAnimation {
                    currentStep = 3
                }
            } label: {
                Text("Suivant")
                    .fontWeight(.semibold)
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
            .disabled(!isUserInfoValid)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Step 3A: Company Form
    
    private var companyFormView: some View {
        VStack(spacing: 16) {
            // Logo de l'entreprise
            VStack(spacing: 12) {
                if let logoImage = selectedLogoImage {
                    Image(uiImage: logoImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                
                PhotosPicker(selection: $selectedLogoItem, matching: .images) {
                    Text(selectedLogoImage == nil ? "Ajouter un logo" : "Changer le logo")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                .onChange(of: selectedLogoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedLogoImage = image
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            
            // Nom de l'entreprise
            SignUpFormField(
                icon: "building.2.fill",
                placeholder: "Nom de l'entreprise",
                text: $companyName
            )
            
            // Adresse
            SignUpFormField(
                icon: "map.fill",
                placeholder: "Adresse",
                text: $companyAddress
            )
            
            // Téléphone
            SignUpFormField(
                icon: "phone.fill",
                placeholder: "Téléphone",
                text: $companyPhone,
                keyboardType: .phonePad
            )
            
            // Email entreprise
            SignUpFormField(
                icon: "envelope.fill",
                placeholder: "Email de l'entreprise",
                text: $companyEmail,
                keyboardType: .emailAddress,
                autocapitalization: .never
            )
            
            // SIRET
            SignUpFormField(
                icon: "number",
                placeholder: "SIRET (optionnel)",
                text: $companySiret,
                keyboardType: .numberPad
            )
            
            // Bouton de création
            Button {
                createCompanyAccount()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Créer mon entreprise")
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
            .disabled(!isCompanyFormValid || isLoading)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Step 3B: Invitation Code
    
    private var invitationCodeView: some View {
        VStack(spacing: 16) {
            // Explication
            VStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Demandez le code d'invitation à votre employeur")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 20)
            
            // Code d'invitation
            SignUpFormField(
                icon: "ticket.fill",
                placeholder: "Code d'invitation (ex: ACME-2025-ABC123)",
                text: $invitationCode,
                autocapitalization: .characters
            )
            
            // Format du code
            Text("Format: ENTREPRISE-ANNÉE-CODE")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            // Bouton de validation
            Button {
                joinCompanyWithCode()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Rejoindre l'entreprise")
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
            .disabled(invitationCode.isEmpty || isLoading)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Validation
    
    private var isUserInfoValid: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 6 && password == confirmPassword
    }
    
    private var isCompanyFormValid: Bool {
        !companyName.isEmpty && !companyAddress.isEmpty && !companyPhone.isEmpty && !companyEmail.isEmpty
    }
    
    // MARK: - Actions
    
    private func createCompanyAccount() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Créer le compte Firebase Auth
                try await authService.signUp(email: email, password: password, name: name)
                
                guard let userId = authService.currentUserId else {
                    throw SignUpError.userIdNotFound
                }
                
                // 2. Créer l'entreprise
                let company = Company(
                    name: companyName,
                    address: companyAddress,
                    phone: companyPhone,
                    email: companyEmail,
                    siret: companySiret.isEmpty ? nil : companySiret,
                    ownerId: userId
                )
                
                let companyService = CompanyService()
                try await companyService.createCompany(company)
                
                // 3. Upload du logo si présent
                if let logoImage = selectedLogoImage {
                    let logoURL = try await companyService.uploadLogo(logoImage, companyId: company.companyId)
                    var updatedCompany = company
                    updatedCompany.logoURL = logoURL
                    try await companyService.updateCompany(updatedCompany)
                }
                
                // 4. Créer l'utilisateur LogiScan avec le rôle admin
                let firebaseService = FirebaseService()
                try await firebaseService.createCompanyUser(
                    userId: userId,
                    email: email,
                    displayName: name,
                    company: company
                )
                
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
    
    private func joinCompanyWithCode() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Valider le code d'invitation
                let invitationService = InvitationService()
                let invitation = try await invitationService.validateCode(invitationCode)
                
                // 2. Créer le compte Firebase Auth
                try await authService.signUp(email: email, password: password, name: name)
                
                guard let userId = authService.currentUserId else {
                    throw SignUpError.userIdNotFound
                }
                
                // 3. Créer l'utilisateur LogiScan avec le rôle spécifié
                let firebaseService = FirebaseService()
                try await firebaseService.createEmployeeUser(
                    userId: userId,
                    email: email,
                    displayName: name,
                    companyId: invitation.companyId,
                    role: invitation.role
                )
                
                // 4. Marquer le code comme utilisé
                try await invitationService.useInvitationCode(codeId: invitation.codeId)
                
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
    
    enum SignUpError: LocalizedError {
        case userIdNotFound
        case invalidInvitationCode
        
        var errorDescription: String? {
            switch self {
            case .userIdNotFound:
                return "Impossible de récupérer l'ID utilisateur"
            case .invalidInvitationCode:
                return "Code d'invitation invalide ou expiré"
            }
        }
    }
}

// MARK: - Supporting Views

struct SignUpFormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
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

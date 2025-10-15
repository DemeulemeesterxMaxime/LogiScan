//
//  AdminView.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AdminView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    
    @State private var permissionService = PermissionService.shared
    @State private var firebaseService = FirebaseService()
    @State private var companyService = CompanyService()
    @State private var invitationService = InvitationService()
    
    // État
    @State private var company: Company?
    @State private var members: [User] = []
    @State private var invitationCodes: [InvitationCode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    // Modales
    @State private var showingMemberRoleSheet = false
    @State private var showingGenerateCodeSheet = false
    @State private var showingCompanyEditSheet = false
    @State private var showingTransferOwnershipAlert = false
    @State private var showingRemoveMemberAlert = false
    @State private var showingDeactivateCodeAlert = false
    
    // Sélections
    @State private var selectedMember: User?
    @State private var selectedCode: InvitationCode?
    @State private var newRoleForMember: User.UserRole?
    
    // Formulaire entreprise
    @State private var editCompanyName = ""
    @State private var editCompanyPhone = ""
    @State private var editCompanyAddress = ""
    @State private var editCompanyEmail = ""
    @State private var editCompanySiret = ""
    
    // Upload logo
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var logoImage: UIImage?
    @State private var isUploadingLogo = false
    
    // Génération code
    @State private var newCodeValidityDays = 30
    @State private var newCodeMaxUses = 10
    @State private var newCodeRole: User.UserRole = .standardEmployee

    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Chargement...")
                } else if let company = company {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Section Entreprise
                            companySection(company)
                            
                            // Section Membres
                            membersSection
                            
                            // Section Codes d'Invitation
                            invitationCodesSection
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Aucune entreprise",
                        systemImage: "building.2",
                        description: Text("Impossible de charger les informations de l'entreprise")
                    )
                }
            }
            .navigationTitle("Administration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if permissionService.isAdmin() {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCompanyEditSheet = true
                        } label: {
                            Label("Modifier", systemImage: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingMemberRoleSheet) {
                if let member = selectedMember {
                    changeMemberRoleSheet(member: member)
                }
            }
            .sheet(isPresented: $showingGenerateCodeSheet) {
                generateInvitationCodeSheet
            }
            .sheet(isPresented: $showingCompanyEditSheet) {
                editCompanySheet
            }
            .alert("Transférer la propriété", isPresented: $showingTransferOwnershipAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Confirmer", role: .destructive) {
                    transferOwnership()
                }
            } message: {
                if let member = selectedMember {
                    Text("Êtes-vous sûr de vouloir transférer la propriété de l'entreprise à \(member.displayName) ? Vous deviendrez Manager.")
                }
            }
            .alert("Retirer le membre", isPresented: $showingRemoveMemberAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Retirer", role: .destructive) {
                    removeMember()
                }
            } message: {
                if let member = selectedMember {
                    Text("Êtes-vous sûr de vouloir retirer \(member.displayName) de l'entreprise ?")
                }
            }
            .alert("Désactiver le code", isPresented: $showingDeactivateCodeAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Désactiver", role: .destructive) {
                    deactivateCode()
                }
            } message: {
                if let code = selectedCode {
                    Text("Êtes-vous sûr de vouloir désactiver le code \(code.code) ?")
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
        .overlay(alignment: .top) {
            if let error = errorMessage {
                ErrorBanner(message: error) {
                    errorMessage = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if let success = successMessage {
                SuccessBanner(message: success) {
                    successMessage = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Company Section
    
    @ViewBuilder
    private func companySection(_ company: Company) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("Entreprise")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Logo
                if let logoURL = company.logoURL {
                    AsyncImage(url: URL(string: logoURL)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } placeholder: {
                        ProgressView()
                            .frame(height: 100)
                    }
                }
                
                AdminInfoRow(label: "Nom", value: company.name, icon: "building.2")
                AdminInfoRow(label: "Email", value: company.email, icon: "envelope")
                
                if let phone = company.phone {
                    AdminInfoRow(label: "Téléphone", value: phone, icon: "phone")
                }
                
                if let address = company.address {
                    AdminInfoRow(label: "Adresse", value: address, icon: "mappin.circle")
                }
                
                if let siret = company.siret {
                    AdminInfoRow(label: "SIRET", value: siret, icon: "doc.text")
                }
                
                AdminInfoRow(
                    label: "Créée le",
                    value: company.createdAt.formatted(date: .abbreviated, time: .omitted),
                    icon: "calendar"
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
    }
    
    // MARK: - Members Section
    
    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text("Membres")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(members.count)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(members) { member in
                    MemberRow(
                        member: member,
                        isCurrentUser: member.userId == authService.currentUserId,
                        onChangeRole: {
                            selectedMember = member
                            newRoleForMember = member.role
                            showingMemberRoleSheet = true
                        },
                        onTransferOwnership: {
                            selectedMember = member
                            showingTransferOwnershipAlert = true
                        },
                        onRemove: {
                            selectedMember = member
                            showingRemoveMemberAlert = true
                        }
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
    }
    
    // MARK: - Invitation Codes Section
    
    @ViewBuilder
    private var invitationCodesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ticket.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text("Codes d'Invitation")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if permissionService.isAdmin() {
                    Button {
                        showingGenerateCodeSheet = true
                    } label: {
                        Label("Générer", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }
            }
            
            if invitationCodes.isEmpty {
                ContentUnavailableView(
                    "Aucun code",
                    systemImage: "ticket",
                    description: Text("Générez un code d'invitation pour inviter des employés")
                )
                .frame(height: 200)
            } else {
                VStack(spacing: 8) {
                    ForEach(invitationCodes) { code in
                        InvitationCodeRow(
                            code: code,
                            onDeactivate: {
                                selectedCode = code
                                showingDeactivateCodeAlert = true
                            },
                            onDelete: {
                                deleteCode(code)
                            }
                        )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
        }
    }
    
    // MARK: - Sheets
    
    @ViewBuilder
    private func changeMemberRoleSheet(member: User) -> some View {
        NavigationStack {
            Form {
                Section("Membre") {
                    HStack {
                        Text("Nom")
                        Spacer()
                        Text(member.displayName)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(member.email)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let role = member.role {
                        HStack {
                            Text("Rôle actuel")
                            Spacer()
                            RoleBadge(role: role, size: .small)
                        }
                    }
                }
                
                Section("Nouveau rôle") {
                    Picker("Rôle", selection: Binding(
                        get: { newRoleForMember ?? member.role ?? .standardEmployee },
                        set: { newRoleForMember = $0 }
                    )) {
                        ForEach([User.UserRole.admin, .manager, .standardEmployee, .limitedEmployee], id: \.self) { role in
                            HStack {
                                RoleBadge(role: role, size: .small)
                                Text(role.displayName)
                            }
                            .tag(role)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Text("⚠️ Changer le rôle d'un membre modifiera immédiatement ses permissions dans l'application.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Changer le rôle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        showingMemberRoleSheet = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        changeMemberRole()
                    }
                    .disabled(newRoleForMember == nil || newRoleForMember == member.role)
                }
            }
        }
    }
    
    @ViewBuilder
    private var generateInvitationCodeSheet: some View {
        NavigationStack {
            Form {
                Section("Paramètres du code") {
                    // Sélection du rôle
                    Picker("Rôle attribué", selection: $newCodeRole) {
                        Label("👤 Employé", systemImage: "person")
                            .tag(User.UserRole.standardEmployee)
                        Label("👥 Employé limité", systemImage: "person.crop.circle")
                            .tag(User.UserRole.limitedEmployee)
                        Label("👔 Manager", systemImage: "person.2")
                            .tag(User.UserRole.manager)
                        Label("⚙️ Admin", systemImage: "star")
                            .tag(User.UserRole.admin)
                    }
                    .pickerStyle(.menu)
                    
                    Stepper("Validité: \(newCodeValidityDays) jours", value: $newCodeValidityDays, in: 1...365)
                    
                    Stepper("Utilisations max: \(newCodeMaxUses)", value: $newCodeMaxUses, in: 1...100)
                }
                
                Section("Permissions du rôle") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ce code donnera le rôle: **\(roleDisplayName(newCodeRole))**")
                            .font(.subheadline)
                        
                        Text("Permissions incluses:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        
                        ForEach(rolePermissions(newCodeRole), id: \.self) { permission in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text(permissionDisplayName(permission))
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section {
                    Text("Le code sera automatiquement généré au format: \(company?.name.uppercased() ?? "COMPANY")-2025-XXXX")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("Le code expirera dans \(newCodeValidityDays) jours et pourra être utilisé \(newCodeMaxUses) fois maximum.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Générer un code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        showingGenerateCodeSheet = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Générer") {
                        generateInvitationCode()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var editCompanySheet: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom", text: $editCompanyName)
                    TextField("Email", text: $editCompanyEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Téléphone", text: $editCompanyPhone)
                        .keyboardType(.phonePad)
                    TextField("Adresse", text: $editCompanyAddress, axis: .vertical)
                        .lineLimit(3...5)
                    TextField("SIRET", text: $editCompanySiret)
                        .keyboardType(.numberPad)
                }
                
                Section("Logo") {
                    PhotosPicker(selection: $selectedLogoItem, matching: .images) {
                        HStack {
                            if let logoImage = logoImage {
                                Image(uiImage: logoImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else if let logoURL = company?.logoURL {
                                AsyncImage(url: URL(string: logoURL)) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } placeholder: {
                                    ProgressView()
                                }
                            }
                            
                            Spacer()
                            
                            Text("Choisir une image")
                                .foregroundStyle(.blue)
                        }
                    }
                    .onChange(of: selectedLogoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                logoImage = image
                            }
                        }
                    }
                    
                    if logoImage != nil || company?.logoURL != nil {
                        Button(role: .destructive) {
                            logoImage = nil
                            selectedLogoItem = nil
                        } label: {
                            Text("Supprimer le logo")
                        }
                    }
                    
                    if isUploadingLogo {
                        HStack {
                            ProgressView()
                            Text("Upload en cours...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Modifier l'entreprise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        showingCompanyEditSheet = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveCompanyChanges()
                    }
                    .disabled(isUploadingLogo)
                }
            }
        }
        .onAppear {
            if let company = company {
                editCompanyName = company.name
                editCompanyEmail = company.email
                editCompanyPhone = company.phone ?? ""
                editCompanyAddress = company.address ?? ""
                editCompanySiret = company.siret ?? ""
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Charger l'utilisateur courant
            guard let userId = authService.currentUserId else {
                throw AdminError.notAuthenticated
            }
            
            let currentUser = try await firebaseService.fetchUser(userId: userId)
            permissionService.setCurrentUser(currentUser)
            
            // Charger l'entreprise
            guard let companyId = currentUser.companyId else {
                throw AdminError.noCompanyFound
            }
            
            company = try await companyService.fetchCompany(companyId: companyId)
            
            // Charger les membres
            members = try await firebaseService.fetchCompanyMembers(companyId: companyId)
            
            // Charger les codes d'invitation (si Admin ou Manager)
            if permissionService.isManagerOrAbove() {
                invitationCodes = try await invitationService.fetchInvitationCodes(companyId: companyId)
            }
            
        } catch {
            errorMessage = "Erreur de chargement: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Actions
    
    private func changeMemberRole() {
        guard let member = selectedMember,
              let newRole = newRoleForMember else { return }
        
        Task {
            do {
                try await firebaseService.updateUserRole(userId: member.userId, newRole: newRole)
                successMessage = "Rôle de \(member.displayName) modifié avec succès"
                showingMemberRoleSheet = false
                await loadData()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    private func transferOwnership() {
        guard let newOwner = selectedMember,
              let currentUserId = authService.currentUserId,
              let companyId = company?.companyId else { return }
        
        Task {
            do {
                try await firebaseService.transferAdminRole(
                    fromUserId: currentUserId,
                    toUserId: newOwner.userId,
                    companyId: companyId
                )
                successMessage = "Propriété transférée à \(newOwner.displayName)"
                await loadData()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    private func removeMember() {
        guard let member = selectedMember else { return }
        
        Task {
            do {
                try await firebaseService.removeUserFromCompany(userId: member.userId)
                successMessage = "\(member.displayName) a été retiré de l'entreprise"
                await loadData()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    private func generateInvitationCode() {
        guard let companyId = company?.companyId,
              let createdBy = authService.currentUserId else { return }
        
        Task {
            do {
                let code = try await invitationService.generateInvitationCode(
                    companyId: companyId,
                    companyName: company?.name ?? "COMPANY",
                    role: newCodeRole,  // Utilise le rôle sélectionné
                    createdBy: createdBy,
                    validityDays: newCodeValidityDays,
                    maxUses: newCodeMaxUses
                )
                successMessage = "Code généré: \(code.code)"
                showingGenerateCodeSheet = false
                await loadData()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    private func deactivateCode() {
        guard let code = selectedCode else { return }
        
        Task {
            do {
                try await invitationService.deactivateCode(codeId: code.codeId)
                successMessage = "Code \(code.code) désactivé"
                await loadData()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    private func deleteCode(_ code: InvitationCode) {
        Task {
            do {
                try await invitationService.deleteCode(codeId: code.codeId)
                successMessage = "Code \(code.code) supprimé"
                await loadData()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveCompanyChanges() {
        guard let company = company else { return }
        
        Task {
            isUploadingLogo = true
            defer { isUploadingLogo = false }
            
            do {
                // Upload logo si nécessaire
                var logoURL = company.logoURL
                if let image = logoImage {
                    logoURL = try await companyService.uploadLogo(image, companyId: company.companyId)
                } else if logoImage == nil && company.logoURL != nil {
                    // Supprimer le logo
                    try await companyService.deleteLogo(companyId: company.companyId)
                    logoURL = nil
                }
                
                // Mettre à jour l'entreprise
                let updatedCompany = Company(
                    companyId: company.companyId,
                    name: editCompanyName,
                    logoURL: logoURL,
                    address: editCompanyAddress.isEmpty ? nil : editCompanyAddress,
                    phone: editCompanyPhone.isEmpty ? nil : editCompanyPhone,
                    email: editCompanyEmail,
                    siret: editCompanySiret.isEmpty ? nil : editCompanySiret,
                    createdAt: company.createdAt,
                    ownerId: company.ownerId
                )
                
                try await companyService.updateCompany(updatedCompany)
                self.company = updatedCompany
                successMessage = "Entreprise mise à jour"
                showingCompanyEditSheet = false
                
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Supporting Views

struct AdminInfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
    }
}

struct MemberRow: View {
    let member: User
    let isCurrentUser: Bool
    let onChangeRole: () -> Void
    let onTransferOwnership: () -> Void
    let onRemove: () -> Void
    
    @State private var permissionService = PermissionService.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.displayName)
                        .font(.headline)
                    
                    if isCurrentUser {
                        Text("(Vous)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(member.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let role = member.role {
                    RoleBadge(role: role, size: .small)
                }
            }
            
            Spacer()
            
            if permissionService.isAdmin() && !isCurrentUser {
                Menu {
                    Button {
                        onChangeRole()
                    } label: {
                        Label("Changer le rôle", systemImage: "person.badge.key")
                    }
                    
                    if member.role != .admin {
                        Button {
                            onTransferOwnership()
                        } label: {
                            Label("Transférer la propriété", systemImage: "crown")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Retirer", systemImage: "person.crop.circle.badge.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct InvitationCodeRow: View {
    let code: InvitationCode
    let onDeactivate: () -> Void
    let onDelete: () -> Void
    
    @State private var permissionService = PermissionService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(code.code)
                    .font(.headline)
                    .fontWeight(.bold)
                    .monospaced()
                
                Spacer()
                
                if code.isActive {
                    if code.isValid {
                        Label("Actif", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Expiré", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Label("Inactif", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            
            HStack {
                Text("Expire: \(code.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Utilisé: \(code.usedCount)/\(code.maxUses)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if code.isActive && permissionService.isAdmin() {
                HStack {
                    Button(role: .destructive) {
                        onDeactivate()
                    } label: {
                        Label("Désactiver", systemImage: "xmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
            }
            
            if !code.isActive && permissionService.isAdmin() {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Supprimer", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.subheadline)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .padding()
        .background(Color.red)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
        .shadow(radius: 5)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    onDismiss()
                }
            }
        }
    }
}

struct SuccessBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
            Text(message)
                .font(.subheadline)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .padding()
        .background(Color.green)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
        .shadow(radius: 5)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Errors

enum AdminError: Error, LocalizedError {
    case notAuthenticated
    case noCompanyFound
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Vous devez être connecté"
        case .noCompanyFound:
            return "Aucune entreprise trouvée"
        case .notAuthorized:
            return "Vous n'avez pas les permissions nécessaires"
        }
    }
}

// MARK: - Helper Functions Extension

extension AdminView {
    private func roleDisplayName(_ role: User.UserRole) -> String {
        switch role {
        case .admin:
            return "Administrateur"
        case .manager:
            return "Manager"
        case .standardEmployee:
            return "Employé Standard"
        case .limitedEmployee:
            return "Employé Limité"
        }
    }
    
    private func rolePermissions(_ role: User.UserRole) -> [String] {
        switch role {
        case .admin:
            return [
                "Gestion complète de l'entreprise",
                "Gestion des membres et permissions",
                "Création et gestion des codes d'invitation",
                "Gestion des événements et devis",
                "Gestion du stock et des camions",
                "Accès au scanner et inventaire",
                "Accès aux rapports et statistiques"
            ]
        case .manager:
            return [
                "Gestion des événements et devis",
                "Gestion du stock et des camions",
                "Accès au scanner et inventaire",
                "Accès aux rapports",
                "Validation des mouvements"
            ]
        case .standardEmployee:
            return [
                "Accès au scanner",
                "Consultation du stock",
                "Consultation des événements",
                "Mouvements de base"
            ]
        case .limitedEmployee:
            return [
                "Accès au scanner",
                "Consultation du stock (limitée)"
            ]
        }
    }
    
    private func permissionDisplayName(_ permission: String) -> String {
        return permission
    }
}

// MARK: - Preview

#Preview {
    AdminView()
        .environmentObject(AuthService())
}

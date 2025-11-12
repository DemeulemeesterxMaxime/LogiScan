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
    @State private var archivedCodes: [InvitationCode] = []  // Nouveau
    @State private var showArchivedCodes = false  // Nouveau
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
    @State private var editCompanyLanguage: AppLanguage = .french
    
    // Upload logo
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var logoImage: UIImage?
    @State private var isUploadingLogo = false
    
        // Génération de code
    @State private var newCodeValidityDays = 30
    @State private var newCodeMaxUses = 10
    @State private var newCodeRole: User.UserRole = .standardEmployee
    @State private var newCodeCustomName = ""
    @State private var newCodeCustomCode = ""  // Nouveau : code personnalisé
    @State private var useCustomCode = false  // Toggle pour activer la personnalisation

    
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
                            
                            // Section Gestion des Tâches (Manager et Admin)
                            if permissionService.checkPermission(.writeTasks) || permissionService.checkPermission(.manageTasks) {
                                taskManagementSection
                            }
                            
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
                
                // Affichage de la langue
                HStack(alignment: .top) {
                    Image(systemName: "globe")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Langue")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text(AppLanguage(rawValue: company.language)?.flag ?? "🌍")
                            Text(AppLanguage(rawValue: company.language)?.displayName ?? company.language)
                                .font(.body)
                        }
                    }
                    
                    Spacer()
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
    
    // MARK: - Task Management Section
    
    @ViewBuilder
    private var taskManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("Gestion des Tâches")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Créer une tâche
                if permissionService.checkPermission(.writeTasks) {
                    NavigationLink {
                        CreateTaskView()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Créer une tâche")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Ajouter une nouvelle tâche à l'équipe")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                }
                
                // Gérer toutes les tâches
                if permissionService.checkPermission(.manageTasks) {
                    NavigationLink {
                        // TODO: AdminTaskManagementView (Phase 4)
                        Text("Gérer toutes les tâches - À IMPLÉMENTER")
                            .navigationTitle("Gestion des tâches")
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.clipboard.fill")
                                .font(.title3)
                                .foregroundStyle(.purple)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gérer toutes les tâches")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Vue d'ensemble de toutes les tâches")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.purple.opacity(0.1))
                        )
                    }
                }
                
                // Attribuer des tâches
                if permissionService.checkPermission(.assignTasks) {
                    NavigationLink {
                        // TODO: TaskAssignmentView (Phase 4)
                        Text("Attribuer des tâches - À IMPLÉMENTER")
                            .navigationTitle("Attribution de tâches")
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Attribuer des tâches")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Assigner des tâches aux membres")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
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
                    "Aucun code actif",
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
                            },
                            onArchive: {
                                archiveCode(code)
                            },
                            onUnarchive: {
                                unarchiveCode(code)
                            }
                        )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            
            // Section codes archivés
            if !archivedCodes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation {
                            showArchivedCodes.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: showArchivedCodes ? "chevron.down" : "chevron.right")
                                .font(.caption)
                            Text("Codes archivés (\(archivedCodes.count))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    if showArchivedCodes {
                        VStack(spacing: 8) {
                            ForEach(archivedCodes) { code in
                                InvitationCodeRow(
                                    code: code,
                                    onDeactivate: { },
                                    onDelete: {
                                        deleteCode(code)
                                    },
                                    onArchive: nil,
                                    onUnarchive: {
                                        unarchiveCode(code)
                                    }
                                )
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
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
                Section("Informations") {
                    TextField("Nom du code (optionnel)", text: $newCodeCustomName)
                        .textInputAutocapitalization(.words)
                    
                    Text("Ex: 'Équipe Livraison', 'Nouveaux Stagiaires', etc.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Code d'invitation") {
                    Toggle("Personnaliser le code", isOn: $useCustomCode)
                    
                    if useCustomCode {
                        TextField("Code personnalisé", text: $newCodeCustomCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: newCodeCustomCode) { _, newValue in
                                // Formater en majuscules et enlever espaces
                                newCodeCustomCode = newValue
                                    .uppercased()
                                    .replacingOccurrences(of: " ", with: "-")
                            }
                        
                        Text("Ex: 'LIVRAISON-2025', 'TEAM-A', etc.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !newCodeCustomCode.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                                Text("Aperçu: \(newCodeCustomCode)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .monospaced()
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.purple)
                            Text("Code généré automatiquement")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let companyName = company?.name {
                            Text("Format: \(generatePreviewCode(companyName: companyName))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .monospaced()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
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
                    if useCustomCode {
                        Text("⚠️ Assurez-vous que le code personnalisé est unique et facile à partager.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
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
                    .disabled(useCustomCode && newCodeCustomCode.isEmpty)
                }
            }
        }
        .onAppear {
            // Reset form
            newCodeCustomName = ""
            newCodeCustomCode = ""
            useCustomCode = false
            newCodeRole = .standardEmployee
            newCodeValidityDays = 30
            newCodeMaxUses = 10
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
                    
                    Picker("Langue", selection: $editCompanyLanguage) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            HStack {
                                Text(language.flag)
                                Text(language.displayName)
                            }
                            .tag(language)
                        }
                    }
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
                editCompanyLanguage = AppLanguage(rawValue: company.language) ?? .french
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
                invitationCodes = try await invitationService.fetchInvitationCodes(companyId: companyId, includeArchived: false)
                archivedCodes = try await invitationService.fetchArchivedCodes(companyId: companyId)
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
                let customName = newCodeCustomName.isEmpty ? nil : newCodeCustomName
                let customCode = (useCustomCode && !newCodeCustomCode.isEmpty) ? newCodeCustomCode : nil
                
                let code = try await invitationService.generateInvitationCode(
                    companyId: companyId,
                    companyName: company?.name ?? "COMPANY",
                    customCode: customCode,  // Code personnalisé
                    customName: customName,  // Nom personnalisé
                    role: newCodeRole,
                    createdBy: createdBy,
                    validityDays: newCodeValidityDays,
                    maxUses: newCodeMaxUses
                )
                
                // Copier le code dans le presse-papier
                await MainActor.run {
                    UIPasteboard.general.string = code.code
                }
                
                if let customName = customName {
                    successMessage = "Code '\(customName)' généré et copié: \(code.code)"
                } else {
                    successMessage = "Code généré et copié: \(code.code)"
                }
                
                showingGenerateCodeSheet = false
                await loadData()
            } catch let error as InvitationService.InvitationError {
                errorMessage = error.localizedDescription
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
                successMessage = "Code \(code.displayName) supprimé"
                await loadData()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    private func archiveCode(_ code: InvitationCode) {
        Task {
            do {
                try await invitationService.archiveCode(codeId: code.codeId)
                successMessage = "Code \(code.displayName) archivé"
                await loadData()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
    
    private func unarchiveCode(_ code: InvitationCode) {
        Task {
            do {
                try await invitationService.unarchiveCode(codeId: code.codeId)
                successMessage = "Code \(code.displayName) restauré"
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
                    ownerId: company.ownerId,
                    language: editCompanyLanguage.rawValue
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
    let onArchive: (() -> Void)?
    let onUnarchive: (() -> Void)?
    
    @State private var permissionService = PermissionService.shared
    @State private var showingEditNameSheet = false
    @State private var editedName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête avec nom/code et statut
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let customName = code.customName, !customName.isEmpty {
                        Text(customName)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(code.code)
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    } else {
                        Text(code.code)
                            .font(.headline)
                            .fontWeight(.bold)
                            .monospaced()
                    }
                    
                    // Badge du rôle
                    HStack(spacing: 4) {
                        Image(systemName: roleIcon(code.role))
                            .font(.caption2)
                        Text(code.role.displayName)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // Statut
                statusBadge
            }
            
            // Informations
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Expire: \(code.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "person.2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(code.usedCount)/\(code.maxUses)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Barre de progression
                    ProgressView(value: Double(code.usedCount), total: Double(code.maxUses))
                        .frame(width: 40)
                        .tint(progressColor)
                }
            }
            
            // Actions
            if permissionService.isAdmin() {
                HStack(spacing: 8) {
                    if code.isArchived {
                        // Code archivé - option de restauration
                        if let onUnarchive = onUnarchive {
                            Button {
                                onUnarchive()
                            } label: {
                                Label("Restaurer", systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                    } else if code.isActive {
                        // Code actif - options complètes
                        Button {
                            editedName = code.customName ?? ""
                            showingEditNameSheet = true
                        } label: {
                            Label("Renommer", systemImage: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        if let onArchive = onArchive {
                            Button {
                                onArchive()
                            } label: {
                                Label("Archiver", systemImage: "archivebox")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                        
                        Button(role: .destructive) {
                            onDeactivate()
                        } label: {
                            Label("Désactiver", systemImage: "xmark.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        // Code inactif - suppression
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(code.isArchived ? Color(.systemGray6) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .sheet(isPresented: $showingEditNameSheet) {
            editNameSheet
        }
    }
    
    private var statusBadge: some View {
        let status = code.status
        return HStack(spacing: 4) {
            Image(systemName: statusIcon(status))
                .font(.caption2)
            Text(status.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor(status).opacity(0.2))
        .foregroundStyle(statusColor(status))
        .clipShape(Capsule())
    }
    
    private var progressColor: Color {
        let ratio = Double(code.usedCount) / Double(code.maxUses)
        if ratio >= 1.0 { return .red }
        if ratio >= 0.75 { return .orange }
        return .green
    }
    
    private var borderColor: Color {
        if code.isArchived { return Color.gray.opacity(0.3) }
        if !code.isActive { return Color.red.opacity(0.3) }
        if !code.isValid { return Color.orange.opacity(0.3) }
        return Color.green.opacity(0.3)
    }
    
    private func statusColor(_ status: InvitationCode.CodeStatus) -> Color {
        switch status {
        case .active: return .green
        case .inactive: return .red
        case .expired: return .orange
        case .exhausted: return .gray
        case .archived: return .gray
        }
    }
    
    private func statusIcon(_ status: InvitationCode.CodeStatus) -> String {
        switch status {
        case .active: return "checkmark.circle.fill"
        case .inactive: return "xmark.circle.fill"
        case .expired: return "clock.badge.exclamationmark"
        case .exhausted: return "circle.slash"
        case .archived: return "archivebox.fill"
        }
    }
    
    private func roleIcon(_ role: User.UserRole) -> String {
        switch role {
        case .admin: return "star.fill"
        case .manager: return "person.2.fill"
        case .standardEmployee: return "person.fill"
        case .limitedEmployee: return "person.crop.circle"
        }
    }
    
    private var editNameSheet: some View {
        NavigationStack {
            Form {
                Section("Nom du code") {
                    TextField("Nom personnalisé", text: $editedName)
                        .textInputAutocapitalization(.words)
                    
                    Text("Laissez vide pour utiliser le code comme nom")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    Text("Code: \(code.code)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Modifier le nom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        showingEditNameSheet = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task {
                            let service = InvitationService()
                            try? await service.updateCodeName(
                                codeId: code.codeId,
                                newName: editedName.isEmpty ? nil : editedName
                            )
                            showingEditNameSheet = false
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
    
    private func generatePreviewCode(companyName: String) -> String {
        let prefix = companyName
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
            .prefix(8)
        let year = Calendar.current.component(.year, from: Date())
        return "\(prefix)-\(year)-XXXX"
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

//
//  SettingsView.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import SwiftUI
import SwiftData
import PhotosUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @Query private var stockItems: [StockItem]
    @Query private var events: [Event]
    @Query private var trucks: [Truck]
    
    @State private var permissionService = PermissionService.shared
    @State private var companyService = CompanyService()
    @State private var firebaseService = FirebaseService()
    @State private var invitationService = InvitationService()
    
    @State private var company: Company?
    @State private var members: [User] = []
    @State private var invitationCodes: [InvitationCode] = []
    @State private var isLoading = true
    @State private var showingLogoutConfirm = false
    @State private var showingDeleteDataConfirm = false
    @State private var selectedDeleteType: DeleteType?
    @State private var isEditingCompany = false
    @State private var errorMessage: String?
    @State private var showingNewCodeSheet = false
    
    // Formulaire entreprise
    @State private var editCompanyName = ""
    @State private var editCompanyEmail = ""
    @State private var editCompanyPhone = ""
    @State private var editCompanyAddress = ""
    @State private var editCompanySiret = ""
    @State private var editCompanyLanguage: AppLanguage = .french
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var logoImage: UIImage?
    @State private var isUploadingLogo = false
    @State private var isSavingCompany = false
    
    // FocusState pour gérer le clavier
    @FocusState private var focusedField: CompanyField?
    
    enum CompanyField: Hashable {
        case name, email, phone, address, siret
    }
    
    enum DeleteType: String {
        case trucks, stock, events, all
        
        var title: String {
            switch self {
            case .trucks: return "Supprimer tous les camions"
            case .stock: return "Supprimer tout le stock"
            case .events: return "Supprimer tous les événements"
            case .all: return "Supprimer toutes les données"
            }
        }
    }
    
    var currentUser: User? {
        permissionService.currentUser
    }
    
    var body: some View {
        List {
            // Section Profil
            profileSection
            
            // Section Entreprise
            if currentUser?.companyId != nil {
                if isLoading {
                    loadingSection
                } else if let company = company {
                    companySection(company: company)
                    membersSection
                    
                    // Section Admin
                    if permissionService.isAdmin() {
                        invitationSection
                    }
                }
            }
            
            // Section Gestion des données
            dataManagementSection
            
            // Section Actions
            actionsSection
        }
        .navigationTitle("Paramètres")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadData()
        }
        .onAppear {
            Task {
                await loadData()
            }
        }
        .alert("Déconnexion", isPresented: $showingLogoutConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Se déconnecter", role: .destructive) {
                logout()
            }
        } message: {
            Text("Voulez-vous vraiment vous déconnecter ?")
        }
        .alert(selectedDeleteType?.title ?? "Supprimer", isPresented: $showingDeleteDataConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                if let type = selectedDeleteType {
                    deleteData(type: type)
                }
            }
        } message: {
            Text("Cette action est irréversible. Toutes les données seront supprimées.")
        }
        .sheet(isPresented: $showingNewCodeSheet) {
            if let companyId = company?.companyId {
                GenerateInvitationView(companyId: companyId) {
                    Task { await loadData() }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(initials)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentUser?.displayName ?? "Utilisateur")
                        .font(.headline)
                    Text(currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            
            if let user = currentUser {
                HStack {
                    Label("Rôle", systemImage: "person.badge.key")
                    Spacer()
                    if let role = user.role {
                        RoleBadge(role: role)
                    }
                }
            }
        } header: {
            Text("Mon Profil")
        }
    }
    
    private var loadingSection: some View {
        Section {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
    }
    
    private func companySection(company: Company) -> some View {
        Section(header: Text("Mon Entreprise")) {
            if !isEditingCompany {
                companyReadOnlyView(company: company)
            } else {
                companyEditView(company: company)
            }
        }
    }
    
    @ViewBuilder
    private func companyReadOnlyView(company: Company) -> some View {
        // Mode lecture
        if let logoURL = company.logoURL {
            AsyncImage(url: URL(string: logoURL)) { image in
                image.resizable().scaledToFit().frame(height: 80)
            } placeholder: {
                ProgressView()
            }
        }
        
        SettingsInfoRow(label: "Nom", value: editCompanyName.isEmpty ? company.name : editCompanyName, icon: "building.2")
        SettingsInfoRow(label: "Email", value: editCompanyEmail.isEmpty ? company.email : editCompanyEmail, icon: "envelope")
        
        if let phone = company.phone {
            SettingsInfoRow(label: "Téléphone", value: phone, icon: "phone")
        }
        if let address = company.address {
            SettingsInfoRow(label: "Adresse", value: address, icon: "mappin")
        }
        if let siret = company.siret {
            SettingsInfoRow(label: "SIRET", value: siret, icon: "doc.text")
        }
        
        // Affichage de la langue
        HStack {
            Label("Langue", systemImage: "globe")
            Spacer()
            HStack(spacing: 6) {
                Text(AppLanguage(rawValue: company.language)?.flag ?? "🌍")
                Text(AppLanguage(rawValue: company.language)?.displayName ?? company.language)
            }
            .foregroundColor(.secondary)
        }
        
        if permissionService.checkPermission(.editCompany) {
            Button(action: { 
                startEditing(company: company)
            }) {
                Label("Modifier", systemImage: "pencil")
            }
        }
    }
    
    @ViewBuilder
    private func companyEditView(company: Company) -> some View {
        // Mode édition
        PhotosPicker(selection: $selectedLogoItem, matching: .images) {
            if let logoImage = logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
            } else {
                Label("Changer le logo", systemImage: "photo")
            }
        }
        .onChange(of: selectedLogoItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    logoImage = uiImage
                }
            }
        }
        
        // TextFields avec IDs stables et FocusState
        TextField("Nom de l'entreprise", text: $editCompanyName)
            .id("companyName")
            .focused($focusedField, equals: .name)
            .textContentType(.organizationName)
            .submitLabel(.next)
            .onSubmit { focusedField = .email }
        
        TextField("Email", text: $editCompanyEmail)
            .id("companyEmail")
            .focused($focusedField, equals: .email)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .textContentType(.emailAddress)
            .submitLabel(.next)
            .onSubmit { focusedField = .phone }
        
        TextField("Téléphone", text: $editCompanyPhone)
            .id("companyPhone")
            .focused($focusedField, equals: .phone)
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
        
        TextField("Adresse", text: $editCompanyAddress)
            .id("companyAddress")
            .focused($focusedField, equals: .address)
            .textContentType(.fullStreetAddress)
            .submitLabel(.next)
            .onSubmit { focusedField = .siret }
        
        TextField("SIRET", text: $editCompanySiret)
            .id("companySiret")
            .focused($focusedField, equals: .siret)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }
        
        // Picker de langue
        Picker("Langue", selection: $editCompanyLanguage) {
            ForEach(AppLanguage.allCases, id: \.self) { language in
                HStack {
                    Text(language.flag)
                    Text(language.displayName)
                }
                .tag(language)
            }
        }
        .pickerStyle(.menu)
        
        Button(action: { 
            focusedField = nil // Fermer le clavier
            Task { await saveCompany() }
        }) {
            HStack {
                if isSavingCompany {
                    ProgressView()
                }
                Label(isSavingCompany ? "Enregistrement..." : "Enregistrer", systemImage: "checkmark.circle.fill")
            }
        }
        .disabled(isSavingCompany || editCompanyName.isEmpty || editCompanyEmail.isEmpty)
        
        Button("Annuler", role: .cancel) {
            focusedField = nil // Fermer le clavier
            isEditingCompany = false
        }
    }
    
    private var membersSection: some View {
        Section {
            ForEach(members, id: \.userId) { member in
                NavigationLink {
                    MemberDetailView(member: member, companyOwnerId: company?.ownerId ?? "")
                        .onDisappear {
                            Task { await loadData() }
                        }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(LinearGradient(colors: [.blue.opacity(0.6), .cyan.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(memberInitials(member.displayName))
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(member.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if member.userId == company?.ownerId {
                                    Image(systemName: "crown.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                            }
                            Text(member.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let role = member.role {
                            RoleBadge(role: role)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Membres")
                Spacer()
                Text("\(members.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var invitationSection: some View {
        Section {
            ForEach(invitationCodes, id: \.codeId) { code in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let customName = code.customName {
                                Text(customName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Text(code.code)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        if code.isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        Text("\(code.usedCount)/\(code.maxUses) utilisations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(roleDisplayName(code.role))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteCode(code)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                    
                    if code.isActive {
                        Button {
                            deactivateCode(code)
                        } label: {
                            Label("Désactiver", systemImage: "pause.circle")
                        }
                        .tint(.orange)
                    } else {
                        Button {
                            activateCode(code)
                        } label: {
                            Label("Activer", systemImage: "play.circle")
                        }
                        .tint(.green)
                    }
                }
            }
            
            Button(action: { showingNewCodeSheet = true }) {
                Label("Générer un code", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Codes d'invitation")
        }
    }
    
    private var dataManagementSection: some View {
        Section {
            Button(role: .destructive) {
                selectedDeleteType = .trucks
                showingDeleteDataConfirm = true
            } label: {
                Label("Supprimer tous les camions (\(trucks.count))", systemImage: "trash")
            }
            
            Button(role: .destructive) {
                selectedDeleteType = .stock
                showingDeleteDataConfirm = true
            } label: {
                Label("Supprimer tout le stock (\(stockItems.count))", systemImage: "trash")
            }
            
            Button(role: .destructive) {
                selectedDeleteType = .events
                showingDeleteDataConfirm = true
            } label: {
                Label("Supprimer tous les événements (\(events.count))", systemImage: "trash")
            }
            
            Button(role: .destructive) {
                selectedDeleteType = .all
                showingDeleteDataConfirm = true
            } label: {
                Label("Supprimer toutes les données", systemImage: "trash.fill")
            }
        } header: {
            Text("Gestion des données")
        } footer: {
            Text("Actions irréversibles. Utilisez avec précaution.")
        }
    }
    
    private var actionsSection: some View {
        Section {
            Button(action: { showingLogoutConfirm = true }) {
                Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Actions
    
    private func startEditing(company: Company) {
        editCompanyName = company.name
        editCompanyEmail = company.email
        editCompanyPhone = company.phone ?? ""
        editCompanyAddress = company.address ?? ""
        editCompanySiret = company.siret ?? ""
        editCompanyLanguage = AppLanguage(rawValue: company.language) ?? .french
        isEditingCompany = true
    }
    
    private func saveCompany() async {
        guard let company = company else { return }
        
        // Capturer les valeurs localement avant toute modification d'état
        let name = editCompanyName
        let email = editCompanyEmail
        let phone = editCompanyPhone
        let address = editCompanyAddress
        let siret = editCompanySiret
        let language = editCompanyLanguage
        let logoToUpload = logoImage
        
        // Mettre à jour l'état UI une seule fois au début
        await MainActor.run {
            isSavingCompany = true
        }
        
        do {
            var updatedCompany = Company(
                companyId: company.companyId,
                name: name,
                logoURL: company.logoURL,
                address: address.isEmpty ? nil : address,
                phone: phone.isEmpty ? nil : phone,
                email: email,
                siret: siret.isEmpty ? nil : siret,
                createdAt: company.createdAt,
                ownerId: company.ownerId,
                language: language.rawValue
            )
            
            // Upload logo si modifié
            if let logoToUpload = logoToUpload {
                let logoURL = try await companyService.uploadLogo(logoToUpload, companyId: company.companyId)
                updatedCompany = Company(
                    companyId: updatedCompany.companyId,
                    name: updatedCompany.name,
                    logoURL: logoURL,
                    address: updatedCompany.address,
                    phone: updatedCompany.phone,
                    email: updatedCompany.email,
                    siret: updatedCompany.siret,
                    createdAt: updatedCompany.createdAt,
                    ownerId: updatedCompany.ownerId,
                    language: updatedCompany.language
                )
            }
            
            try await companyService.updateCompany(updatedCompany)
            
            // Mettre à jour tous les états UI en une seule fois à la fin
            await MainActor.run {
                self.company = updatedCompany
                self.logoImage = nil
                self.selectedLogoItem = nil
                self.isSavingCompany = false
                self.isEditingCompany = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSavingCompany = false
            }
        }
    }
    
    private func deleteData(type: DeleteType) {
        Task {
            do {
                switch type {
                case .trucks:
                    for truck in trucks {
                        modelContext.delete(truck)
                    }
                case .stock:
                    for item in stockItems {
                        modelContext.delete(item)
                    }
                case .events:
                    for event in events {
                        modelContext.delete(event)
                    }
                case .all:
                    for truck in trucks {
                        modelContext.delete(truck)
                    }
                    for item in stockItems {
                        modelContext.delete(item)
                    }
                    for event in events {
                        modelContext.delete(event)
                    }
                }
                
                try modelContext.save()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        
        do {
            guard let companyId = currentUser?.companyId else {
                isLoading = false
                return
            }
            
            let loadedCompany = try await companyService.fetchCompany(companyId: companyId)
            let loadedMembers = try await firebaseService.fetchCompanyMembers(companyId: companyId)
            
            var loadedCodes: [InvitationCode] = []
            if permissionService.isAdmin() {
                loadedCodes = try await invitationService.fetchInvitationCodes(companyId: companyId)
            }
            
            await MainActor.run {
                self.company = loadedCompany
                self.members = loadedMembers
                self.invitationCodes = loadedCodes
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func logout() {
        Task {
            try? await authService.signOut()
            permissionService.clearCurrentUser()
        }
    }
    
    private func deactivateCode(_ code: InvitationCode) {
        Task {
            do {
                try await invitationService.deactivateCode(codeId: code.codeId)
                await loadData()
            } catch {
                await MainActor.run {
                    errorMessage = "Erreur lors de la désactivation: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func activateCode(_ code: InvitationCode) {
        Task {
            do {
                try await invitationService.activateCode(codeId: code.codeId)
                await loadData()
            } catch {
                await MainActor.run {
                    errorMessage = "Erreur lors de l'activation: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteCode(_ code: InvitationCode) {
        Task {
            do {
                try await invitationService.deleteCode(codeId: code.codeId)
                await loadData()
            } catch {
                await MainActor.run {
                    errorMessage = "Erreur lors de la suppression: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func roleDisplayName(_ role: User.UserRole) -> String {
        switch role {
        case .admin: return "Admin"
        case .manager: return "Manager"
        case .standardEmployee: return "Employé"
        case .limitedEmployee: return "Employé limité"
        }
    }
    
    private var initials: String {
        guard let name = currentUser?.displayName else { return "?" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
    
    private func memberInitials(_ name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
}

// MARK: - Supporting Views

struct SettingsInfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct GenerateInvitationView: View {
    let companyId: String
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var invitationService = InvitationService()
    
    // Nouvelles propriétés pour personnalisation
    @State private var customName = ""
    @State private var customCode = ""
    @State private var useCustomCode = false
    @State private var selectedRole: User.UserRole = .standardEmployee
    @State private var validityDays = 30
    @State private var maxUses = 10
    
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var generatedCode: InvitationCode?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Informations") {
                    TextField("Nom du code (optionnel)", text: $customName)
                        .textInputAutocapitalization(.words)
                    
                    Text("Ex: 'Équipe Livraison', 'Nouveaux Stagiaires', etc.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Code d'invitation") {
                    Toggle("Personnaliser le code", isOn: $useCustomCode)
                    
                    if useCustomCode {
                        TextField("Code personnalisé", text: $customCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: customCode) { _, newValue in
                                // Formater en majuscules et enlever espaces
                                customCode = newValue
                                    .uppercased()
                                    .replacingOccurrences(of: " ", with: "-")
                            }
                        
                        Text("Ex: 'LIVRAISON-2025', 'TEAM-A', etc.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !customCode.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                                Text("Aperçu: \(customCode)")
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
                    }
                }
                
                Section("Paramètres du code") {
                    // Sélection du rôle
                    Picker("Rôle attribué", selection: $selectedRole) {
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
                    
                    Stepper("Validité: \(validityDays) jours", value: $validityDays, in: 1...365)
                    Stepper("Utilisations max: \(maxUses)", value: $maxUses, in: 1...100)
                }
                
                Section("Permissions du rôle") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ce code donnera le rôle: **\(roleDisplayName(selectedRole))**")
                            .font(.subheadline)
                        
                        Text("Permissions incluses:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        
                        ForEach(rolePermissions(selectedRole), id: \.self) { permission in
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
                
                if let code = generatedCode {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if let name = code.customName {
                                    Text(name)
                                        .font(.headline)
                                }
                                Text(code.code)
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = code.code
                            }) {
                                Label("Copier", systemImage: "doc.on.doc")
                            }
                        }
                    } header: {
                        Text("Code généré")
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    if useCustomCode {
                        Text("⚠️ Assurez-vous que le code personnalisé est unique et facile à partager.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Le code expirera dans \(validityDays) jours et pourra être utilisé \(maxUses) fois maximum.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nouveau code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        onDismiss()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(isGenerating ? "Génération..." : "Générer") {
                        Task {
                            await generateCode()
                        }
                    }
                    .disabled(isGenerating || generatedCode != nil || (useCustomCode && customCode.isEmpty))
                }
            }
        }
    }
    
    private func generateCode() async {
        isGenerating = true
        errorMessage = nil
        
        guard let userId = PermissionService.shared.currentUser?.userId else {
            errorMessage = "Utilisateur non identifié"
            isGenerating = false
            return
        }
        
        do {
            let finalCustomName = customName.isEmpty ? nil : customName
            let finalCustomCode = (useCustomCode && !customCode.isEmpty) ? customCode : nil
            
            let code = try await invitationService.generateInvitationCode(
                companyId: companyId,
                companyName: "",
                customCode: finalCustomCode,
                customName: finalCustomName,
                role: selectedRole,
                createdBy: userId,
                validityDays: validityDays,
                maxUses: maxUses
            )
            
            await MainActor.run {
                self.generatedCode = code
                self.isGenerating = false
                
                // Copier le code dans le presse-papier
                UIPasteboard.general.string = code.code
                
                // Fermer la page après un court délai
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconde
                    onDismiss()
                    dismiss()
                }
            }
        } catch let error as InvitationService.InvitationError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isGenerating = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isGenerating = false
            }
        }
    }
    
    // Helper functions pour affichage
    private func roleDisplayName(_ role: User.UserRole) -> String {
        switch role {
        case .admin: return "Administrateur"
        case .manager: return "Manager"
        case .standardEmployee: return "Employé"
        case .limitedEmployee: return "Employé limité"
        }
    }
    
    private func rolePermissions(_ role: User.UserRole) -> [String] {
        switch role {
        case .admin:
            return ["Gestion complète", "Accès à toutes les fonctionnalités", "Gestion des utilisateurs", "Codes d'invitation", "Paramètres entreprise"]
        case .manager:
            return ["Gestion d'équipe", "Création événements", "Gestion stock", "Rapports", "Validation commandes"]
        case .standardEmployee:
            return ["Consultation stock", "Scanner articles", "Création commandes", "Gestion événements limités"]
        case .limitedEmployee:
            return ["Consultation uniquement", "Scanner articles", "Accès lecture seule"]
        }
    }
    
    private func permissionDisplayName(_ permission: String) -> String {
        return permission
    }
}

struct MemberDetailView: View {
    let member: User
    let companyOwnerId: String
    
    @Environment(\.dismiss) var dismiss
    @State private var firebaseService = FirebaseService()
    @State private var selectedRole: User.UserRole
    @State private var isSaving = false
    @State private var showingDeleteConfirm = false
    @State private var errorMessage: String?
    
    init(member: User, companyOwnerId: String) {
        self.member = member
        self.companyOwnerId = companyOwnerId
        _selectedRole = State(initialValue: member.role ?? .limitedEmployee)
    }
    
    var isOwner: Bool {
        member.userId == companyOwnerId
    }
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Nom")
                    Spacer()
                    Text(member.displayName)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Email")
                    Spacer()
                    Text(member.email)
                        .foregroundColor(.secondary)
                }
                
                if isOwner {
                    Label("Propriétaire", systemImage: "crown.fill")
                        .foregroundColor(.yellow)
                }
            } header: {
                Text("Informations")
            }
            
            if !isOwner {
                Section {
                    Picker("Rôle", selection: $selectedRole) {
                        ForEach(User.UserRole.allCases, id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                } header: {
                    Text("Permissions")
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Retirer de l'entreprise", systemImage: "person.badge.minus")
                    }
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Détails")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isOwner && selectedRole != member.role {
                ToolbarItem(placement: .primaryAction) {
                    Button(isSaving ? "Enregistrement..." : "Enregistrer") {
                        Task { await saveMember() }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .alert("Retirer le membre", isPresented: $showingDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Retirer", role: .destructive) {
                Task { await removeMember() }
            }
        } message: {
            Text("Voulez-vous vraiment retirer \(member.displayName) de votre entreprise ?")
        }
    }
    
    private func saveMember() async {
        isSaving = true
        
        do {
            let updatedMember = User(
                userId: member.userId,
                email: member.email,
                displayName: member.displayName,
                photoURL: member.photoURL,
                accountType: member.accountType,
                companyId: member.companyId,
                role: selectedRole
            )
            try await firebaseService.updateUser(updatedMember)
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
    
    private func removeMember() async {
        do {
            try await firebaseService.removeUserFromCompany(userId: member.userId)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AuthService())
    }
}

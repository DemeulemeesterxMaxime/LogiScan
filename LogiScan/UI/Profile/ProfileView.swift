//
//  ProfileView.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var localizationManager: LocalizationManager
    @Query private var allTasks: [TodoTask]
    @State private var permissionService = PermissionService.shared
    @State private var authService = AuthService()
    @State private var showingCompanySheet = false
    @State private var showingLogoutConfirm = false
    @State private var showingDeleteAccountConfirm = false
    @State private var showingReauthSheet = false
    @State private var showingNotifications = false
    @State private var reauthEmail = ""
    @State private var reauthPassword = ""
    @State private var deleteAccountError: String?
    
    var currentUser: User? {
        permissionService.currentUser
    }
    
    // Tâches assignées à l'utilisateur (non complétées/annulées)
    private var myTasks: [TodoTask] {
        guard let userId = currentUser?.userId, let companyId = currentUser?.companyId else {
            return []
        }
        return allTasks.filter { task in
            task.companyId == companyId &&
            task.assignedToUserId == userId &&
            task.status != .completed &&
            task.status != .cancelled
        }
    }
    
    // Tâches en libre-service (non attribuées)
    private var unassignedTasks: [TodoTask] {
        guard let companyId = currentUser?.companyId else { return [] }
        return allTasks.filter { task in
            task.companyId == companyId &&
            task.assignedToUserId == nil &&
            task.status != .completed &&
            task.status != .cancelled
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Section Profil Utilisateur
                Section {
                    userInfoRow
                    
                    if let user = currentUser {
                        roleRow(user: user)
                        companyRow(user: user)
                    }
                } header: {
                    Text("my_profile".localized())
                }
                
                // Section Mes Tâches (visible pour tous les employés)
                if currentUser?.companyId != nil {
                    Section {
                        NavigationLink {
                            TodoListView(defaultFilter: .myTasks)
                                .navigationTitle("my_tasks".localized())
                        } label: {
                            HStack {
                                Label("my_daily_tasks".localized(), systemImage: "checklist")
                                
                                Spacer()
                                
                                // Badge avec nombre de tâches
                                if myTasks.count > 0 {
                                    Text("\(myTasks.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.blue)
                                        )
                                }
                            }
                        }
                        
                        NavigationLink {
                            TodoListView(defaultFilter: .unassigned)
                                .navigationTitle("available_tasks".localized())
                        } label: {
                            HStack {
                                Label("available_tasks".localized(), systemImage: "tray.2")
                                
                                Spacer()
                                
                                // Badge avec nombre de tâches
                                if unassignedTasks.count > 0 {
                                    Text("\(unassignedTasks.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.orange)
                                        )
                                }
                            }
                        }
                    } header: {
                        Text("my_tasks".localized())
                    } footer: {
                        Text("my_tasks_description".localized())
                            .font(.caption)
                    }
                }
                
                // Section Gestion des Tâches (visible pour Manager et Admin)
                if permissionService.checkPermission(.writeTasks) || permissionService.checkPermission(.assignTasks) {
                    Section {
                        if permissionService.checkPermission(.writeTasks) {
                            NavigationLink {
                                CreateTaskView()
                            } label: {
                                Label("create_task".localized(), systemImage: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if permissionService.checkPermission(.manageTasks) {
                            NavigationLink {
                                AdminTaskManagementView()
                            } label: {
                                Label("manage_all_tasks".localized(), systemImage: "list.bullet.clipboard")
                            }
                        }
                        
                        if permissionService.checkPermission(.assignTasks) {
                            NavigationLink {
                                AdminTaskManagementView()
                            } label: {
                                Label("assign_tasks".localized(), systemImage: "person.badge.plus")
                            }
                        }
                    } header: {
                        Text("manage_tasks".localized())
                    } footer: {
                        Text("task_management_description".localized())
                            .font(.caption)
                    }
                }
                
                // Section Entreprise (visible si membre d'une entreprise)
                if currentUser?.companyId != nil {
                    Section {
                        NavigationLink {
                            CompanySettingsView()
                        } label: {
                            Label("manage_my_company".localized(), systemImage: "building.2")
                        }
                    } header: {
                        Text("company".localized())
                    }
                }
                
                // Section Administration (visible pour Admin uniquement)
                if permissionService.isAdmin() {
                    Section {
                        NavigationLink {
                            AdminView()
                        } label: {
                            Label("full_administration".localized(), systemImage: "gear.badge")
                        }
                    } header: {
                        Text("administration".localized())
                    }
                }
                
                // Section Paramètres
                Section {
                    Button(action: { showingLogoutConfirm = true }) {
                        HStack {
                            Label("sign_out".localized(), systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    }
                    
                    Button(action: { showingDeleteAccountConfirm = true }) {
                        HStack {
                            Label("delete_my_account".localized(), systemImage: "trash.circle")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                } header: {
                    Text("account_settings".localized())
                } footer: {
                    Text("La suppression du compte est irréversible et supprimera définitivement toutes vos données.")
                        .font(.caption)
                }
            }
            .navigationTitle("profile".localized())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNotifications = true
                    } label: {
                        Image(systemName: "bell.fill")
                    }
                }
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationCenterView()
            }
            .sheet(isPresented: $showingReauthSheet) {
                ReauthenticationSheet(
                    email: $reauthEmail,
                    password: $reauthPassword,
                    onAuthenticate: {
                        Task {
                            await reauthenticateAndDelete()
                        }
                    }
                )
            }
            .alert("Déconnexion", isPresented: $showingLogoutConfirm) {
                Button("Annuler", role: .cancel) {}
                Button("Se déconnecter", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Voulez-vous vraiment vous déconnecter ?")
            }
            .alert("Supprimer mon compte", isPresented: $showingDeleteAccountConfirm) {
                Button("Annuler", role: .cancel) {}
                Button("Supprimer définitivement", role: .destructive) {
                    // Préremplir l'email
                    reauthEmail = currentUser?.email ?? ""
                    reauthPassword = ""
                    showingReauthSheet = true
                }
            } message: {
                Text("⚠️ ATTENTION : Cette action est irréversible !\n\nVotre compte, toutes vos données et votre accès à l'application seront définitivement supprimés.\n\nPour des raisons de sécurité, vous devez vous reconnecter.")
            }
            .alert("Erreur", isPresented: .constant(deleteAccountError != nil)) {
                Button("OK", role: .cancel) {
                    deleteAccountError = nil
                }
            } message: {
                Text(deleteAccountError ?? "")
            }
        }
    }
    
    // MARK: - User Info Row
    
    private var userInfoRow: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
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
    }
    
    // MARK: - Role Row
    
    private func roleRow(user: User) -> some View {
        HStack {
            Label("Rôle", systemImage: "person.badge.key")
            
            Spacer()
            
            if let role = user.role {
                RoleBadge(role: role)
            } else {
                Text("no_role".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Company Row
    
    private func companyRow(user: User) -> some View {
        HStack {
            Label("Entreprise", systemImage: "building.2")
            
            Spacer()
            
            if user.companyId != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("member".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("none_feminine".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var initials: String {
        guard let name = currentUser?.displayName else { return "?" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
    
    // MARK: - Actions
    
    private func logout() {
        Task {
            do {
                try await authService.signOut()
                permissionService.clearCurrentUser()
            } catch {
                print("❌ Erreur lors de la déconnexion : \(error.localizedDescription)")
            }
        }
    }
    
    private func reauthenticateAndDelete() async {
        guard !reauthEmail.isEmpty, !reauthPassword.isEmpty else {
            await MainActor.run {
                deleteAccountError = "Veuillez saisir votre email et mot de passe"
            }
            return
        }
        
        do {
            // 1. Réauthentifier
            try await authService.reauthenticate(email: reauthEmail, password: reauthPassword)
            
            // 2. Supprimer le compte Firebase
            try await authService.deleteAccount()
            
            // 3. Nettoyer les données locales
            await MainActor.run {
                permissionService.clearCurrentUser()
                // Le modelContext sera nettoyé automatiquement
            }
            
            print("✅ Compte supprimé avec succès")
            
        } catch {
            await MainActor.run {
                deleteAccountError = error.localizedDescription
                showingReauthSheet = false
            }
            print("❌ Erreur lors de la suppression du compte : \(error.localizedDescription)")
        }
    }
}

// MARK: - Reauthentication Sheet

struct ReauthenticationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var email: String
    @Binding var password: String
    let onAuthenticate: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    
                    SecureField("Mot de passe", text: $password)
                } header: {
                    Text("Confirmation d'identité")
                } footer: {
                    Text("Pour des raisons de sécurité, veuillez confirmer votre identité en saisissant votre mot de passe.")
                        .font(.caption)
                }
            }
            .navigationTitle("Réauthentification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmer") {
                        onAuthenticate()
                        dismiss()
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Company Settings View

struct CompanySettingsView: View {
    @State private var companyService = CompanyService()
    @State private var firebaseService = FirebaseService()
    @State private var permissionService = PermissionService.shared
    
    @State private var company: Company?
    @State private var members: [User] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if let company = company {
                // Informations entreprise
                Section {
                    CompanyInfoRow(title: "Nom", value: company.name, icon: "building.2")
                    
                    if let address = company.address {
                        CompanyInfoRow(title: "Adresse", value: address, icon: "mappin.circle")
                    }
                    
                    if let phone = company.phone {
                        CompanyInfoRow(title: "Téléphone", value: phone, icon: "phone.circle")
                    }
                    
                    CompanyInfoRow(title: "Email", value: company.email, icon: "envelope.circle")
                    
                    if let siret = company.siret {
                        CompanyInfoRow(title: "SIRET", value: siret, icon: "doc.text")
                    }
                } header: {
                    Text("info".localized())
                }
                
                // Membres de l'entreprise
                Section {
                    ForEach(members, id: \.userId) { member in
                        CompanyMemberRow(member: member, isOwner: member.userId == company.ownerId)
                    }
                } header: {
                    HStack {
                        Text("members".localized())
                        Spacer()
                        Text("\(members.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Actions Admin
                if permissionService.isAdmin() {
                    Section {
                        NavigationLink {
                            AdminView()
                        } label: {
                            Label("Éditer l'entreprise", systemImage: "pencil")
                        }
                    } header: {
                        Text("administration".localized())
                    }
                }
            } else if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Mon Entreprise")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadCompanyData()
        }
        .onAppear {
            Task {
                await loadCompanyData()
            }
        }
    }
    
    // MARK: - Load Data
    
    private func loadCompanyData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let companyId = permissionService.currentUser?.companyId else {
                errorMessage = "Aucune entreprise associée"
                isLoading = false
                return
            }
            
            // Charger l'entreprise
            let loadedCompany = try await companyService.fetchCompany(companyId: companyId)
            
            // Charger les membres
            let loadedMembers = try await firebaseService.fetchCompanyMembers(companyId: companyId)
            
            await MainActor.run {
                self.company = loadedCompany
                self.members = loadedMembers
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Supporting Views

struct CompanyInfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct CompanyMemberRow: View {
    let member: User
    let isOwner: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.6), .cyan.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initials)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(member.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isOwner {
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
        .padding(.vertical, 4)
    }
    
    private var initials: String {
        let components = member.displayName.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
}

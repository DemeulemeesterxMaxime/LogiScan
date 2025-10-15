//
//  ProfileView.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var permissionService = PermissionService.shared
    @State private var showingLogoutConfirm = false
    @State private var showingCompanySection = false
    @State private var showingAdminSection = false
    
    var currentUser: User? {
        permissionService.currentUser
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
                    Text("Mon Profil")
                }
                
                // Section Entreprise (visible si membre d'une entreprise)
                if currentUser?.companyId != nil {
                    Section {
                        NavigationLink {
                            CompanySettingsView()
                        } label: {
                            Label("Gérer mon entreprise", systemImage: "building.2")
                        }
                    } header: {
                        Text("Entreprise")
                    }
                }
                
                // Section Administration (visible pour Admin uniquement)
                if permissionService.isAdmin() {
                    Section {
                        NavigationLink {
                            AdminView()
                        } label: {
                            Label("Administration complète", systemImage: "gear.badge")
                        }
                    } header: {
                        Text("Administration")
                    }
                }
                
                // Section Paramètres
                Section {
                    Button(action: { showingLogoutConfirm = true }) {
                        HStack {
                            Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Actions")
                }
            }
            .navigationTitle("Profil")
            .alert("Déconnexion", isPresented: $showingLogoutConfirm) {
                Button("Annuler", role: .cancel) {}
                Button("Se déconnecter", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Voulez-vous vraiment vous déconnecter ?")
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
                Text("Aucun rôle")
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
                Text("Membre")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Aucune")
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
            try? await authService.signOut()
            permissionService.clearCurrentUser()
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
                    Text("Informations")
                }
                
                // Membres de l'entreprise
                Section {
                    ForEach(members, id: \.userId) { member in
                        CompanyMemberRow(member: member, isOwner: member.userId == company.ownerId)
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
                
                // Actions Admin
                if permissionService.isAdmin() {
                    Section {
                        NavigationLink {
                            AdminView()
                        } label: {
                            Label("Éditer l'entreprise", systemImage: "pencil")
                        }
                    } header: {
                        Text("Administration")
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

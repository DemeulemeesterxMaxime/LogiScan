//
//  QuoteVersionHistoryView.swift
//  LogiScan
//
//  Created by Assistant on 27/10/2025.
//

import SwiftUI
import SwiftData
import PDFKit

struct QuoteVersionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var versionService = QuoteVersionService()
    
    let event: Event
    let quoteItems: [QuoteItem]
    
    @State private var versions: [FirestoreQuoteVersion] = []
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedVersion: FirestoreQuoteVersion?
    @State private var showingPDF = false
    @State private var pdfDocument: PDFDocument?
    @State private var showRestoreConfirmation = false
    @State private var versionToRestore: FirestoreQuoteVersion?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Chargement des versions...")
                        .padding()
                } else if versions.isEmpty {
                    emptyStateView
                } else {
                    versionsList
                }
            }
            .navigationTitle("Historique des devis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .alert("Information", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .confirmationDialog(
                "Reprendre cette version ?",
                isPresented: $showRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reprendre la modification") {
                    if let version = versionToRestore {
                        restoreVersion(version)
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les articles du devis seront chargés depuis cette version pour modification.")
            }
            .sheet(isPresented: $showingPDF) {
                if let pdfDoc = pdfDocument {
                    PDFViewerSheet(
                        pdfDocument: pdfDoc,
                        version: selectedVersion,
                        onRestore: {
                            if let version = selectedVersion {
                                versionToRestore = version
                                showRestoreConfirmation = true
                            }
                        }
                    )
                }
            }
        }
        .task {
            await loadVersions()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Aucune version")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Aucun devis finalisé pour cet événement")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Versions List
    
    private var versionsList: some View {
        List {
            Section {
                Text("\(versions.count) version(s) disponible(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(versions, id: \.versionId) { version in
                VersionRow(version: version) {
                    viewVersion(version)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadVersions() async {
        do {
            versions = try await versionService.fetchVersions(for: event.eventId)
            isLoading = false
            print("✅ [QuoteVersionHistory] \(versions.count) versions chargées")
        } catch {
            await MainActor.run {
                isLoading = false
                alertMessage = "Erreur lors du chargement: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func viewVersion(_ version: FirestoreQuoteVersion) {
        selectedVersion = version
        
        Task {
            do {
                // Télécharger le PDF
                let pdfData: Data
                
                if let urlString = version.pdfUrl {
                    // Télécharger depuis l'URL
                    pdfData = try await versionService.downloadPDFFromURL(urlString)
                } else {
                    // Télécharger depuis le Storage path
                    pdfData = try await versionService.downloadPDF(from: version.pdfStoragePath)
                }
                
                await MainActor.run {
                    pdfDocument = PDFDocument(data: pdfData)
                    showingPDF = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Erreur lors du téléchargement du PDF: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func restoreVersion(_ version: FirestoreQuoteVersion) {
        // TODO: Implémenter la logique pour charger les items de cette version
        // et rediriger vers QuoteBuilder avec ces items
        print("🔄 Restauration de la version \(version.versionNumber)")
        
        alertMessage = "Fonctionnalité en cours d'implémentation"
        showAlert = true
        
        // Cette fonctionnalité nécessitera:
        // 1. Charger les quoteItemsSnapshot de cette version
        // 2. Créer de nouveaux QuoteItems dans SwiftData
        // 3. Ouvrir QuoteBuilder avec ces items
    }
}

// MARK: - Version Row

struct VersionRow: View {
    let version: FirestoreQuoteVersion
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icône
                Image(systemName: statusIcon(for: version.status))
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 32)
                
                // Infos
                VStack(alignment: .leading, spacing: 4) {
                    Text("Version \(version.versionNumber)")
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(version.createdByName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(String(format: "%.2f € TTC", version.finalAmount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                // Badge de version
                if version.versionNumber == 1 {
                    Text("Initiale")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: version.createdAt)
    }
    
    private func statusIcon(for status: String) -> String {
        switch status {
        case "draft": return "doc.text"
        case "finalized": return "checkmark.seal.fill"
        case "sent": return "paperplane.fill"
        case "accepted": return "hand.thumbsup.fill"
        case "refused": return "hand.thumbsdown.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - PDF Viewer Sheet

struct PDFViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let pdfDocument: PDFDocument
    let version: FirestoreQuoteVersion?
    let onRestore: () -> Void
    
    var body: some View {
        NavigationView {
            PDFKitView(document: pdfDocument)
                .navigationTitle(version.map { "Version \($0.versionNumber)" } ?? "PDF")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Fermer") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            onRestore()
                            dismiss()
                        }) {
                            Label("Modifier", systemImage: "square.and.pencil")
                        }
                    }
                }
        }
    }
}

#Preview {
    let event = Event(
        eventId: "EVENT123",
        name: "Test Event",
        clientName: "John Doe"
    )
    
    QuoteVersionHistoryView(event: event, quoteItems: [])
}

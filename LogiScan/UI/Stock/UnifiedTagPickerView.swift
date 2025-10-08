//
//  UnifiedTagPickerView.swift
//  LogiScan
//
//  Created by Demeulemeester on 03/10/2025.
//

import SwiftData
import SwiftUI

/// Vue unifiée pour gérer les étiquettes dans toute l'app
/// Utilisable dans le formulaire de création ET dans l'édition d'articles existants
struct UnifiedTagPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allStockItems: [StockItem]

    let category: String
    @Binding var selectedTags: [String]

    @State private var newTagText = ""
    @State private var showingDeleteConfirmation = false
    @State private var tagToDelete: String?
    @State private var originalTags: [String] = []  // ✅ Sauvegarde des tags originaux

    var existingTags: [String] {
        let allTags = allStockItems.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    var suggestedTags: [String] {
        let currentTags = Set(selectedTags)
        // ✅ Ne pas suggérer le tag qu'on vient d'ajouter
        return existingTags.filter {
            !currentTags.contains($0) && !newTagText.isEmpty
                && $0.localizedCaseInsensitiveContains(newTagText)
                && !selectedTags.contains($0)  // Évite les tags déjà sélectionnés
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Section d'ajout d'étiquette
                addTagSection

                Divider()

                // Liste des étiquettes actuelles
                currentTagsSection

                if !suggestedTags.isEmpty {
                    Divider()
                    suggestedTagsSection
                }

                Spacer()
            }
            .navigationTitle("Étiquettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        // ✅ Restaurer les tags originaux
                        selectedTags = originalTags
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // ✅ Sauvegarder les tags originaux au chargement
                originalTags = selectedTags
            }
        }
        .alert("Supprimer l'étiquette", isPresented: $showingDeleteConfirmation) {
            Button("Supprimer", role: .destructive) {
                if let tag = tagToDelete {
                    removeTag(tag)
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            if let tag = tagToDelete {
                Text("Voulez-vous supprimer l'étiquette \"\(tag)\" ?")
            }
        }
    }

    // MARK: - Add Tag Section

    private var addTagSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                TextField("Nouvelle étiquette", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.words)
                    .onSubmit {
                        addNewTag()
                    }

                Button("Ajouter") {
                    addNewTag()
                }
                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }

            // Tags pré-définis pour cette catégorie
            categoryTagsSection
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Category Tags Section

    private var categoryTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags suggérés pour \(category)")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 80), spacing: 8)
                ], spacing: 8
            ) {
                ForEach(predefinedTagsForCategory, id: \.self) { tag in
                    Button(action: {
                        addTag(tag)
                    }) {
                        Text(tag)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        selectedTags.contains(tag)
                                            ? Color.blue.opacity(0.3) : Color.blue.opacity(0.1))
                            )
                            .foregroundColor(selectedTags.contains(tag) ? .blue : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        Color.blue.opacity(0.3),
                                        lineWidth: selectedTags.contains(tag) ? 1 : 0)
                            )
                    }
                    .disabled(selectedTags.contains(tag))
                }
            }
        }
    }

    // MARK: - Current Tags Section

    private var currentTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Étiquettes actuelles (\(selectedTags.count))")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            if selectedTags.isEmpty {
                Text("Aucune étiquette. Ajoutez-en une ci-dessus.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 100), spacing: 12)
                        ], spacing: 12
                    ) {
                        ForEach(selectedTags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Button(action: {
                                    tagToDelete = tag
                                    showingDeleteConfirmation = true
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.green.opacity(0.2))
                            )
                            .foregroundColor(.green)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Suggested Tags Section

    private var suggestedTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags suggérés")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 100), spacing: 12)
                    ], spacing: 12
                ) {
                    ForEach(suggestedTags, id: \.self) { tag in
                        Button(action: {
                            addTag(tag)
                        }) {
                            Text(tag)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .foregroundColor(.blue)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Predefined Tags

    private var predefinedTagsForCategory: [String] {
        switch category {
        case "Éclairage":
            return [
                "LED", "Halogène", "Par", "Wash", "Spot", "Flood", "RGB", "UV", "Stroboscope",
                "Laser", "Extérieur", "Intérieur",
            ]
        case "Son":
            return [
                "Passif", "Actif", "Sub", "Satellite", "Monitor", "Micro", "DI", "Ampli",
                "Table de mixage", "Effet",
            ]
        case "Structures":
            return [
                "Alu", "Acier", "Pied", "Traverse", "Angle", "Coupleur", "Sangle", "Chaîne",
                "Manille", "Élingue",
            ]
        case "Mobilier":
            return [
                "Table", "Chaise", "Banc", "Bar", "Mange-debout", "Parasol", "Podium", "Scène",
                "Barrière",
            ]
        case "Câblage":
            return ["XLR", "Jack", "Speakon", "PowerCon", "DMX", "RJ45", "Multipaire", "Extension"]
        default:
            return ["Neuf", "Occasion", "Fragile", "Lourd", "Urgent", "VIP", "Backup", "Test"]
        }
    }

    // MARK: - Actions

    private func addNewTag() {
        let trimmedTag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTag.isEmpty else { return }
        guard !selectedTags.contains(trimmedTag) else {
            newTagText = ""
            return
        }

        withAnimation(.spring(response: 0.3)) {
            selectedTags.append(trimmedTag)
        }
        newTagText = ""
    }

    private func addTag(_ tag: String) {
        guard !selectedTags.contains(tag) else { return }

        withAnimation(.spring(response: 0.3)) {
            selectedTags.append(tag)
        }
    }

    private func removeTag(_ tag: String) {
        withAnimation(.spring(response: 0.3)) {
            selectedTags.removeAll { $0 == tag }
        }
    }
}

// MARK: - Preview

#Preview("Nouveau Article") {
    @Previewable @State var tags: [String] = ["LED", "50W"]

    UnifiedTagPickerView(
        category: "Éclairage",
        selectedTags: $tags
    )
    .modelContainer(for: [StockItem.self], inMemory: true)
}

#Preview("Sans Tags") {
    @Previewable @State var tags: [String] = []

    UnifiedTagPickerView(
        category: "Son",
        selectedTags: $tags
    )
    .modelContainer(for: [StockItem.self], inMemory: true)
}

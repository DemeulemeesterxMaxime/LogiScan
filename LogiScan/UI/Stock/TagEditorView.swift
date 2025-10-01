//
//  TagEditorView.swift
//  LogiScan
//
//  Created by Demeulemeester on 01/10/2025.
//

import SwiftUI
import SwiftData

struct TagEditorView: View {
    @Bindable var stockItem: StockItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var newTagText = ""
    @State private var allExistingTags: [String] = []
    @State private var showingDeleteConfirmation = false
    @State private var tagToDelete: String?
    
    @Query private var allStockItems: [StockItem]
    
    var existingTags: [String] {
        let allTags = allStockItems.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    var suggestedTags: [String] {
        let currentTags = Set(stockItem.tags)
        return existingTags.filter { !currentTags.contains($0) && !newTagText.isEmpty && $0.localizedCaseInsensitiveContains(newTagText) }
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
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Supprimer l'étiquette", isPresented: $showingDeleteConfirmation) {
            Button("Supprimer", role: .destructive) {
                if let tag = tagToDelete {
                    removeTag(tag)
                }
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            if let tag = tagToDelete {
                Text("Voulez-vous supprimer l'étiquette \"\(tag)\" ?")
            }
        }
    }
    
    private var addTagSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                TextField("Nouvelle étiquette", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
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
    
    private var categoryTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags suggérés pour \(stockItem.category)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80), spacing: 8)
            ], spacing: 8) {
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
                                    .fill(stockItem.tags.contains(tag) ? Color.blue.opacity(0.3) : Color.blue.opacity(0.1))
                            )
                            .foregroundColor(stockItem.tags.contains(tag) ? .blue : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: stockItem.tags.contains(tag) ? 1 : 0)
                            )
                    }
                    .disabled(stockItem.tags.contains(tag))
                }
            }
        }
    }
    
    private var predefinedTagsForCategory: [String] {
        switch stockItem.category {
        case "Éclairage":
            return ["LED", "Halogène", "Par", "Wash", "Spot", "Flood", "RGB", "UV", "Stroboscope", "Laser", "Extérieur", "Intérieur"]
        case "Son":
            return ["Passif", "Actif", "Sub", "Satellite", "Monitor", "Micro", "DI", "Ampli", "Table de mixage", "Effet"]
        case "Structures":
            return ["Alu", "Acier", "Pied", "Traverse", "Angle", "Coupleur", "Sangle", "Chaîne", "Manille", "Élingue"]
        case "Mobilier":
            return ["Table", "Chaise", "Banc", "Bar", "Mange-debout", "Parasol", "Podium", "Scène", "Barrière"]
        default:
            return ["Neuf", "Occasion", "Fragile", "Lourd", "Urgent", "VIP", "Backup", "Test"]
        }
    }
    
    private var currentTagsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Étiquettes actuelles (\(stockItem.tags.count))")
                    .font(.headline)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            if stockItem.tags.isEmpty {
                Text("Aucune étiquette")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: 8)
                ], spacing: 8) {
                    ForEach(stockItem.tags.sorted(), id: \.self) { tag in
                        TagChip(
                            tag: tag,
                            onDelete: {
                                tagToDelete = tag
                                showingDeleteConfirmation = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var suggestedTagsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Suggestions")
                    .font(.headline)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedTags.prefix(10), id: \.self) { tag in
                        Button(action: {
                            addTag(tag)
                            newTagText = ""
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.green.opacity(0.1))
                            )
                            .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func addNewTag() {
        let trimmedTag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return }
        
        addTag(trimmedTag)
        newTagText = ""
    }
    
    private func addTag(_ tag: String) {
        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTag.isEmpty && !stockItem.tags.contains(normalizedTag) else { return }
        
        stockItem.tags.append(normalizedTag)
        stockItem.updatedAt = Date()
    }
    
    private func removeTag(_ tag: String) {
        stockItem.tags.removeAll { $0 == tag }
        stockItem.updatedAt = Date()
        tagToDelete = nil
    }
    
    private func saveChanges() {
        try? modelContext.save()
    }
}

struct TagChip: View {
    let tag: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
        .foregroundColor(.blue)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    let container = try! ModelContainer(
        for: StockItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let sampleItem = StockItem(
        sku: "LED-SPOT-50W",
        name: "Projecteur LED 50W",
        category: "Éclairage",
        totalQuantity: 25,
        unitWeight: 2.5,
        unitVolume: 0.01,
        unitValue: 150.0,
        tags: ["LED", "50W", "Extérieur"]
    )
    
    return TagEditorView(stockItem: sampleItem)
        .modelContainer(container)
}

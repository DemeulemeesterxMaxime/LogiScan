//
//  TagEditorView.swift
//  LogiScan
//
//  Created by Demeulemeester on 01/10/2025.
//

import SwiftData
import SwiftUI

/// Wrapper pour UnifiedTagPickerView qui édite directement un StockItem
struct TagEditorView: View {
    @Bindable var stockItem: StockItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var tempTags: [String] = []

    var body: some View {
        UnifiedTagPickerView(
            category: stockItem.category,
            selectedTags: $tempTags
        )
        .onAppear {
            tempTags = stockItem.tags
        }
        .onDisappear {
            saveChanges()
        }
    }

    private func saveChanges() {
        stockItem.tags = tempTags
        stockItem.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print("❌ Erreur sauvegarde tags: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var sampleItem = StockItem(
        sku: "LED-SPOT-50W",
        name: "Projecteur LED 50W",
        category: "Éclairage",
        totalQuantity: 25,
        unitWeight: 2.5,
        unitVolume: 0.01,
        unitValue: 150.0,
        tags: ["LED", "50W", "Extérieur"]
    )

    TagEditorView(stockItem: sampleItem)
        .modelContainer(for: [StockItem.self], inMemory: true)
}

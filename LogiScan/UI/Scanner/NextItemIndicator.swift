//
//  NextItemIndicator.swift
//  LogiScan
//
//  Created by Assistant on 16/10/2025.
//

import SwiftUI

/// Indicateur du prochain article à scanner avec navigation
struct NextItemIndicator: View {
    let scanList: ScanList
    @State private var currentItemIndex: Int = 0
    @State private var showItemDetail = false
    
    // Calculer les articles non scannés
    private var pendingItems: [PreparationListItem] {
        scanList.items.filter { !$0.isComplete }
    }
    
    // Article actuellement affiché
    private var currentItem: PreparationListItem? {
        guard !pendingItems.isEmpty else { return nil }
        return pendingItems[currentItemIndex % pendingItems.count]
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Barre de progression intégrée
            progressBar
            
            if let item = currentItem {
                // Prochain article à scanner
                Button(action: {
                    // Passer à l'article suivant
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentItemIndex = (currentItemIndex + 1) % pendingItems.count
                    }
                }) {
                    HStack(spacing: 12) {
                        // Icône catégorie
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: categoryIcon(for: item.category))
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                        }
                        
                        // Info article
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prochain article")
                                .font(.caption)
                                .foregroundColor(.secondary)  // Adaptatif
                            
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)  // Adaptatif
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            HStack(spacing: 4) {
                                Text("SKU: \(item.sku)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)  // Adaptatif
                                    .lineLimit(1)
                                
                                Text("•")
                                    .foregroundColor(.secondary.opacity(0.6))
                                
                                Text("\(item.remainingQuantity) restant\(item.remainingQuantity > 1 ? "s" : "")")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Flèche et compteur
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                                .foregroundColor(.primary)  // Adaptatif
                            
                            if pendingItems.count > 1 {
                                Text("\(currentItemIndex + 1)/\(pendingItems.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)  // Adaptatif
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                // Tous les articles sont scannés
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Liste complète")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)  // Adaptatif
                        
                        Text("Tous les articles ont été scannés")
                            .font(.caption)
                            .foregroundColor(.secondary)  // Adaptatif
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray6).opacity(0.95),  // Adaptatif : gris clair en mode clair, gris foncé en mode sombre
                            Color(.systemGray5).opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.6),  // Plus visible
                                    Color.orange.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2  // Bordure plus épaisse pour meilleure visibilité
                        )
                )
                .shadow(color: Color.orange.opacity(0.3), radius: 12, x: 0, y: 4)  // Ombre renforcée
        )
    }
    
    // Barre de progression
    private var progressBar: some View {
        let scannedCount = scanList.items.filter { $0.isComplete }.count
        let totalCount = scanList.items.count
        let progress = totalCount > 0 ? Double(scannedCount) / Double(totalCount) : 0.0
        
        return VStack(spacing: 8) {
            HStack {
                Label("Progression", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary.opacity(0.9))  // Adaptatif mode clair/sombre
                
                Spacer()
                
                Text("\(scannedCount)/\(totalCount)")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background - Adaptatif
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                    
                    // Progress bar avec gradient renforcé
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange,
                                    Color.orange.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                        .overlay(
                            // Effet de brillance plus visible
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: geo.size.width * progress)
                        )
                        .overlay(
                            // Bordure pour contraste en mode clair
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.orange.opacity(0.5), lineWidth: 0.5)
                                .frame(width: geo.size.width * progress)
                        )
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
    
    // Helper : icône selon la catégorie
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case let c where c.contains("table"):
            return "table.furniture"
        case let c where c.contains("chaise"):
            return "chair"
        case let c where c.contains("éclairage"):
            return "lightbulb"
        case let c where c.contains("décor"):
            return "sparkles"
        case let c where c.contains("technique"):
            return "speaker.wave.2"
        default:
            return "cube.box"
        }
    }
}

#Preview {
    @Previewable @State var scanList = {
        let list = ScanList(
            scanListId: "test-1",
            eventId: "event-1",
            eventName: "Festival LBR",
            totalItems: 2,
            scannedItems: 0,
            status: .inProgress
        )
        
        // Ajouter des items
        let item1 = PreparationListItem(
            scanListId: "test-1",
            sku: "TBL-001",
            name: "Table ronde 8 pers",
            category: "Table",
            quantityRequired: 10,
            quantityScanned: 6
        )
        
        let item2 = PreparationListItem(
            scanListId: "test-1",
            sku: "CHR-001",
            name: "Chaise bois",
            category: "Chaise",
            quantityRequired: 80,
            quantityScanned: 45
        )
        
        list.items.append(item1)
        list.items.append(item2)
        
        return list
    }()
    
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            NextItemIndicator(scanList: scanList)
                .padding()
        }
    }
}

//
//  CameraStyleModeSelectorView.swift
//  LogiScan
//
//  Created by Demeulemeester on 14/10/2025.
//  Style appareil photo iOS avec modes horizontaux + détails en scrollant vers le bas
//

import SwiftUI

struct CameraStyleModeSelectorView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @Binding var showModeDetails: Bool
    @State private var dragOffset: CGFloat = 0
    @State private var selectedModeIndex: Int = 0
    
    let allModes = ScanMode.allCases
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode Selector horizontal (comme appareil photo)
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let currentIndex = allModes.firstIndex(of: viewModel.currentMode) ?? 0
                
                HStack(spacing: 0) {
                    ForEach(Array(allModes.enumerated()), id: \.offset) { index, mode in
                        ModeItem(
                            mode: mode,
                            isSelected: mode == viewModel.currentMode,
                            width: screenWidth / 3.5
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if mode != viewModel.currentMode {
                                    // Si le mode nécessite une config (camion/event)
                                    if mode.requiredPermission != .scanQR && mode != .free && mode != .inventory {
                                        viewModel.showModeSelector = true
                                    } else {
                                        viewModel.selectMode(mode)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: screenWidth * CGFloat(allModes.count) / 3.5)
                .offset(x: screenWidth * 0.4 - (screenWidth / 3.5) * CGFloat(currentIndex))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.currentMode)
            }
            .frame(height: 50)
            .padding(.top, 8)
            
            // Description du mode actuel
            VStack(spacing: 4) {
                Text(viewModel.currentMode.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal)
                
                // Indicateur pour afficher les détails
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showModeDetails.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(showModeDetails ? "Masquer" : "Plus d'infos")
                            .font(.caption2)
                        Image(systemName: showModeDetails ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 4)
                }
            }
            .padding(.bottom, 8)
            
            // Vue détaillée (visible en scrollant vers le bas)
            if showModeDetails {
                ModeDetailView(mode: viewModel.currentMode, viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Mode Item (élément du carousel horizontal)

struct ModeItem: View {
    let mode: ScanMode
    let isSelected: Bool
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 6) {
            // Icône
            Image(systemName: mode.icon)
                .font(.system(size: isSelected ? 24 : 20))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .frame(height: 28)
            
            // Nom du mode
            Text(mode.displayName)
                .font(.system(size: isSelected ? 13 : 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: width)
        .scaleEffect(isSelected ? 1.0 : 0.85)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Mode Detail View (vue détaillée)

struct ModeDetailView: View {
    let mode: ScanMode
    @ObservedObject var viewModel: ScannerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Infos détaillées
            VStack(alignment: .leading, spacing: 12) {
                // Description complète
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.title3)
                        .foregroundColor(mode.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comment ça marche ?")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text(getDetailedDescription(for: mode))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Actions disponibles
                if let actions = getAvailableActions(for: mode) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(mode.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("automatic_actions".localized())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(actions)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                // Contexte actuel (camion, event)
                if let context = getCurrentContext() {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .foregroundColor(mode.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("current_context".localized())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(context)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(
            Rectangle()
                .fill(.black.opacity(0.3))
        )
    }
    
    private func getDetailedDescription(for mode: ScanMode) -> String {
        switch mode {
        case .free:
            return "Scannez n'importe quel QR code pour voir les détails de l'asset. Aucune action automatique."
        case .inventory:
            return "Mode inventaire pour compter et vérifier le stock disponible. Créez des listes de comptage."
        case .stockToTruck:
            return "Chargement d'un camion depuis le dépôt. Chaque scan déplace automatiquement l'asset dans le camion."
        case .truckToEvent:
            return "Déchargement du camion sur le site d'événement. Les assets sont automatiquement assignés à l'événement."
        case .eventToTruck:
            return "Rechargement du camion après l'événement. Les assets retournent dans le camion."
        case .truckToStock:
            return "Retour au dépôt. Les assets sont automatiquement remis en stock et le camion est vidé."
        }
    }
    
    private func getAvailableActions(for mode: ScanMode) -> String? {
        guard let movementType = mode.autoMovementType else { return nil }
        
        switch movementType {
        case .load:
            return "Création automatique de mouvements de chargement"
        case .unload:
            return "Création automatique de mouvements de déchargement"
        case .reload:
            return "Création automatique de mouvements de rechargement"
        case .returnWarehouse:
            return "Création automatique de mouvements de retour"
        default:
            return nil
        }
    }
    
    private func getCurrentContext() -> String? {
        var parts: [String] = []
        
        if let truck = viewModel.selectedTruck {
            parts.append("Camion: \(truck.licensePlate)")
        }
        
        if let event = viewModel.selectedEvent {
            parts.append("Événement: \(event.name)")
        }
        
        if let session = viewModel.currentSession, let expected = session.expectedAssets {
            parts.append("\(session.scannedAssets.count)/\(expected.count) assets scannés")
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        
        VStack {
            Spacer()
            
            CameraStyleModeSelectorView(
                viewModel: {
                    let vm = ScannerViewModel(
                        assetRepository: PreviewAssetRepository(),
                        movementRepository: PreviewMovementRepository()
                    )
                    vm.currentMode = .stockToTruck
                    return vm
                }(),
                showModeDetails: .constant(false)
            )
            .frame(height: 120)
        }
    }
    .ignoresSafeArea()
}

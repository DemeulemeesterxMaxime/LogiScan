//
//  ScanOverlayView.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import SwiftUI

/// Overlay affiché pendant le scan avec animations et feedback
struct ScanOverlayView: View {
    @ObservedObject var viewModel: ScannerViewModel
    let onShowList: () -> Void
    let onChangeMode: () -> Void
    
    var body: some View {
        ZStack {
            // Mode Indicator (top)
            VStack {
                modeIndicator
                    .padding(.top, 60)
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 16) {
                    // Success Animation
                    if viewModel.showSuccessAnimation {
                        successAnimationView
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Duplicate Warning
                    if viewModel.showDuplicateWarning {
                        duplicateWarningView
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Session Progress (if applicable)
                    if let session = viewModel.currentSession, viewModel.currentMode != .free {
                        sessionProgressView(session: session)
                            .transition(.move(edge: .bottom))
                    }
                    
                    // Control Buttons
                    controlButtons
                }
                .padding()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showSuccessAnimation)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showDuplicateWarning)
    }
    
    // MARK: - Components
    
    private var modeIndicator: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.currentMode.icon)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentMode.displayName)
                    .font(.headline)
                
                Text(viewModel.currentMode.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Change Mode Button
            Button(action: onChangeMode) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
            }
        }
        .foregroundColor(.white)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .padding(.horizontal)
    }
    
    private var successAnimationView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 80, height: 80)
                    .scaleEffect(viewModel.showSuccessAnimation ? 1.2 : 0.8)
                    .opacity(viewModel.showSuccessAnimation ? 0.3 : 0)
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
            .animation(
                .spring(response: 0.3, dampingFraction: 0.6)
                    .repeatCount(1),
                value: viewModel.showSuccessAnimation
            )
            
            Text("Asset scanné !")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var duplicateWarningView: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.yellow)
            
            Text("Déjà scanné !")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.9))
                .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)
        )
    }
    
    private func sessionProgressView(session: ScanSession) -> some View {
        VStack(spacing: 12) {
            // Progress Bar
            VStack(spacing: 8) {
                HStack {
                    Text("progression".localized())
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(session.scannedAssets.count)/\(session.expectedAssets?.count ?? 0)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.currentMode.color)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.currentMode.gradient)
                            .frame(width: geometry.size.width * session.progress, height: 12)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: session.progress)
                    }
                }
                .frame(height: 12)
            }
            
            // Quick Stats
            HStack(spacing: 16) {
                statItem(icon: "checkmark.circle.fill", value: "\(viewModel.sessionStats.totalScanned)", label: "Scannés")
                
                if let expected = session.expectedAssets {
                    statItem(icon: "clock.fill", value: "\(expected.count - session.scannedAssets.count)", label: "Restants")
                }
                
                if session.isComplete {
                    statItem(icon: "checkmark.seal.fill", value: "Terminé", label: "", color: .green)
                }
            }
        }
        .foregroundColor(.white)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
    }
    
    private func statItem(icon: String, value: String, label: String, color: Color = .white) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(color)
            
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var controlButtons: some View {
        HStack(spacing: 12) {
            // Show List Button (if applicable)
            if !viewModel.scanList.isEmpty {
                Button(action: onShowList) {
                    VStack(spacing: 4) {
                        Image(systemName: "list.clipboard")
                            .font(.title3)
                        Text("list".localized())
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .foregroundColor(.white)
                }
            }
            
            // Scan Control Button
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScanning()
                } else {
                    viewModel.startScanning()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isScanning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title3)
                    Text(viewModel.isScanning ? "Pause" : "Scanner")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.isScanning ? Color.orange : Color.green)
                )
                .foregroundColor(.white)
            }
            
            // End Session Button (if applicable)
            if viewModel.currentSession != nil && viewModel.currentMode != .free {
                Button(action: {
                    viewModel.endCurrentSession()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        Text("finish".localized())
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        
        ScanOverlayView(
            viewModel: {
                let vm = ScannerViewModel(
                    assetRepository: PreviewAssetRepository(),
                    movementRepository: PreviewMovementRepository()
                )
                vm.currentMode = .stockToTruck
                vm.isScanning = true
                vm.sessionStats.totalScanned = 15
                return vm
            }(),
            onShowList: {},
            onChangeMode: {}
        )
    }
    .ignoresSafeArea()
}

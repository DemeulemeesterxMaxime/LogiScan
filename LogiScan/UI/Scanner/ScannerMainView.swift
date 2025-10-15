//
//  ScannerMainView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//  Refactored on 13/10/2025 - Multi-mode scanner with enhanced UX
//

import SwiftUI
import SwiftData
import AVFoundation

struct ScannerMainView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ScannerViewModel
    @StateObject private var syncManager = SyncManager()
    @State private var showingPermissionAlert = false
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var showModeDetails = false
    @State private var scrollOffset: CGFloat = 0
    
    init(
        assetRepository: AssetRepositoryProtocol,
        movementRepository: MovementRepositoryProtocol
    ) {
        self._viewModel = StateObject(wrappedValue: ScannerViewModel(
            assetRepository: assetRepository,
            movementRepository: movementRepository
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    if cameraPermission == .authorized {
                        scannerView
                    } else {
                        permissionView
                    }
                }
            }
            .navigationTitle("Scanner")
            .navigationBarTitleDisplayMode(.inline)
            // Toolbar retiré - pas d'heure ni de bouton d'actualisation
        }
        .onAppear {
            checkCameraPermission()
        }
        .sheet(isPresented: $viewModel.showResult) {
            ScanResultView(
                result: viewModel.scanResult,
                onMovementAction: { type, assetId, from, to in
                    Task {
                        await viewModel.createMovement(
                            type: type,
                            assetId: assetId,
                            fromLocation: from,
                            toLocation: to
                        )
                    }
                },
                onScanAgain: {
                    viewModel.startScanning()
                }
            )
        }
        .sheet(isPresented: $viewModel.showModeSelector) {
            ScanModeSelectorView(
                onModeSelected: { mode, truck, event, assets in
                    viewModel.selectMode(mode, truck: truck, event: event, expectedAssets: assets)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showScanList) {
            ScanListView(viewModel: viewModel)
        }
        .alert("Erreur", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Une erreur est survenue")
        }
        .alert("Permission caméra requise", isPresented: $showingPermissionAlert) {
            Button("Paramètres") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("LogiScan a besoin d'accéder à la caméra pour scanner les QR codes.")
        }
    }
    
    private var scannerView: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera View
                QRScannerView(
                    scannedCode: $viewModel.scannedCode,
                    isScanning: $viewModel.isScanning,
                    onCodeScanned: viewModel.handleScannedCode
                )
                .clipShape(RoundedRectangle(cornerRadius: 0))
                
                // Overlay avec contrôles
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Session Progress (si applicable)
                    if let session = viewModel.currentSession, viewModel.currentMode != .free {
                        sessionProgressView(session: session)
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                            .transition(.move(edge: .bottom))
                    }
                    
                    // Sélecteur de mode horizontal (style appareil photo iOS)
                    CameraStyleModeSelectorView(
                        viewModel: viewModel,
                        showModeDetails: $showModeDetails
                    )
                    .frame(height: 120)
                    .background(
                        Rectangle()
                            .fill(.black.opacity(0.4))
                            .blur(radius: 20)
                    )
                }
                
                // Bouton liste (en haut à droite)
                if !viewModel.scanList.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                viewModel.showScanList = true
                            }) {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "list.clipboard")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                        
                                        // Badge avec nombre d'items
                                        if let expected = viewModel.currentSession?.expectedAssets {
                                            Text("\(viewModel.currentSession?.scannedAssets.count ?? 0)/\(expected.count)")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(4)
                                                .background(Circle().fill(Color.red))
                                                .offset(x: 18, y: -18)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 60)
                }
                
                // Success/Duplicate animations
                VStack {
                    Spacer()
                        .frame(height: geometry.size.height * 0.3)
                    
                    if viewModel.showSuccessAnimation {
                        successAnimationView
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    if viewModel.showDuplicateWarning {
                        duplicateWarningView
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Spacer()
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showSuccessAnimation)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showDuplicateWarning)
    }
    
    private var permissionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("Accès caméra requis")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("LogiScan a besoin d'accéder à votre caméra pour scanner les codes QR des assets.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Autoriser l'accès") {
                requestCameraPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
    }
    
    private func checkCameraPermission() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        
        if cameraPermission == .notDetermined {
            requestCameraPermission()
        } else if cameraPermission == .denied || cameraPermission == .restricted {
            showingPermissionAlert = true
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.cameraPermission = granted ? .authorized : .denied
                if granted {
                    self.viewModel.startScanning()
                } else {
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sessionProgressView(session: ScanSession) -> some View {
        VStack(spacing: 12) {
            // Progress Bar
            VStack(spacing: 8) {
                HStack {
                    Text("Progression")
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
        }
        .foregroundColor(.white)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
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
}

#Preview {
    // Preview simplifié avec modèles de base seulement
    let container = try! ModelContainer(
        for: StockItem.self, Asset.self, Movement.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    return ScannerMainView(
        assetRepository: PreviewAssetRepository(),
        movementRepository: PreviewMovementRepository()
    )
    .modelContainer(container)
}

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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let lastSync = syncManager.lastSyncDate {
                        Text(lastSync.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await syncManager.syncFromFirebaseIfNeeded(modelContext: modelContext, forceRefresh: true)
                            }
                        }) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.white)
                                .font(.title3)
                        }
                    }
                }
            }
        }
        .onAppear {
            checkCameraPermission()
            Task {
                await syncManager.syncFromFirebaseIfNeeded(modelContext: modelContext, forceRefresh: true)
            }
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
        ZStack {
            // Camera View
            QRScannerView(
                scannedCode: $viewModel.scannedCode,
                isScanning: $viewModel.isScanning,
                onCodeScanned: viewModel.handleScannedCode
            )
            .clipShape(RoundedRectangle(cornerRadius: 0))
            
            // Scan Overlay with mode indicator and controls
            ScanOverlayView(
                viewModel: viewModel,
                onShowList: {
                    viewModel.showScanList = true
                },
                onChangeMode: {
                    viewModel.showModeSelector = true
                }
            )
            
            // Mode Selector Floating Button
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        viewModel.showModeSelector = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: viewModel.currentMode.icon)
                                .font(.title2)
                            Text("Mode")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(
                            Circle()
                                .fill(viewModel.currentMode.gradient)
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        )
                    }
                    .padding()
                }
            }
        }
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

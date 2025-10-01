//
//  ScannerMainView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftUI
import SwiftData
import AVFoundation

struct ScannerMainView: View {
    @StateObject private var viewModel: ScannerViewModel
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if viewModel.isScanning {
                            viewModel.stopScanning()
                        } else {
                            viewModel.startScanning()
                        }
                    }) {
                        Image(systemName: viewModel.isScanning ? "pause.circle" : "play.circle")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .sheet(isPresented: $viewModel.showResult) {
            ScanResultView(
                result: viewModel.scanResult,
                onMovementAction: { type, from, to in
                    Task {
                        await viewModel.createMovement(
                            type: type,
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
        VStack {
            ZStack {
                QRScannerView(
                    scannedCode: $viewModel.scannedCode,
                    isScanning: $viewModel.isScanning,
                    onCodeScanned: viewModel.handleScannedCode
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            scanInstructionsOverlay
                            quickActionButtons
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                        .padding()
                    }
                }
            }
        }
    }
    
    private var scanInstructionsOverlay: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "qrcode.viewfinder")
                    .foregroundColor(.white)
                    .font(.title2)
                
                Text("Placez le QR code dans le cadre")
                    .foregroundColor(.white)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let lastCode = viewModel.scannedCode {
                Text("Dernier scan: \(lastCode.prefix(20))...")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption2)
            }
        }
    }
    
    private var quickActionButtons: some View {
        HStack(spacing: 12) {
            quickActionButton(
                icon: "cube.box",
                title: "Stock",
                action: {
                    // TODO: Navigation vers stock
                }
            )
            
            quickActionButton(
                icon: "truck",
                title: "Camions",
                action: {
                    // TODO: Navigation vers camions
                }
            )
            
            quickActionButton(
                icon: "list.clipboard",
                title: "Ordres",
                action: {
                    // TODO: Navigation vers ordres
                }
            )
        }
    }
    
    private func quickActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
            )
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

// Repositories de preview simplifiés
class PreviewAssetRepository: AssetRepositoryProtocol {
    func getAllAssets() async throws -> [Asset] { [] }
    func getAssetById(_ id: String) async throws -> Asset? { nil }
    func getAssetsByLocation(_ locationId: String) async throws -> [Asset] { [] }
    func getAssetsByEvent(_ eventId: String) async throws -> [Asset] { [] }
    func saveAsset(_ asset: Asset) async throws { }
    func deleteAsset(_ asset: Asset) async throws { }
    func updateAssetLocation(_ assetId: String, locationId: String?) async throws { }
    func updateAssetStatus(_ assetId: String, status: AssetStatus) async throws { }
    func searchAssets(_ query: String) async throws -> [Asset] { [] }
}

class PreviewMovementRepository: MovementRepositoryProtocol {
    func createMovement(_ movement: Movement) async throws { }
    func getMovementsByAsset(_ assetId: String) async throws -> [Movement] { [] }
    func getMovementsByEvent(_ eventId: String) async throws -> [Movement] { [] }
    func getUnsyncedMovements() async throws -> [Movement] { [] }
    func markMovementAsSynced(_ movementId: String) async throws { }
    func getRecentMovements(limit: Int) async throws -> [Movement] { [] }
}

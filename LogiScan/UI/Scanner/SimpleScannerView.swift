//
//  SimpleScannerView.swift
//  LogiScan
//
//  Created by Demeulemeester on 01/10/2025.
//

import SwiftUI
import SwiftData
import AVFoundation

struct SimpleScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var scannedCode: String? = nil
    @State private var isScanning = false
    @State private var isTorchOn = false
    @State private var showResult = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var showingPermissionAlert = false
    
    let onScanComplete: ((ScanResult) -> Void)?
    
    init(onScanComplete: ((ScanResult) -> Void)? = nil) {
        self.onScanComplete = onScanComplete
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
                    Button(action: toggleScanning) {
                        Image(systemName: isScanning ? "pause.circle" : "play.circle")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .sheet(isPresented: $showResult) {
            if let code = scannedCode {
                SimpleScanResultView(scannedCode: code) {
                    startScanning()
                }
            }
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Une erreur est survenue")
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
                    scannedCode: $scannedCode,
                    isScanning: $isScanning,
                    isTorchOn: $isTorchOn,
                    requiresTapToScan: true, // 🆕 Nécessite un tap
                    onCodeScanned: handleScannedCode
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        scanInstructionsOverlay
                        
                        // Statistiques simples
                        if let code = scannedCode, !code.isEmpty {
                            Text("Dernier scan: \(code.prefix(30))...")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var scanInstructionsOverlay: some View {
        HStack {
            Image(systemName: "qrcode.viewfinder")
                .foregroundColor(.white)
                .font(.title2)
            
            Text("Placez le QR code dans le cadre")
                .foregroundColor(.white)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                
                Text("LogiScan a besoin d'accéder à votre caméra pour scanner les codes QR.")
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
    
    private func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    private func startScanning() {
        isScanning = true
    }
    
    private func stopScanning() {
        isScanning = false
    }
    
    private func handleScannedCode(_ code: String) {
        scannedCode = code
        isScanning = false
        
        // Créer un ScanResult simple
        let scanResult = ScanResult(
            type: .unknown,
            title: "Code scanné",
            subtitle: code,
            status: "Détecté",
            statusColor: "blue",
            rawPayload: code
        )
        
        // Appeler le callback si présent
        if let onScanComplete = onScanComplete {
            onScanComplete(scanResult)
            dismiss()
        } else {
            showResult = true
        }
        
        // Feedback haptique
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("📱 Code scanné: \(code)")
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
                    self.startScanning()
                } else {
                    self.showingPermissionAlert = true
                }
            }
        }
    }
}

struct SimpleScanResultView: View {
    let scannedCode: String
    let onScanAgain: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Code scanné")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                // Contenu scanné
                VStack(spacing: 16) {
                    Text("Contenu:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(scannedCode)
                        .font(.body)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .textSelection(.enabled)
                }
                
                // Actions
                VStack(spacing: 16) {
                    Button("Scanner un autre code") {
                        dismiss()
                        onScanAgain()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Fermer") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Résultat du scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SimpleScannerView()
        .modelContainer(for: [StockItem.self, Asset.self, Movement.self, Event.self, Truck.self])
}

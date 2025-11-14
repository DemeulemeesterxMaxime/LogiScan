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
    @State private var scrollOffset: CGFloat = 0
    // ✅ SUPPRIMÉ - Variables pour tap instruction (scan automatique maintenant)
    @State private var isTorchOn = false  // État de la torche/flash
    
    // NOUVEAU : Bandeau de sélection de mode - toujours démarrer en mode libre
    @State private var selectedMode: ScannerMode = .free
    @State private var selectedEvent: Event? = nil
    @State private var selectedScanList: ScanList? = nil
    @State private var showListManagement = false
    
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
                // Dégradé de fond moderne
                backgroundGradient
                
                mainContent
            }
            .navigationTitle("Scanner")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            checkCameraPermission()
            // 🆕 Toujours réinitialiser en mode "Scan libre" à l'ouverture
            selectedMode = .free
            selectedEvent = nil
            selectedScanList = nil
            
            // 🆕 Passer le ModelContext au ViewModel
            viewModel.setModelContext(modelContext)
        }
        .sheet(isPresented: $viewModel.showResult) {
            scanResultSheet
        }
        .sheet(isPresented: $showListManagement) {
            ScanListBrowserView()
        }
        .sheet(isPresented: $viewModel.showInventoryList) {
            if let session = viewModel.currentInventorySession {
                InventoryListView(session: session)
            }
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
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemGray6),  // Adaptatif : clair en mode clair, foncé en mode sombre
                Color(.systemGray5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            if cameraPermission == .authorized {
                // Bandeau de sélection de mode
                ScanModeBanner(
                    selectedMode: $selectedMode,
                    selectedEvent: $selectedEvent,
                    selectedScanList: $selectedScanList,
                    onModeChange: {
                        handleModeChange()
                    }
                )
                .background(Color(.systemBackground))
                
                // NextItemIndicator pour mode Événement (au-dessus du scanner)
                if selectedMode == .event, let scanList = selectedScanList {
                    NextItemIndicator(scanList: scanList)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                }
                
                // Barre de progression pour mode Inventaire uniquement
                inventoryProgressSection
                
                // Vue scanner
                scannerView
                
                // Bouton flottant pour gérer la liste (mode Event uniquement)
                if selectedMode == .event && selectedScanList != nil {
                    floatingManageButton
                }
            } else {
                permissionView
            }
        }
    }
    
    private var inventoryProgressSection: some View {
        Group {
            if selectedMode == .inventory, let invSession = viewModel.currentInventorySession {
                let scannedCount = invSession.totalCount
                
                HStack {
                    Label("Inventaire", systemImage: "list.clipboard")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(scannedCount) scannés")
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)
                    
                    // Bouton pour voir la liste
                    Button {
                        viewModel.showInventoryList = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Voir")
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
        }
    }
    
    private var scanResultSheet: some View {
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
                // ✅ Redémarrer le scan automatiquement
                viewModel.startScanning()
            }
        )
    }
    
    private var scannerView: some View {
        GeometryReader { geometry in
            ZStack {
                // ✅ Nouvelle interface de scan moderne
                ModernQRScannerView(
                    isScanning: $viewModel.isScanning,
                    isTorchOn: $isTorchOn,
                    onCodeScanned: viewModel.handleScannedCode
                )
                
                // Overlay avec contrôles
                VStack(spacing: 0) {
                    // Header avec mode actuel
                    currentModeHeader
                        .padding(.top, 8)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.7),
                                    Color.black.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Espace pour NextItemIndicator en mode Event
                    if selectedMode == .event {
                        Spacer()
                            .frame(height: 60)
                    }
                    
                    Spacer()
                    
                    // ✅ SUPPRIMÉ - Plus besoin d'instruction pour taper
                    // Le scan est maintenant automatique
                    
                    Spacer()
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
            // ✅ SUPPRIMÉ - Plus besoin de tap gesture, le scan est automatique
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showSuccessAnimation)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showDuplicateWarning)
    }
    
    private var permissionView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icône animée
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse)
            }
            
            VStack(spacing: 16) {
                Text("Accès caméra requis")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("LogiScan utilise la caméra pour scanner les codes QR et codes-barres de vos assets. Cette fonctionnalité est essentielle pour le suivi de votre matériel.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    requestCameraPermission()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text("Autoriser l'accès")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                
                Button(action: {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }) {
                    Text("Ouvrir les réglages")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Info supplémentaire
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundColor(.green.opacity(0.8))
                
                Text("Vos données restent privées et sécurisées")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Floating Controls Bar
    
    private var floatingManageButton: some View {
        VStack {
            Spacer()
            
            // Indicateur "Prêt à scanner" au-dessus des boutons
            if viewModel.isScanning {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(viewModel.isScanning ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isScanning)
                    
                    Text("Prêt à scanner")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom, 16)
            }
            
            // Barre de contrôles flottante avec tous les boutons
            HStack(spacing: 40) {
                // Bouton Gérer la liste (gauche)
                Button {
                    showListManagement = true
                } label: {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.orange))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                
                // Bouton Scanner central (plus gros)
                // ✅ SUPPRIMÉ - Le scan est automatique, pas besoin de bouton
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .fill(
                            viewModel.isScanning ? 
                                viewModel.currentMode.gradient :
                                LinearGradient(colors: [.gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 68, height: 68)
                    
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title)
                        .foregroundColor(.white)
                        .symbolEffect(.pulse, isActive: viewModel.isScanning)
                }
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                
                // Bouton Flash (droite)
                Button(action: {
                    isTorchOn.toggle()
                }) {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title2)
                        .foregroundStyle(isTorchOn ? .yellow : .white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(isTorchOn ? Color.yellow.opacity(0.3) : Color.white.opacity(0.2)))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)  // Réduit de 60 à 20 pour coller presque à la tabbar
        }
    }
    
    // MARK: - Handle Mode Change
    
    private func handleModeChange() {
        // Réinitialiser le scanner
        viewModel.stopScanning()
        
        // ✅ Réinitialiser le ViewModel pour éviter les états mixtes
        viewModel.currentActiveScanList = nil
        
        // Adapter le ViewModel selon le mode
        switch selectedMode {
        case .free:
            // Mode libre : pas de contexte spécifique
            viewModel.selectMode(.free, truck: nil, event: nil, expectedAssets: nil)
            
        case .inventory:
            // Mode inventaire : compter les assets
            viewModel.selectMode(.inventory, truck: nil, event: nil, expectedAssets: nil)
            
        case .event:
            // Mode événement : utiliser la liste sélectionnée
            if let event = selectedEvent, let scanList = selectedScanList {
                // Utiliser un mode approprié selon le LogisticsStatus de l'événement
                let scanMode = determineScanMode(for: event)
                // Définir la liste active dans le ViewModel
                viewModel.currentActiveScanList = scanList
                viewModel.selectMode(scanMode, truck: nil, event: event, expectedAssets: nil)
            }
        }
    }
    
    private func determineScanMode(for event: Event) -> ScanMode {
        // Déterminer le mode de scan selon le statut logistique
        switch event.logisticsStatus {
        case .inStock, .loadingToTruck:
            return .stockToTruck
        case .inTransitToEvent:
            return .stockToTruck
        case .onSite:
            return .truckToEvent
        case .loadingFromEvent, .inTransitToStock:
            return .eventToTruck
        case .returned:
            return .truckToStock
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
    
    // ✅ SUPPRIMÉ - handleScreenTap() n'est plus nécessaire avec le scan automatique
    
    // MARK: - Helper Views
    
    // ✅ SUPPRIMÉ - Plus besoin d'instruction pour taper
    
    // MARK: - Helper Views
    
    private var currentModeHeader: some View {
        HStack(spacing: 12) {
            // Icône du mode
            ZStack {
                Circle()
                    .fill(viewModel.currentMode.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: viewModel.currentMode.icon)
                    .font(.title3)
                    .foregroundColor(viewModel.currentMode.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentMode.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(modeDescription)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Nom événement + Bouton Changer pour mode Event
            if selectedMode == .event, let event = selectedEvent {
                HStack(spacing: 8) {
                    // Nom de l'événement
                    Text(event.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // Bouton Changer d'événement
                    Button(action: {
                        showListManagement = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.caption2)
                            Text("Changer")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.2))
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var modeDescription: String {
        switch viewModel.currentMode {
        case .free:
            return "Scan libre - Informations uniquement"
        case .inventory:
            return "Inventaire - Comptage en masse"
        case .stockToTruck:
            return "Chargement camion"
        case .truckToEvent:
            return "Déchargement sur site"
        case .eventToTruck:
            return "Rechargement camion"
        case .truckToStock:
            return "Retour entrepôt"
        }
    }
    
    private var bottomControlsView: some View {
        VStack(spacing: 16) {
            // Boutons d'action rapide
            HStack(spacing: 20) {
                // Voir la liste
                if !viewModel.scanList.isEmpty {
                    Button(action: {
                        viewModel.showScanList = true
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: "list.bullet")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                // Badge
                                if viewModel.currentSession?.expectedAssets != nil {
                                    Text("\(viewModel.currentSession?.scannedAssets.count ?? 0)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Circle().fill(Color.blue))
                                        .offset(x: 20, y: -20)
                                }
                            }
                            
                            Text("Liste")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                
                Spacer()
                
                // Bouton scanner central (indicateur visuel uniquement)
                // ✅ MODIFIÉ - Le scan est automatique, juste un indicateur visuel
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    
                    Circle()
                        .fill(
                            viewModel.isScanning ? 
                                viewModel.currentMode.gradient :
                                LinearGradient(colors: [.gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(.white)
                        .symbolEffect(.pulse, isActive: viewModel.isScanning)
                }
                
                Spacer()
                
                // Torche
                Button(action: {
                    isTorchOn.toggle()
                }) {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(isTorchOn ? Color.yellow.opacity(0.3) : Color.white.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                    .font(.title2)
                                    .foregroundColor(isTorchOn ? .yellow : .white)
                            )
                        
                        Text("Flash")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, 32)
            
            // Indicateur de scan
            if viewModel.isScanning {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(viewModel.isScanning ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isScanning)
                    
                    Text("Prêt à scanner")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            // ✅ SUPPRIMÉ - Message "Touchez pour activer" obsolète
        }
        .padding(.vertical, 12)
    }
    
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

// MARK: - Scanning Frame Overlay

struct ScanningFrameOverlay: View {
    @State private var isAnimating = false
    let topOffset: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            // Calculer la zone de scan verticale (format portrait)
            let availableHeight = geometry.size.height - topOffset
            let scanZoneHeight = availableHeight * 0.75  // 75% de la hauteur disponible
            let scanZoneTop = topOffset + (availableHeight - scanZoneHeight) / 2
            let scanZoneCenter = scanZoneTop + (scanZoneHeight / 2) + 20  // Descendu de 20px pour centrer visuellement
            
            let frameSize: CGFloat = 240  // Réduit de 280 à 240
            
            ZStack {
                // Coins du cadre
                VStack {
                    HStack {
                        CornerShape(corner: .topLeft)
                        Spacer()
                        CornerShape(corner: .topRight)
                    }
                    Spacer()
                    HStack {
                        CornerShape(corner: .bottomLeft)
                        Spacer()
                        CornerShape(corner: .bottomRight)
                    }
                }
                .frame(width: frameSize, height: frameSize)
                
                // Ligne de scan animée
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0),
                                Color.blue.opacity(0.8),
                                Color.blue.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: frameSize, height: 2)
                    .offset(y: isAnimating ? frameSize/2 : -frameSize/2)
                    .animation(
                        .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            .position(
                x: geometry.size.width / 2,
                y: scanZoneCenter  // Centré dans la zone de scan verticale et remonté
            )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct CornerShape: View {
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let corner: Corner
    
    var body: some View {
        ZStack {
            switch corner {
            case .topLeft:
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 40, height: 4)
                        Spacer()
                    }
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 4, height: 40)
                        Spacer()
                    }
                    Spacer()
                }
            case .topRight:
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 40, height: 4)
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 4, height: 40)
                    }
                    Spacer()
                }
            case .bottomLeft:
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 4, height: 40)
                        Spacer()
                    }
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 40, height: 4)
                        Spacer()
                    }
                }
            case .bottomRight:
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 4, height: 40)
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 40, height: 4)
                    }
                }
            }
        }
        .frame(width: 44, height: 44)
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

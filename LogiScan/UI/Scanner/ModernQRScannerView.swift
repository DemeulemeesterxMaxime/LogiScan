//
//  ModernQRScannerView.swift
//  LogiScan
//
//  Created by Assistant on 07/11/2025.
//  Interface de scan moderne avec zone de scan et arrière-plan grisé
//

import SwiftUI
import AVFoundation

/// Vue de scan QR moderne avec interface améliorée
/// Utilise AVFoundation avec une UI SwiftUI moderne
struct ModernQRScannerView: View {
    @Binding var isScanning: Bool
    @Binding var isTorchOn: Bool
    let onCodeScanned: (String) -> Void
    let onShowList: (() -> Void)? // ✅ Callback optionnel pour afficher la liste
    
    @State private var scannedCode: String?
    @State private var showScanAnimation = false
    
    init(
        isScanning: Binding<Bool>,
        isTorchOn: Binding<Bool>,
        onCodeScanned: @escaping (String) -> Void,
        onShowList: (() -> Void)? = nil
    ) {
        self._isScanning = isScanning
        self._isTorchOn = isTorchOn
        self.onCodeScanned = onCodeScanned
        self.onShowList = onShowList
    }
    
    var body: some View {
        ZStack {
            // Caméra en plein écran
            QRScannerView(
                scannedCode: $scannedCode,
                isScanning: $isScanning,
                isTorchOn: $isTorchOn,
                requiresTapToScan: false,  // ✅ Scan automatique - pas besoin de tap
                onCodeScanned: handleScan
            )
            .ignoresSafeArea()
            
            // Zone de scan avec coins uniquement (pas de fond sombre)
            scanFrameOnly
            
            // Contrôles de scan
            VStack {
                Spacer()
                
                scanControls
                    .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())  // ✅ Permet le tap sur toute la vue
        .onTapGesture {
            // Le tap déclenche le scan si arrêté
            if !isScanning {
                withAnimation(.spring(response: 0.3)) {
                    isScanning = true
                }
            }
        }
    }
    
    // MARK: - Scan Frame Only (coins uniquement, pas de fond sombre)
    
    private var scanFrameOnly: some View {
        GeometryReader { geometry in
            let scanSize = geometry.size.width * 0.7
            let scanRect = CGRect(
                x: (geometry.size.width - scanSize) / 2,
                y: (geometry.size.height - scanSize) / 2,
                width: scanSize,
                height: scanSize
            )
            
            ZStack {
                // Coins colorés uniquement
                ScanCorners(rect: scanRect)
                
                // Ligne de scan animée
                if isScanning {
                    ScanningLine(rect: scanRect, isAnimating: $showScanAnimation)
                }
                
                // Texte d'instruction au-dessus de la zone
                Text("Placez le QR code dans le cadre")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                            .shadow(radius: 10)
                    )
                    .position(
                        x: scanRect.midX,
                        y: scanRect.minY - 40
                    )
            }
            .onAppear {
                showScanAnimation = true
            }
        }
    }
    
    // MARK: - Scan Overlay (OLD - Not used anymore)
    
    private var scanOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Fond sombre avec découpe pour la zone de scan
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .mask {
                        Rectangle()
                            .overlay {
                                scanWindowMask(in: geometry)
                                    .blendMode(.destinationOut)
                            }
                    }
                
                // Zone de scan avec bordures
                scanFrame(in: geometry)
            }
        }
    }
    
    private func scanWindowMask(in geometry: GeometryProxy) -> some View {
        let scanSize = geometry.size.width * 0.7
        let scanRect = CGRect(
            x: (geometry.size.width - scanSize) / 2,
            y: (geometry.size.height - scanSize) / 2,
            width: scanSize,
            height: scanSize
        )
        
        return RoundedRectangle(cornerRadius: 20)
            .frame(width: scanRect.width, height: scanRect.height)
            .position(x: scanRect.midX, y: scanRect.midY)
    }
    
    private func scanFrame(in geometry: GeometryProxy) -> some View {
        let scanSize = geometry.size.width * 0.7
        let scanRect = CGRect(
            x: (geometry.size.width - scanSize) / 2,
            y: (geometry.size.height - scanSize) / 2,
            width: scanSize,
            height: scanSize
        )
        
        return ZStack {
            // Bordure principale
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: scanRect.width, height: scanRect.height)
                .position(x: scanRect.midX, y: scanRect.midY)
            
            // Coins colorés
            ScanCorners(rect: scanRect)
            
            // Ligne de scan animée
            if isScanning {
                ScanningLine(rect: scanRect, isAnimating: $showScanAnimation)
            }
            
            // Texte d'instruction au-dessus de la zone
            Text("Placez le QR code dans le cadre")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                        .shadow(radius: 10)
                )
                .position(
                    x: scanRect.midX,
                    y: scanRect.minY - 40
                )
        }
        .onAppear {
            showScanAnimation = true
        }
    }
    
    // MARK: - Controls
    
    private var scanControls: some View {
        HStack(spacing: 30) {
            // Bouton Flash
            Button {
                isTorchOn.toggle()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title2)
                    Text(isTorchOn ? "Actif" : "Flash")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(isTorchOn ? Color.yellow.opacity(0.3) : Color.white.opacity(0.2))
                        .shadow(color: isTorchOn ? .yellow.opacity(0.3) : .clear, radius: 10)
                )
            }
            
            // Bouton Scan (principal)
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isScanning.toggle()
                }
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                            .frame(width: 70, height: 70)
                        
                        if isScanning {
                            Circle()
                                .trim(from: 0, to: 0.8)
                                .stroke(Color.green, lineWidth: 3)
                                .frame(width: 70, height: 70)
                                .rotationEffect(.degrees(isScanning ? 360 : 0))
                                .animation(
                                    .linear(duration: 1).repeatForever(autoreverses: false),
                                    value: isScanning
                                )
                        }
                        
                        Image(systemName: isScanning ? "stop.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(isScanning ? .green : .white)
                    }
                    
                    Text(isScanning ? "Arrêter" : "Scanner")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            // Bouton Liste
            if let onShowList = onShowList {
                Button {
                    onShowList()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.title2)
                        Text("Liste")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.2))
                    )
                }
            }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Actions
    
    private func handleScan(_ code: String) {
        // Animation de succès
        withAnimation(.spring()) {
            showScanAnimation = false
        }
        
        // Feedback haptique
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Callback
        onCodeScanned(code)
        
        // Redémarrer l'animation après un court délai
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showScanAnimation = true
            }
        }
    }
}

// MARK: - Scan Corners

struct ScanCorners: View {
    let rect: CGRect
    let cornerLength: CGFloat = 40
    let cornerWidth: CGFloat = 5
    
    var body: some View {
        ZStack {
            // Top-left
            ScanCornerShape(corner: .topLeft)
                .fill(Color.blue)
                .frame(width: cornerLength, height: cornerLength)
                .position(x: rect.minX, y: rect.minY)
            
            // Top-right
            ScanCornerShape(corner: .topRight)
                .fill(Color.blue)
                .frame(width: cornerLength, height: cornerLength)
                .position(x: rect.maxX, y: rect.minY)
            
            // Bottom-left
            ScanCornerShape(corner: .bottomLeft)
                .fill(Color.blue)
                .frame(width: cornerLength, height: cornerLength)
                .position(x: rect.minX, y: rect.maxY)
            
            // Bottom-right
            ScanCornerShape(corner: .bottomRight)
                .fill(Color.blue)
                .frame(width: cornerLength, height: cornerLength)
                .position(x: rect.maxX, y: rect.maxY)
        }
    }
}

// MARK: - Corner Shape

struct ScanCornerShape: Shape {
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let corner: Corner
    let thickness: CGFloat = 5
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch corner {
        case .topLeft:
            // Horizontal
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: thickness))
            path.addLine(to: CGPoint(x: thickness, y: thickness))
            path.addLine(to: CGPoint(x: thickness, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
            
        case .topRight:
            // Horizontal
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width - thickness, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width - thickness, y: thickness))
            path.addLine(to: CGPoint(x: 0, y: thickness))
            path.closeSubpath()
            
        case .bottomLeft:
            // Horizontal
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: thickness, y: 0))
            path.addLine(to: CGPoint(x: thickness, y: rect.height - thickness))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - thickness))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
            
        case .bottomRight:
            // Horizontal
            path.move(to: CGPoint(x: 0, y: rect.height - thickness))
            path.addLine(to: CGPoint(x: rect.width - thickness, y: rect.height - thickness))
            path.addLine(to: CGPoint(x: rect.width - thickness, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
        
        return path
    }
}

// MARK: - Scanning Line

struct ScanningLine: View {
    let rect: CGRect
    @Binding var isAnimating: Bool
    @State private var offset: CGFloat = 0
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0),
                        Color.blue,
                        Color.blue.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: rect.width - 40, height: 3)
            .position(x: rect.midX, y: rect.minY + offset)
            .onAppear {
                withAnimation(
                    .linear(duration: 2)
                        .repeatForever(autoreverses: true)
                ) {
                    offset = rect.height - 20
                }
            }
            .onChange(of: isAnimating) { _, newValue in
                if !newValue {
                    offset = 0
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ModernQRScannerView(
        isScanning: .constant(true),
        isTorchOn: .constant(false),
        onCodeScanned: { code in
            print("Scanned: \(code)")
        }
    )
}

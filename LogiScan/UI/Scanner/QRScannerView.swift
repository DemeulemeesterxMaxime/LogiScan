//
//  QRScannerView.swift
//  LogiScan
//
//  Created by Demeulemeester on 30/09/2025.
//

import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool
    @Binding var isTorchOn: Bool
    let onCodeScanned: (String) -> Void
    let requiresTapToScan: Bool // 🆕 Nécessite un tap pour scanner
    
    init(
        scannedCode: Binding<String?>,
        isScanning: Binding<Bool>,
        isTorchOn: Binding<Bool>,
        requiresTapToScan: Bool = true, // ✅ Retour au tap requis par défaut
        onCodeScanned: @escaping (String) -> Void
    ) {
        self._scannedCode = scannedCode
        self._isScanning = isScanning
        self._isTorchOn = isTorchOn
        self.requiresTapToScan = requiresTapToScan
        self.onCodeScanned = onCodeScanned
    }
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        controller.requiresTapToScan = requiresTapToScan
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
        
        // Synchroniser l'état de la torche
        if isTorchOn != uiViewController.isTorchOn {
            uiViewController.toggleTorch()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRScannerView
        
        init(_ parent: QRScannerView) {
            self.parent = parent
        }
        
        func didScanCode(_ code: String) {
            DispatchQueue.main.async {
                self.parent.scannedCode = code
                self.parent.onCodeScanned(code)
            }
        }
        
        func didFailWithError(_ error: Error) {
            print("QR Scanner error: \(error)")
        }
    }
}

protocol QRScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didFailWithError(_ error: Error)
}

class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerDelegate?
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var videoCaptureDevice: AVCaptureDevice?
    private var isSessionRunning = false
    var isTorchOn = false  // Public pour SwiftUI
    var requiresTapToScan = true // 🆕 Nécessite un tap pour scanner
    private var canScan = false // 🆕 Contrôle si le scan est autorisé
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
        
        // Autoriser le scan automatiquement
        canScan = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopScanning()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError(QRScannerError.noCameraAvailable)
            return
        }
        
        videoCaptureDevice = device
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: device)
        } catch {
            delegate?.didFailWithError(error)
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didFailWithError(QRScannerError.cannotAddInput)
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417]
        } else {
            delegate?.didFailWithError(QRScannerError.cannotAddOutput)
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // ✅ NE PLUS ajouter d'overlay ici - géré par SwiftUI ModernQRScannerView
    }
    
    func startScanning() {
        guard !isSessionRunning else { return }
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }
    
    func stopScanning() {
        guard isSessionRunning else { return }
        
        // Éteindre la torche avant d'arrêter
        if isTorchOn {
            toggleTorch()
        }
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    func toggleTorch() {
        guard let device = videoCaptureDevice,
              device.hasTorch else {
            print("⚠️ Torche non disponible")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if isTorchOn {
                device.torchMode = .off
                isTorchOn = false
                print("💡 Torche désactivée")
            } else {
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
                print("💡 Torche activée")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("❌ Erreur torche: \(error)")
        }
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard let metadataObject = metadataObjects.first else { return }
        guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
        guard let stringValue = readableObject.stringValue else { return }
        
        // ✅ Si le tap n'est pas requis, le scan est toujours autorisé
        if !requiresTapToScan {
            canScan = true
        }
        
        // 🆕 Vérifier si le scan est autorisé
        guard canScan else {
            print("⏸️ Scan détecté mais ignoré - Scan automatique activé")
            return
        }
        
        // Désactiver le scan après avoir scanné (nécessitera un nouveau tap si requis)
        if requiresTapToScan {
            canScan = false
            print("🔒 Scan désactivé - Tapez à nouveau pour scanner")
        }
        
        // Feedback haptique
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        delegate?.didScanCode(stringValue)
    }
}

enum QRScannerError: Error, LocalizedError {
    case noCameraAvailable
    case cannotAddInput
    case cannotAddOutput
    
    var errorDescription: String? {
        switch self {
        case .noCameraAvailable:
            return "Caméra non disponible"
        case .cannotAddInput:
            return "Impossible d'ajouter l'entrée caméra"
        case .cannotAddOutput:
            return "Impossible d'ajouter la sortie de métadonnées"
        }
    }
}

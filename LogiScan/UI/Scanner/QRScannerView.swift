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
    let onCodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
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
    private var isSessionRunning = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopScanning()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError(QRScannerError.noCameraAvailable)
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
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
        
        // Ajouter un overlay pour indiquer la zone de scan
        setupScanOverlay()
    }
    
    private func setupScanOverlay() {
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        let scanRect = CGRect(
            x: view.bounds.width * 0.1,
            y: view.bounds.height * 0.3,
            width: view.bounds.width * 0.8,
            height: view.bounds.width * 0.8
        )
        
        let scanWindow = UIBezierPath(rect: scanRect)
        let fullPath = UIBezierPath(rect: view.bounds)
        fullPath.append(scanWindow)
        fullPath.usesEvenOddFillRule = true
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = fullPath.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
        
        // Ajouter des coins pour indiquer la zone de scan
        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 4
        
        let corners = [
            // Top-left
            CGRect(x: scanRect.minX, y: scanRect.minY, width: cornerLength, height: cornerWidth),
            CGRect(x: scanRect.minX, y: scanRect.minY, width: cornerWidth, height: cornerLength),
            // Top-right
            CGRect(x: scanRect.maxX - cornerLength, y: scanRect.minY, width: cornerLength, height: cornerWidth),
            CGRect(x: scanRect.maxX - cornerWidth, y: scanRect.minY, width: cornerWidth, height: cornerLength),
            // Bottom-left
            CGRect(x: scanRect.minX, y: scanRect.maxY - cornerWidth, width: cornerLength, height: cornerWidth),
            CGRect(x: scanRect.minX, y: scanRect.maxY - cornerLength, width: cornerWidth, height: cornerLength),
            // Bottom-right
            CGRect(x: scanRect.maxX - cornerLength, y: scanRect.maxY - cornerWidth, width: cornerLength, height: cornerWidth),
            CGRect(x: scanRect.maxX - cornerWidth, y: scanRect.maxY - cornerLength, width: cornerWidth, height: cornerLength)
        ]
        
        for corner in corners {
            let cornerView = UIView(frame: corner)
            cornerView.backgroundColor = .systemBlue
            overlayView.addSubview(cornerView)
        }
        
        view.addSubview(overlayView)
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
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard let metadataObject = metadataObjects.first else { return }
        guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
        guard let stringValue = readableObject.stringValue else { return }
        
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

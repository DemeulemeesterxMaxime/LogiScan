//
//  ScanListView.swift
//  LogiScan
//
//  Created by Demeulemeester on 13/10/2025.
//

import SwiftUI

struct ScanListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ScannerViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress Header
                    progressHeader
                    
                    // Scan List
                    if viewModel.scanList.isEmpty {
                        emptyState
                    } else {
                        scanListContent
                    }
                }
            }
            .navigationTitle("Liste de Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let session = viewModel.currentSession, session.isComplete {
                        Button(action: {
                            viewModel.endCurrentSession()
                            dismiss()
                        }) {
                            Text("Terminer")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var progressHeader: some View {
        VStack(spacing: 16) {
            // Progress Ring
            if let session = viewModel.currentSession {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 12)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: session.progress)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: session.progress)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(session.progress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(session.scannedAssets.count)/\(session.expectedAssets?.count ?? 0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
                
                // Mode Badge
                HStack {
                    Image(systemName: viewModel.currentMode.icon)
                    Text(viewModel.currentMode.displayName)
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(viewModel.currentMode.color.opacity(0.2))
                )
                .foregroundColor(viewModel.currentMode.color)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    private var scanListContent: some View {
        List {
            ForEach(viewModel.scanList) { item in
                ScanListItemRow(item: item)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Aucune liste de scan")
                .font(.headline)
            
            Text("Commencez à scanner des assets pour les voir apparaître ici")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Scan List Item Row

struct ScanListItemRow: View {
    let item: ScanListItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(item.isScanned ? Color.green.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 40, height: 40)
                
                Image(systemName: item.isScanned ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isScanned ? .green : .secondary)
            }
            
            // Asset Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(item.isScanned ? .secondary : .primary)
                
                HStack {
                    Text("SKU: \(item.sku)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let serialNumber = item.serialNumber {
                        Text("• SN: \(serialNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let scannedAt = item.scannedAt {
                    Text("Scanné à \(scannedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Chevron
            if !item.isScanned {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .opacity(item.isScanned ? 0.6 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    let viewModel = ScannerViewModel(
        assetRepository: PreviewAssetRepository(),
        movementRepository: PreviewMovementRepository()
    )
    
    // Simuler une session avec des items
    viewModel.scanList = [
        ScanListItem(
            asset: Asset(
                assetId: "A001",
                sku: "LED-SPOT-50W",
                name: "Projecteur LED 50W",
                category: "Éclairage",
                weight: 2.5,
                volume: 0.01,
                value: 150.0,
                qrPayload: ""
            ),
            isScanned: true
        ),
        ScanListItem(
            asset: Asset(
                assetId: "A002",
                sku: "LED-PAR-64",
                name: "Projecteur PAR 64",
                category: "Éclairage",
                weight: 3.0,
                volume: 0.015,
                value: 200.0,
                qrPayload: ""
            ),
            isScanned: false
        )
    ]
    
    return ScanListView(viewModel: viewModel)
}

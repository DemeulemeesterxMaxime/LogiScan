//
//  LoadingView.swift
//  LogiScan
//
//  Created by Demeulemeester on 15/10/2025.
//

import SwiftUI

struct LoadingView: View {
    var message: String = "Chargement de votre profil..."
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {
    LoadingView()
}

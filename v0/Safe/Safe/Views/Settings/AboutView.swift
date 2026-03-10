//
//  AboutView.swift
//  Safe

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.checkerboard")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Safe")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .foregroundColor(.secondary)
            
            Text("Application de sécurité personnelle développée pour votre protection.")
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
        }
        .padding()
        .navigationTitle("À propos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AboutView()
}

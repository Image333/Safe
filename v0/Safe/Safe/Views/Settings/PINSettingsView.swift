//
//  PINSettingsView.swift
//  Safe

import SwiftUI

struct PINSettingsView: View {
    var body: some View {
        VStack {
            Text("Configuration du code PIN")
                .font(.title2)
                .padding()
            
            Text("Fonctionnalité à implémenter")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .navigationTitle("Code PIN")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    PINSettingsView()
}

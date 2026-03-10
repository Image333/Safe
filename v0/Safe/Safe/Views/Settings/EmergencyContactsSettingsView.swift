//
//  EmergencyContactsSettingsView.swift
//  Safe

import SwiftUI

struct EmergencyContactsSettingsView: View {
    var body: some View {
        VStack {
            Text("Gestion des contacts d'urgence")
                .font(.title2)
                .padding()
            
            Text("Fonctionnalité à implémenter")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .navigationTitle("Contacts d'urgence")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    EmergencyContactsSettingsView()
}

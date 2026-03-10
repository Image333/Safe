//
//  HelpView.swift
//  Safe

import SwiftUI

struct HelpView: View {
    var body: some View {
        List {
            Section("Utilisation") {
                Text("Comment utiliser l'alerte d'urgence")
                Text("Configurer vos contacts")
                Text("Partager votre localisation")
            }
            
            Section("Dépannage") {
                Text("Problèmes de notifications")
                Text("Problèmes de localisation")
                Text("Autres problèmes")
            }
            
            Section("Contact") {
                Text("support@safe-app.com")
                    .foregroundColor(.blue)
            }
        }
        .navigationTitle("Aide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HelpView()
}

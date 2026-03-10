//
//  AuthTestView.swift
//  Safe
//
//  Created by Imane on 08/09/2025.
//

import SwiftUI

struct AuthTestView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Test des Vues d'Authentification")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                
                VStack(spacing: 20) {
                    NavigationLink(destination: AuthenticationView()) {
                        TestButton(title: "Vue d'Authentification", icon: "lock.fill", color: .blue)
                    }
                    
                    NavigationLink(destination: AuthenticationView()) {
                        TestButton(title: "Test Complet", icon: "person.badge.plus", color: .green)
                    }
                    
                    NavigationLink(destination: ForgotPasswordView()) {
                        TestButton(title: "Mot de Passe Oublié", icon: "key.fill", color: .orange)
                    }
                    
                    NavigationLink(destination: AuthenticationView()) {
                        TestButton(title: "Vue Combinée (Onglets)", icon: "rectangle.grid.1x2", color: .purple)
                    }
                }
                .padding()
                
                Spacer()
                
                VStack(spacing: 10) {
                    Text("💡 Conseils de test :")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("• Utilisez 'test@example.com' ou 'admin@safe.com' pour tester la connexion")
                        Text("• Mot de passe minimum 6 caractères")
                        Text("• Les boutons Google/Apple sont simulés")
                        Text("• L'email 'admin@safe.com' simule un compte existant")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Tests Auth")
        }
    }
}

struct TestButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [color, color.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(radius: 3)
    }
}

#Preview {
    AuthTestView()
        .environmentObject(AuthManager())
}

//
//  NetworkTestView.swift
//  Safe
//
//  Created for debugging network connectivity
//

import SwiftUI

struct NetworkTestView: View {
    @State private var isTestingConnection = false
    @State private var connectionStatus = "Non testé"
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let apiService = APIService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test de Connectivité Réseau")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("URL du serveur:")
                    .font(.headline)
                Text(AppConfig.baseURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 15) {
                HStack {
                    Text("Status:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(connectionStatus)
                        .foregroundColor(connectionStatus == "✅ Connecté" ? .green : 
                                       connectionStatus == "❌ Échec" ? .red : .orange)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Button(action: {
                    testConnection()
                }) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isTestingConnection ? "Test en cours..." : "Tester la connexion")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isTestingConnection)
            }
            
            Spacer()
        }
        .padding()
        .alert("Résultat du test", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionStatus = "🔄 Test en cours..."
        
        Task {
            do {
                let success = try await apiService.testConnection()
                await MainActor.run {
                    if success {
                        connectionStatus = "✅ Connecté"
                        alertMessage = "Connexion au serveur réussie !"
                    } else {
                        connectionStatus = "❌ Échec"
                        alertMessage = "Le serveur a répondu mais avec un statut inattendu"
                    }
                    isTestingConnection = false
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    connectionStatus = "❌ Échec"
                    alertMessage = "Erreur: \(error.localizedDescription)"
                    isTestingConnection = false
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    NetworkTestView()
}

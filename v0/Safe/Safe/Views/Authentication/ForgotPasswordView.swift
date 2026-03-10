//
//  ForgotPasswordView.swift
//  Safe
//
//  Created by Imane on 08/09/2025.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                
                // En-tête
                VStack(spacing: 20) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Mot de passe oublié")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Entrez votre adresse email et nous vous enverrons un lien pour réinitialiser votre mot de passe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 50)
                
                // Formulaire ou confirmation
                if !isSuccess {
                    VStack(spacing: 25) {
                        // Champ email
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Adresse email")
                                .font(.headline)
                            
                            TextField("Entrez votre email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disabled(isLoading)
                        }
                        .padding(.horizontal, 30)
                        
                        // Bouton d’envoi
                        Button(action: {
                            sendResetEmail()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text(isLoading ? "Envoi en cours..." : "Envoyer le lien")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(email.isEmpty || isLoading || !isValidEmail(email))
                        .opacity((email.isEmpty || isLoading || !isValidEmail(email)) ? 0.6 : 1.0)
                        .padding(.horizontal, 30)
                    }
                } else {
                    // Confirmation après succès
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Email envoyé !")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("Un lien de réinitialisation a été envoyé à :")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(email)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Vérifiez votre boîte de réception et vos spams")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button("Renvoyer l'email") {
                            sendResetEmail()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 30)
                }
                
                Spacer()
                
                // Retour connexion
                Button("Retour à la connexion") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.bottom, 30)
            }
            .navigationTitle("Récupération")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
            .alert(isSuccess ? "Succès" : "Erreur", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Actions
    
    private func sendResetEmail() {
        isLoading = true
        
        // Simulation d'appel réseau (1.5 sec)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            
            if !isValidEmail(email) {
                showErrorAlert("Email invalide")
                return
            }
            
            isSuccess = true
            alertMessage = "Email de récupération envoyé avec succès à \(email)"
            showAlert = true
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func showErrorAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    ForgotPasswordView()
}

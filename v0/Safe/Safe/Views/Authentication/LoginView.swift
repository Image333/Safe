//
//  LoginView.swift
//  Safe
//
//  Created by Imane on 08/09/2025.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var rememberMe = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header avec logo
                VStack(spacing: 20) {
                    Image(systemName: "shield.lefthalf.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Safe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Connectez-vous à votre compte")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                .padding(.bottom, 50)
                
                // Formulaire de connexion
                VStack(spacing: 20) {
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.gray)
                            Text("Email")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        TextField("Entrez votre email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(authManager.isLoading)
                    }
                    
                    // Mot de passe
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(.gray)
                            Text("Mot de passe")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            if showPassword {
                                TextField("Entrez votre mot de passe", text: $password)
                                    .disabled(authManager.isLoading)
                            } else {
                                SecureField("Entrez votre mot de passe", text: $password)
                                    .disabled(authManager.isLoading)
                            }
                            
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Options
                    HStack {
                        Button(action: {
                            rememberMe.toggle()
                        }) {
                            HStack {
                                Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                    .foregroundColor(rememberMe ? .blue : .gray)
                                Text("Se souvenir de moi")
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                        
                        NavigationLink(destination: ForgotPasswordView()) {
                            Text("Mot de passe oublié ?")
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 10)
                    
                    // Bouton de connexion
                    VStack(spacing: 15) {
                        Button(action: {
                            loginUser()
                        }) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text(authManager.isLoading ? "Connexion..." : "Se connecter")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                        .opacity((email.isEmpty || password.isEmpty || authManager.isLoading) ? 0.6 : 1.0)
                    }
                    .padding(.horizontal, 30)
                    
                    // Lien vers inscription
                    HStack {
                        Text("Pas encore de compte ?")
                            .foregroundColor(.secondary)
                        NavigationLink(destination: RegisterView()) {
                            Text("S'inscrire")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarHidden(true)
        }
        .alert("Erreur", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Méthodes privées
    
    private func loginUser() {
        Task {
            do {
                // Validation basique côté client
                guard isValidEmail(email) else {
                    showErrorAlert("Email invalide")
                    return
                }
                
                guard password.count >= 6 else {
                    showErrorAlert("Le mot de passe doit contenir au moins 6 caractères")
                    return
                }
                
                // Appeler l'API via AuthManager
                let success = try await authManager.login(email: email, password: password)
                
                if success {
                    // La navigation sera automatiquement gérée par ContentView
                    // grâce à l'état isAuthenticated d'AuthManager
                }
            } catch AuthError.invalidCredentials {
                showErrorAlert("Email ou mot de passe incorrect")
            } catch AuthError.networkError(let description) {
                showErrorAlert("Erreur réseau: \(description)")
            } catch {
                showErrorAlert("Erreur de connexion: \(error.localizedDescription)")
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}

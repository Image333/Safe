//
//  AuthenticationView.swift
//  Safe
//
//  Created by Imane on 08/09/2025.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @State private var showForgotPassword = false
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Onglet Connexion
                LoginViewContent(showForgotPassword: $showForgotPassword)
                    .environmentObject(authManager)
                    .tag(0)
                
                // Onglet Inscription
                RegisterViewContent()
                    .environmentObject(authManager)
                    .tag(1)
            }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .top) {
            VStack {
                HStack(spacing: 0) {
                    Button(action: {
                        selectedTab = 0
                    }) {
                        Text("Connexion")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedTab == 0 ? .white : .blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                selectedTab == 0 
                                    ? Color.blue
                                    : Color.clear
                            )
                    }
                    
                    Button(action: {
                        selectedTab = 1
                    }) {
                        Text("Inscription")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedTab == 1 ? .white : .blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                selectedTab == 1 
                                    ? Color.blue
                                    : Color.clear
                            )
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .padding(.top, 100)
        }
        .overlay(alignment: .bottomTrailing) {
            // Bouton de debug réseau (uniquement en mode debug)
            #if DEBUG
            NavigationLink(destination: NetworkTestView()) {
                Image(systemName: "network")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.black.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.trailing)
            .padding(.bottom)
            #endif
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .navigationBarHidden(true)
        } // Fermeture de NavigationView
    }
}

// MARK: - Login Content

struct LoginViewContent: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var showForgotPassword: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var rememberMe = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Logo et titre
                VStack(spacing: 20) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Safe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 180)
                
                // Formulaire de connexion
                VStack(spacing: 20) {
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(authManager.isLoading)
                    }
                    
                    // Mot de passe
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if showPassword {
                                TextField("Mot de passe", text: $password)
                                    .disabled(authManager.isLoading)
                            } else {
                                SecureField("Mot de passe", text: $password)
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
                        Toggle("Se souvenir", isOn: $rememberMe)
                            .font(.caption)
                        
                        Spacer()
                        
                        Button("Mot de passe oublié ?") {
                            showForgotPassword = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    // Bouton de connexion
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
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                    .opacity((email.isEmpty || password.isEmpty || authManager.isLoading) ? 0.6 : 1.0)
                }
                .padding(.horizontal, 30)
                
                Spacer(minLength: 50)
            }
        }
        .alert("Erreur", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loginUser() {
        Task {
            do {
                let success = try await authManager.login(email: email, password: password)
                if success {
                    // Navigation automatique gérée par ContentView
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Erreur de connexion: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Register Content

struct RegisterViewContent: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var acceptTerms = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // En-tête
                VStack(spacing: 15) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Créer un compte")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Rejoignez Safe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 180)
                
                // Formulaire
                VStack(spacing: 15) {
                    TextField("Prénom", text: $firstName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disabled(authManager.isLoading)
                    
                    TextField("Nom", text: $lastName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disabled(authManager.isLoading)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(authManager.isLoading)
                    
                    HStack {
                        if showPassword {
                            TextField("Mot de passe", text: $password)
                                .disabled(authManager.isLoading)
                        } else {
                            SecureField("Mot de passe", text: $password)
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
                    
                    SecureField("Confirmer le mot de passe", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(authManager.isLoading)
                    
                    HStack {
                        Button(action: {
                            acceptTerms.toggle()
                        }) {
                            Image(systemName: acceptTerms ? "checkmark.square.fill" : "square")
                                .foregroundColor(acceptTerms ? .blue : .gray)
                        }
                        
                        Text("J'accepte les conditions")
                            .font(.caption)
                        
                        Spacer()
                    }
                    
                    Button(action: {
                        registerUser()
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text(authManager.isLoading ? "Création..." : "Créer le compte")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || authManager.isLoading)
                    .opacity((!isFormValid || authManager.isLoading) ? 0.6 : 1.0)
                }
                .padding(.horizontal, 30)
                
                Spacer(minLength: 50)
            }
        }
        .alert("Erreur", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        return !firstName.isEmpty &&
               !lastName.isEmpty &&
               !email.isEmpty &&
               !password.isEmpty &&
               password == confirmPassword &&
               password.count >= 6 &&
               acceptTerms
    }
    
    private func registerUser() {
        Task {
            do {
                let success = try await authManager.register(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    password: password
                )
                if success {
                    // Navigation automatique gérée par ContentView
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Erreur d'inscription: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthManager())
}
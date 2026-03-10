//
//  RegisterView.swift
//  Safe
//
//  Created by Imane on 08/09/2025.
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var phoneNumber = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var acceptTerms = false
    @State private var acceptPrivacy = false
    @State private var receiveNotifications = true
    @State private var forceRefresh = false
    
    var body: some View {
        NavigationView {
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
                        
                        Text("Rejoignez Safe pour protéger vos proches")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Formulaire d'inscription
                    VStack(spacing: 20) {
                        // Informations personnelles
                        Group {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Prénom")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Entrez votre prénom", text: $firstName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.words)
                                    .disabled(authManager.isLoading)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nom")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Entrez votre nom", text: $lastName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.words)
                                    .disabled(authManager.isLoading)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Entrez votre email", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disabled(authManager.isLoading)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Téléphone (optionnel)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                TextField("Entrez votre numéro", text: $phoneNumber)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.phonePad)
                                    .disabled(authManager.isLoading)
                            }
                        }
                        
                        // Mots de passe
                        Group {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Mot de passe")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
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
                                
                                // Indicateur de force du mot de passe
                                PasswordStrengthIndicator(password: password)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirmer le mot de passe")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    if showConfirmPassword {
                                        TextField("Confirmez votre mot de passe", text: $confirmPassword)
                                            .disabled(authManager.isLoading)
                                    } else {
                                        SecureField("Confirmez votre mot de passe", text: $confirmPassword)
                                            .disabled(authManager.isLoading)
                                    }
                                    
                                    Button(action: {
                                        showConfirmPassword.toggle()
                                    }) {
                                        Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                // Validation de correspondance
                                if !confirmPassword.isEmpty {
                                    HStack {
                                        Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(password == confirmPassword ? .green : .red)
                                        Text(password == confirmPassword ? "Les mots de passe correspondent" : "Les mots de passe ne correspondent pas")
                                            .font(.caption)
                                            .foregroundColor(password == confirmPassword ? .green : .red)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Conditions et notifications
                    VStack(spacing: 15) {
                        VStack(spacing: 10) {
                            HStack {
                                Button(action: {
                                    acceptTerms.toggle()
                                    forceRefresh.toggle() // Force le rafraîchissement
                                }) {
                                    Image(systemName: acceptTerms ? "checkmark.square.fill" : "square")
                                        .foregroundColor(acceptTerms ? .blue : .gray)
                                }
                                
                                Text("J'accepte les ")
                                    .font(.caption)
                                + Text("Conditions d'utilisation")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .underline()
                                
                                Spacer()
                            }
                            
                            HStack {
                                Button(action: {
                                    acceptPrivacy.toggle()
                                    forceRefresh.toggle() // Force le rafraîchissement
                                }) {
                                    Image(systemName: acceptPrivacy ? "checkmark.square.fill" : "square")
                                        .foregroundColor(acceptPrivacy ? .blue : .gray)
                                }
                                
                                Text("J'accepte la ")
                                    .font(.caption)
                                + Text("Politique de confidentialité")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .underline()
                                
                                Spacer()
                            }
                            
                            HStack {
                                Toggle("Recevoir les notifications", isOn: $receiveNotifications)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Debug info en temps réel
                        VStack {
                            Text("🔍 Validation: \(isFormValid ? "VALIDE ✅" : "INVALIDE ❌")")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isFormValid ? .green : .red)
                            Text("Champs: Prénom(\(!firstName.isEmpty ? "✅" : "❌")) Nom(\(!lastName.isEmpty ? "✅" : "❌")) Email(\(!email.isEmpty ? "✅" : "❌")) MdP(\(password.count >= 6 ? "✅" : "❌"))")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Confirm(\(password == confirmPassword && !confirmPassword.isEmpty ? "✅" : "❌")) CGU(\(acceptTerms ? "✅" : "❌")) Confidentialité(\(acceptPrivacy ? "✅" : "❌"))")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Loading: \(authManager.isLoading ? "OUI" : "NON") - Bouton activé: \(isFormValid && !authManager.isLoading ? "OUI" : "NON")")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 30)
                        
                        // Bouton d'inscription simplifié
                        Button(action: {
                            if isFormValid && !authManager.isLoading {
                                registerUser()
                            } else {
                            }
                        }) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text(authManager.isLoading ? "Création du compte..." : "Créer mon compte")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                isFormValid && !authManager.isLoading ? Color.green : Color.gray
                            )
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || authManager.isLoading)
                        .padding(.horizontal, 30)
                    }
                    
                    // Lien vers connexion
                    HStack {
                        Text("Déjà un compte ?")
                            .foregroundColor(.secondary)
                        
                        Button("Se connecter") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                    .font(.subheadline)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Inscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
            .alert("Erreur", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onTapGesture {
                // Fermer le clavier quand on tape ailleurs
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Éviter les problèmes sur iPad
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        let firstNameValid = !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let lastNameValid = !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && email.contains("@")
        let passwordValid = password.count >= 6
        let passwordMatchValid = password == confirmPassword && !confirmPassword.isEmpty
        let agreementsValid = acceptTerms && acceptPrivacy
        
        let isValid = firstNameValid && lastNameValid && emailValid && passwordValid && passwordMatchValid && agreementsValid
        
        // Debug pour comprendre pourquoi le bouton reste grisé
        
        return isValid
    }
    
    // MARK: - Actions
    
    private func registerUser() {
        // RegisterUser called
        // Form valid: \(isFormValid)
        // Fields: firstName='\(firstName)', lastName='\(lastName)', email='\(email)', password='\(password)', confirmPassword='\(confirmPassword)'
        // Agreements: acceptTerms=\(acceptTerms), acceptPrivacy=\(acceptPrivacy)
        
        Task {
            do {
                // Validations côté client
                guard isValidEmail(email) else {
                    showErrorAlert("Email invalide")
                    return
                }
                
                guard password.count >= 6 else {
                    showErrorAlert("Le mot de passe doit contenir au moins 6 caractères")
                    return
                }
                
                guard password == confirmPassword else {
                    showErrorAlert("Les mots de passe ne correspondent pas")
                    return
                }
                
                guard acceptTerms else {
                    showErrorAlert("Vous devez accepter les conditions d'utilisation")
                    return
                }
                
                
                // Appeler l'API via AuthManager
                let success = try await authManager.register(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    password: password
                )
                
                
                if success {
                    // La navigation sera automatiquement gérée par ContentView
                    // grâce à l'état isAuthenticated d'AuthManager
                }
            } catch AuthError.registrationFailed(let description) {
                showErrorAlert("Erreur d'inscription: \(description)")
            } catch AuthError.networkError(let description) {
                showErrorAlert("Erreur réseau: \(description)")
            } catch {
                showErrorAlert("Erreur d'inscription: \(error.localizedDescription)")
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

// MARK: - Password Strength Indicator

struct PasswordStrengthIndicator: View {
    let password: String
    
    private var strength: PasswordStrength {
        return getPasswordStrength(password)
    }
    
    var body: some View {
        if !password.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { index in
                        Rectangle()
                            .frame(height: 4)
                            .foregroundColor(index < strength.level ? strength.color : Color.gray.opacity(0.3))
                            .cornerRadius(2)
                    }
                }
                
                Text(strength.description)
                    .font(.caption)
                    .foregroundColor(strength.color)
            }
        }
    }
    
    private func getPasswordStrength(_ password: String) -> PasswordStrength {
        let length = password.count
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialChar = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        
        var score = 0
        if length >= 8 { score += 1 }
        if hasUppercase { score += 1 }
        if hasLowercase { score += 1 }
        if hasNumber { score += 1 }
        if hasSpecialChar { score += 1 }
        if length >= 12 { score += 1 }
        
        switch score {
        case 0...2:
            return PasswordStrength(level: 1, color: .red, description: "Faible")
        case 3...4:
            return PasswordStrength(level: 2, color: .orange, description: "Moyen")
        case 5...6:
            return PasswordStrength(level: 3, color: .yellow, description: "Bon")
        default:
            return PasswordStrength(level: 4, color: .green, description: "Excellent")
        }
    }
}

struct PasswordStrength {
    let level: Int
    let color: Color
    let description: String
}

#Preview {
    RegisterView()
        .environmentObject(AuthManager())
}

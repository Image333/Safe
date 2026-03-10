//
//  AuthManager.swift
//  Safe
//
//  Created by Imane on 08/09/2025.
//

import SwiftUI

/// Erreurs d'authentification
enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case registrationFailed(String)
    case networkError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Email ou mot de passe incorrect"
        case .emailAlreadyExists:
            return "Cet email est déjà utilisé"
        case .registrationFailed(let description):
            return "Erreur d'inscription: \(description)"
        case .networkError(let description):
            return "Erreur réseau: \(description)"
        case .unknown(let description):
            return "Erreur inconnue: \(description)"
        }
    }
}

/// Gestionnaire d'état d'authentification
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    
    /// Récupérer le token d'authentification actuel
    var token: String? {
        return UserDefaults.standard.string(forKey: AppConfig.UserDefaultsKeys.authToken)
    }
    
    init() {
        checkAuthenticationStatus()
    }
    
    /// Vérifie le statut d'authentification au démarrage
    private func checkAuthenticationStatus() {
        guard let token = UserDefaults.standard.string(forKey: AppConfig.UserDefaultsKeys.authToken),
              let savedUserData = UserDefaults.standard.data(forKey: AppConfig.UserDefaultsKeys.currentUser),
              let _ = try? JSONDecoder().decode(User.self, from: savedUserData) else {
            isAuthenticated = false
            return
        }
        
        Task {
            do {
                let apiUser = try await apiService.me(token: token)
                await MainActor.run {
                    currentUser = User(
                        id: String(apiUser.id),
                        firstName: apiUser.firstname,
                        lastName: apiUser.name,
                        email: apiUser.email
                    )
                    isAuthenticated = true
                }
            } catch {
                // Token invalide, nettoyer
                await MainActor.run {
                    logout()
                }
            }
        }
    }
    
    /// Connexion utilisateur
    func login(email: String, password: String) async throws -> Bool {
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let response = try await apiService.login(email: email, password: password)
            
            // Sauvegarder le token et l'utilisateur
            UserDefaults.standard.set(response.token, forKey: AppConfig.UserDefaultsKeys.authToken)
            
            let user = User(
                id: String(response.user.id),
                firstName: response.user.firstname,
                lastName: response.user.name,
                email: response.user.email
            )
            
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: AppConfig.UserDefaultsKeys.currentUser)
            }
            
            await MainActor.run {
                currentUser = user
                isAuthenticated = true
            }
            
            return true
        } catch APIError.unauthorized {
            throw AuthError.invalidCredentials
        } catch APIError.networkError(let description) {
            throw AuthError.networkError(description)
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }
    
    /// Déconnecter l'utilisateur
    func logout() {
        // Supprimer les données sauvegardées
        UserDefaults.standard.removeObject(forKey: AppConfig.UserDefaultsKeys.authToken)
        UserDefaults.standard.removeObject(forKey: AppConfig.UserDefaultsKeys.currentUser)
        
        // Réinitialiser l'état
        currentUser = nil
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isAuthenticated = false
        }
    }
    
    /// Inscription utilisateur
    func register(firstName: String, lastName: String, email: String, password: String) async throws -> Bool {
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let response = try await apiService.signup(
                firstname: firstName,
                name: lastName,
                email: email,
                password: password
            )
            
            // Sauvegarder le token et l'utilisateur
            UserDefaults.standard.set(response.token, forKey: AppConfig.UserDefaultsKeys.authToken)
            
            let user = User(
                id: String(response.user.id),
                firstName: response.user.firstname,
                lastName: response.user.name,
                email: response.user.email
            )
            
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: AppConfig.UserDefaultsKeys.currentUser)
            }
            
            await MainActor.run {
                currentUser = user
                isAuthenticated = true
            }
            
            return true
        } catch APIError.badRequest(let description) {
            throw AuthError.registrationFailed(description)
        } catch APIError.networkError(let description) {
            throw AuthError.networkError(description)
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }
}

/// Modèle utilisateur simple
struct User: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}

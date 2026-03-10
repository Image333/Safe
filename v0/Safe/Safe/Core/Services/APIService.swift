//
//  APIService.swift
//  Safe
//
//  Created by Imane on 15/09/2025.
//

import Foundation

/// Service de communication avec l'API backend
class APIService {
    static let shared = APIService()
    
    private let baseURL = AppConfig.baseURL
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.networkTimeout
        config.timeoutIntervalForResource = AppConfig.networkTimeout
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Auth Endpoints
    
    /// Structure pour la réponse de connexion/inscription
    struct AuthResponse: Codable {
        let token: String
        let user: APIUser
    }
    
    /// Modèle utilisateur de l'API
    struct APIUser: Codable {
        let id: Int  // Changé de user_id à id
        let name: String
        let firstname: String
        let email: String
        let registration_date: String
        
        // Plus besoin de CodingKeys car les noms correspondent maintenant
    }
    
    /// Structure pour la requête de connexion
    struct LoginRequest: Codable {
        let email: String
        let password: String
    }
    
    /// Structure pour la requête d'inscription
    struct SignupRequest: Codable {
        let name: String
        let firstname: String
        let email: String
        let password: String
    }
    
    /// Connexion utilisateur
    func login(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/api/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginData = LoginRequest(email: email, password: password)
        request.httpBody = try JSONEncoder().encode(loginData)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError("Impossible de se connecter au serveur: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.invalidCredentials
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.error)
            }
            throw APIError.serverError("Erreur de connexion")
        }
        
        do {
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
    
    /// Inscription utilisateur
    func signup(firstname: String, name: String, email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/api/auth/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let signupData = SignupRequest(name: name, firstname: firstname, email: email, password: password)
        request.httpBody = try JSONEncoder().encode(signupData)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError("Impossible de se connecter au serveur: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 409 {
            throw APIError.emailAlreadyExists
        }
        
        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            // Essayer de décoder l'erreur
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.badRequest(errorData.error)
            }
            let responseText = String(data: data, encoding: .utf8) ?? "Erreur inconnue"
            throw APIError.serverError("Erreur d'inscription (HTTP \(httpResponse.statusCode)): \(responseText)")
        }
        
        do {
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
    
    /// Récupérer les informations de l'utilisateur connecté
    func me(token: String) async throws -> APIUser {
        let url = URL(string: "\(baseURL)/api/auth/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError("Impossible de se connecter au serveur: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError("Erreur lors de la récupération du profil")
        }
        
        do {
            return try JSONDecoder().decode(APIUser.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
    
    /// Test de connectivité avec le serveur
    func testConnection() async throws -> Bool {
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 500
            }
            return false
        } catch {
            throw APIError.networkError("Test de connexion échoué: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Contact Endpoints
    
    /// Structure pour la réponse de la liste de contacts
    struct ContactsResponse: Codable {
        let count: Int
        let data: [Contact]
    }
    
    /// Récupérer tous les contacts de l'utilisateur
    func getContacts(token: String) async throws -> [Contact] {
        let url = URL(string: "\(baseURL)/api/contact")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError("Impossible de récupérer les contacts: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.error)
            }
            throw APIError.serverError("Erreur lors de la récupération des contacts")
        }
        
        do {
            let contactsResponse = try JSONDecoder().decode(ContactsResponse.self, from: data)
            return contactsResponse.data
        } catch {
            throw APIError.decodingError
        }
    }
    
    /// Créer un nouveau contact
    func createContact(token: String, input: ContactInput) async throws -> Contact {
        let url = URL(string: "\(baseURL)/api/contact")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONEncoder().encode(input)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError("Impossible de créer le contact: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.error)
            }
            throw APIError.serverError("Erreur lors de la création du contact")
        }
        
        do {
            return try JSONDecoder().decode(Contact.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
    
    /// Supprimer un contact
    func deleteContact(token: String, contactId: Int) async throws {
        let url = URL(string: "\(baseURL)/api/contact/\(contactId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError("Impossible de supprimer le contact: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 204 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            if httpResponse.statusCode == 404 {
                throw APIError.serverError("Contact introuvable")
            }
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.error)
            }
            throw APIError.serverError("Erreur lors de la suppression du contact")
        }
    }
}

// MARK: - Error Handling

struct APIErrorResponse: Codable {
    let error: String
}

enum APIError: LocalizedError {
    case invalidResponse
    case invalidCredentials
    case emailAlreadyExists
    case badRequest(String)
    case serverError(String)
    case decodingError
    case unauthorized
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Réponse du serveur invalide"
        case .invalidCredentials:
            return "Email ou mot de passe incorrect"
        case .emailAlreadyExists:
            return "Cet email est déjà utilisé"
        case .badRequest(let message):
            return "Requête invalide: \(message)"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Erreur de traitement des données"
        case .unauthorized:
            return "Non autorisé"
        case .networkError(let description):
            return "Erreur de connexion réseau: \(description)"
        }
    }
}

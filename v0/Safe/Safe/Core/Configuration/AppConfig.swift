import Foundation

/// Configuration de l'application
struct AppConfig {
    static let simulationMode = false
    static var baseURL: String {
        #if DEBUG
        return "http://82.65.130.61:3002"
        #else
        return "http://82.65.130.61:3002"
        #endif
    }

    static let networkTimeout: TimeInterval = 30.0

    struct Permissions {
        static let cacheTimeout: TimeInterval = 2.0 
        static let requestCooldown: TimeInterval = 0.5
        static let maxRetryAttempts = 3
    }
    
    /// Clés pour UserDefaults
    struct UserDefaultsKeys {
        static let authToken = "auth_token"
        static let currentUser = "current_user"
        static let lastPermissionRequest = "last_permission_request"
    }
    
    /// Configuration SMTP pour l'envoi d'emails d'urgence
    struct SMTP {
        /// Serveur SMTP
        static var host: String {
            let envValue = EnvironmentConfig.shared.smtpHost
            return !envValue.isEmpty ? envValue : "smtp.gmail.com"
        }
        
        /// Port SMTP (587 pour TLS, 465 pour SSL)
        static var port: Int {
            let envValue = EnvironmentConfig.shared.smtpPort
            return envValue != 0 ? envValue : 587
        }
        
        /// Email expéditeur
        static var fromEmail: String {
            let envValue = EnvironmentConfig.shared.smtpFromEmail
            return !envValue.isEmpty ? envValue : "imanefleur863@gmail.com"
        }
        
        /// Nom de l'expéditeur
        static var fromName: String {
            let envValue = EnvironmentConfig.shared.smtpFromName
            return !envValue.isEmpty ? envValue : "Safe - Alerte d'urgence"
        }
        
        /// Nom d'utilisateur SMTP (généralement votre email)
        static var username: String {
            let envValue = EnvironmentConfig.shared.smtpUsername
            return !envValue.isEmpty ? envValue : "imanefleur863@gmail.com"
        }
        
        /// Mot de passe SMTP (App Password pour Gmail)
        static var password: String {
            let envValue = EnvironmentConfig.shared.smtpPassword
            return !envValue.isEmpty ? envValue : "xkhj mtqr mhgl gszw"
        }
        
        /// Vérifie si la configuration SMTP est complète
        static var isConfigured: Bool {
            !fromEmail.isEmpty && !username.isEmpty && !password.isEmpty
        }
    }
}

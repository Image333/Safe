//
//  EnvironmentConfig.swift
//  Safe
//
// 
//

import Foundation

/// Gestionnaire de configuration depuis les variables d'environnement
class EnvironmentConfig {
    static let shared = EnvironmentConfig()
    private var envVariables: [String: String] = [:]
    
    private init() {
        loadEnvFile()
    }
    
    private func loadEnvFile() {
        // Chemin vers le fichier .env dans le bundle principal
        guard let envPath = Bundle.main.path(forResource: ".env", ofType: nil) else {
            return
        }
        
        guard let content = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
    
            let parts = trimmed.components(separatedBy: "=")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                envVariables[key] = value
            }
        }
        
    }
    func get(_ key: String, default defaultValue: String = "") -> String {
        return envVariables[key] ?? defaultValue
    }
    func getInt(_ key: String, default defaultValue: Int = 0) -> Int {
        guard let value = envVariables[key] else { return defaultValue }
        return Int(value) ?? defaultValue
    }
    func has(_ key: String) -> Bool {
        guard let value = envVariables[key] else { return false }
        return !value.isEmpty
    }
    
    // MARK: - SMTP Configuration
    
    var smtpHost: String {
        return get("SMTP_HOST", default: "smtp.gmail.com")
    }
    
    var smtpPort: Int {
        return getInt("SMTP_PORT", default: 587)
    }
    
    var smtpUsername: String {
        return get("SMTP_USERNAME")
    }
    
    var smtpPassword: String {
        return get("SMTP_PASSWORD")
    }
    
    var smtpFromEmail: String {
        return get("SMTP_FROM_EMAIL")
    }
    
    var smtpFromName: String {
        return get("SMTP_FROM_NAME", default: "Safe - Alerte d'urgence")
    }
    
    var isSMTPConfigured: Bool {
        return has("SMTP_USERNAME") && has("SMTP_PASSWORD") && has("SMTP_FROM_EMAIL")
    }
}

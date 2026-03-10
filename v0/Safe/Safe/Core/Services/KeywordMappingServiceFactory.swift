//
//  KeywordMappingServiceFactory.swift
//  Safe
//
//  Factory pour choisir l'implémentation du service
//

import Foundation

class KeywordMappingServiceFactory {
    
    enum ServiceType {
        case local
        case remote
    }
    
    static let currentType: ServiceType = .local
    
    static func createService(authManager: AuthManager? = nil) -> any KeywordMappingServiceProtocol {
        switch currentType {
        case .local:
            return LocalKeywordMappingService()
            
        case .remote:
            guard let authManager = authManager else {
                return LocalKeywordMappingService()
            }
            return RemoteKeywordMappingService(authManager: authManager)
        }
    }
}

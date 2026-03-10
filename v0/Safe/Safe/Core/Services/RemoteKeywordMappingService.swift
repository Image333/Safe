//
//  RemoteKeywordMappingService.swift
//  Safe
//
//  Service SERVEUR pour la gestion des liaisons mot-clé/contact
//  (À activer plus tard quand le backend sera prêt)
//

import Foundation
import Combine

/// Service de gestion SERVEUR des liaisons mot-clé/contact (API)
class RemoteKeywordMappingService: KeywordMappingServiceProtocol, ObservableObject {
    @Published var mappings: [KeywordContactMapping] = []
    
    private let authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    func addMapping(keyword: String, contactId: Int?, priority: Int, sendMode: SendMode) async throws {
        guard authManager.token != nil else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Non authentifié"])
        }
        
        let newMapping = KeywordContactMapping(
            id: UUID(),
            serverId: nil,
            keyword: keyword,
            contactId: contactId,
            priority: priority,
            sendMode: sendMode
        )
        
        await MainActor.run {
            mappings.append(newMapping)
        }
    }
    
    func getContactIdsForKeyword(_ keyword: String) -> [Int] {
        let cleanedKeyword = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return mappings
            .filter { $0.keyword == cleanedKeyword && $0.contactId != nil }
            .sorted { $0.priority < $1.priority }
            .compactMap { $0.contactId }
    }
    
    func getSendModeForKeyword(_ keyword: String) -> SendMode? {
        let cleanedKeyword = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return mappings
            .first { $0.keyword == cleanedKeyword }?
            .sendMode
    }
    
    func removeMapping(_ mapping: KeywordContactMapping) async throws {
        guard authManager.token != nil else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Non authentifié"])
        }
        
        await MainActor.run {
            mappings.removeAll { $0.id == mapping.id }
        }
    }
    
    func removeMappingsForContact(_ contactId: Int) async throws {
        let toDelete = mappings.filter { $0.contactId == contactId }
        
        for mapping in toDelete {
            try await removeMapping(mapping)
        }
    }
    
    func loadMappings() async throws {
        guard authManager.token != nil else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Non authentifié"])
        }
        
        await MainActor.run {
            mappings = []
        }
    }
}

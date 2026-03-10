//
//  LocalKeywordMappingService.swift
//  Safe
//
//  Service LOCAL pour la gestion des liaisons mot-clé/contact
//

import Foundation
import Combine

/// Service de gestion LOCAL des liaisons mot-clé/contact (UserDefaults)
class LocalKeywordMappingService: KeywordMappingServiceProtocol, ObservableObject {
    @Published var mappings: [KeywordContactMapping] = []
    
    private let userDefaults = UserDefaults.standard
    private let mappingsKey = "keyword_contact_mappings"
    
    private var keywordDetectionService: KeywordDetectionServiceProtocol? {
        DependencyContainer.shared.keywordDetectionService
    }
    
    init() {
        Task {
            try? await loadMappings()
        }
    }
    
    func addMapping(keyword: String, contactId: Int?, priority: Int, sendMode: SendMode) async throws {
        let newMapping = KeywordContactMapping(
            keyword: keyword,
            contactId: contactId,
            priority: priority,
            sendMode: sendMode
        )
        
        await MainActor.run {
            mappings.append(newMapping)
            saveMappings()
            
            keywordDetectionService?.addKeyword(keyword)
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
        await MainActor.run {
            mappings.removeAll { $0.id == mapping.id }
            saveMappings()
            
            let stillUsed = mappings.contains { $0.keyword == mapping.keyword }
            if !stillUsed {
                keywordDetectionService?.removeKeyword(mapping.keyword)
            }
        }
    }
    
    func removeMappingsForContact(_ contactId: Int) async throws {
        await MainActor.run {
            mappings.removeAll { $0.contactId == contactId }
            saveMappings()
        }
    }
    
    func loadMappings() async throws {
        if let data = userDefaults.data(forKey: mappingsKey),
           let decoded = try? JSONDecoder().decode([KeywordContactMapping].self, from: data) {
            await MainActor.run {
                mappings = decoded
                
                let keywords = Set(mappings.map { $0.keyword })
                keywordDetectionService?.setKeywords(Array(keywords))
            }
        }
    }
    
    // MARK: - Private
    
    private func saveMappings() {
        if let encoded = try? JSONEncoder().encode(mappings) {
            userDefaults.set(encoded, forKey: mappingsKey)
        }
    }
}

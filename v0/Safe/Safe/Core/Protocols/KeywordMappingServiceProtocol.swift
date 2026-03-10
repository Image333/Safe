//
//  KeywordMappingServiceProtocol.swift
//  Safe
//
//  Protocole pour la gestion des liaisons mot-clé/contact
//

import Foundation
import Combine

protocol KeywordMappingServiceProtocol: ObservableObject {
    var mappings: [KeywordContactMapping] { get }

    func addMapping(keyword: String, contactId: Int?, priority: Int, sendMode: SendMode) async throws
    func getContactIdsForKeyword(_ keyword: String) -> [Int]
    func getSendModeForKeyword(_ keyword: String) -> SendMode?
    func removeMapping(_ mapping: KeywordContactMapping) async throws
    func removeMappingsForContact(_ contactId: Int) async throws
    func loadMappings() async throws
}

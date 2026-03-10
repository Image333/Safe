//
//  KeywordContactMapping.swift
//  Safe
//
//  Liaison entre mots-clés et contacts d'urgence
//

import Foundation

/// Mode d'envoi pour une liaison mot-clé
enum SendMode: String, Codable, CaseIterable {
    case sendToContacts = "Envoyer par email automatiquement"
    case recordOnly = "Enregistrer seulement"
    
    var icon: String {
        switch self {
        case .sendToContacts: return "envelope.fill"
        case .recordOnly: return "mic.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .sendToContacts: return "📧 L'enregistrement sera envoyé automatiquement par email"
        case .recordOnly: return "💾 L'enregistrement sera sauvegardé sans envoi"
        }
    }
}

/// Liaison entre un mot-clé et un contact
struct KeywordContactMapping: Codable, Identifiable, Equatable {
    let id: UUID
    let serverId: Int?  // ID serveur (nil si local uniquement)
    let keyword: String
    let contactId: Int?  // Optionnel maintenant (nil si recordOnly)
    let priority: Int
    let sendMode: SendMode  // Mode d'envoi
    
    init(
        id: UUID = UUID(),
        serverId: Int? = nil,
        keyword: String,
        contactId: Int? = nil,
        priority: Int = 1,
        sendMode: SendMode = .sendToContacts
    ) {
        self.id = id
        self.serverId = serverId
        self.keyword = keyword.lowercased()
        self.contactId = contactId
        self.priority = priority
        self.sendMode = sendMode
    }
    
    static func == (lhs: KeywordContactMapping, rhs: KeywordContactMapping) -> Bool {
        lhs.id == rhs.id
    }
}

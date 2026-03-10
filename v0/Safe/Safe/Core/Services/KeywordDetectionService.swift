//
//  KeywordDetectionService.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import Combine

/// Service de détection de mots-clés d'urgence
/// 
/// Implémente un système robuste de détection avec anti-rebond et sensibilité configurable.
/// Respecte les principes SOLID avec responsabilité unique.
final class KeywordDetectionService: KeywordDetectionServiceProtocol, ObservableObject {
    
    // MARK: - Private Properties
    private var emergencyKeywords: Set<String> = []
    private var lastDetectionTimes: [String: Date] = [:]
    private var cooldownPeriod: TimeInterval = 5.0
    
    // MARK: - Published Properties
    @Published private(set) var lastDetectedKeyword: String?
    @Published private(set) var detectionCount: Int = 0
    
    // MARK: - Publishers
    private let detectionSubject = PassthroughSubject<DetectedKeyword, Never>()
    
    // MARK: - Initialization
    
    init() {
        // L'utilisateur doit maintenant configurer ses propres mots-clés
    }
    
    // MARK: - KeywordDetectionServiceProtocol Implementation
    
    func setKeywords(_ keywords: [String]) {
        emergencyKeywords = Set(keywords.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
    }
    
    func addKeyword(_ keyword: String) {
        let cleanedKeyword = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        emergencyKeywords.insert(cleanedKeyword)
    }
    
    func removeKeyword(_ keyword: String) {
        let cleanedKeyword = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        emergencyKeywords.remove(cleanedKeyword)
    }
    
    func detectKeywords(in text: String) -> [DetectedKeyword] {
        let cleanedText = text.lowercased()
        var detectedKeywords: [DetectedKeyword] = []
        
        // Rechercher chaque mot-clé dans le texte
        for keyword in emergencyKeywords {
            if cleanedText.contains(keyword) {
                // Vérifier l'anti-rebond
                if shouldDetectKeyword(keyword) {
                    let detectedKeyword = DetectedKeyword(
                        keyword: keyword,
                        detectedAt: Date(),
                        confidence: calculateConfidence(keyword: keyword, in: cleanedText),
                        context: extractContext(keyword: keyword, from: text)
                    )
                    
                    detectedKeywords.append(detectedKeyword)
                    recordDetection(for: keyword)
                }
            }
        }
        
        // Trier par niveau de confiance décroissant
        return detectedKeywords.sorted { $0.confidence > $1.confidence }
    }
    
    func setCooldownPeriod(_ seconds: TimeInterval) {
        cooldownPeriod = seconds
    }
    
    func getKeywordList() -> [String] {
        return Array(emergencyKeywords).sorted()
    }
    
    func clearDetectionHistory() {
        lastDetectionTimes.removeAll()
        detectionCount = 0
    }
    
    func getDetectionPublisher() -> AnyPublisher<DetectedKeyword, Never> {
        return detectionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func shouldDetectKeyword(_ keyword: String) -> Bool {
        let now = Date()
        
        // Vérifier si assez de temps s'est écoulé depuis la dernière détection
        if let lastDetection = lastDetectionTimes[keyword] {
            let timeSinceLastDetection = now.timeIntervalSince(lastDetection)
            return timeSinceLastDetection >= cooldownPeriod
        }
        
        return true
    }
    
    private func recordDetection(for keyword: String) {
        lastDetectionTimes[keyword] = Date()
        detectionCount += 1
        lastDetectedKeyword = keyword
        
        // Publier la détection
        let detectedKeyword = DetectedKeyword(
            keyword: keyword,
            detectedAt: Date(),
            confidence: 1.0,
            context: ""
        )
        
        detectionSubject.send(detectedKeyword)
    }
    
    private func calculateConfidence(keyword: String, in text: String) -> Double {
        // Calcul de confiance basé sur :
        // 1. La longueur du mot-clé (plus long = plus spécifique)
        // 2. La position dans le texte (début/fin = plus important)
        // 3. La fréquence d'apparition
        
        let keywordLength = Double(keyword.count)
        _ = Double(text.count) // textLength non utilisé pour l'instant
        
        // Score de base basé sur la longueur relative
        var confidence = min(keywordLength / 10.0, 1.0)
        
        // Bonus si le mot-clé est au début ou à la fin
        if text.hasPrefix(keyword) || text.hasSuffix(keyword) {
            confidence += 0.2
        }
        
        // Bonus pour les mots-clés plus spécifiques
        let specificKeywords = ["au secours", "à l'aide", "emergency", "urgence"]
        if specificKeywords.contains(keyword) {
            confidence += 0.3
        }
        
        return min(confidence, 1.0)
    }
    
    private func extractContext(keyword: String, from text: String) -> String {
        // Extraire le contexte autour du mot-clé (±20 caractères)
        guard let range = text.lowercased().range(of: keyword.lowercased()) else {
            return text
        }
        
        let startIndex = text.index(range.lowerBound, offsetBy: -min(20, range.lowerBound.utf16Offset(in: text)))
        let endIndex = text.index(range.upperBound, offsetBy: min(20, text.count - range.upperBound.utf16Offset(in: text)))
        
        return String(text[startIndex..<endIndex])
    }
}

// MARK: - Analytics and Statistics

extension KeywordDetectionService {
    
    /// Statistiques de détection pour le monitoring
    var detectionStatistics: DetectionStatistics {
        return DetectionStatistics(
            totalDetections: detectionCount,
            keywordCount: emergencyKeywords.count,
            lastDetectionTime: lastDetectionTimes.values.max(),
            mostFrequentKeyword: findMostFrequentKeyword()
        )
    }
    
    private func findMostFrequentKeyword() -> String? {
        // Simplification - dans une implémentation complète,
        // on garderait un compteur par mot-clé
        return lastDetectedKeyword
    }
}

// MARK: - Supporting Types

/// Statistiques de détection
struct DetectionStatistics {
    let totalDetections: Int
    let keywordCount: Int
    let lastDetectionTime: Date?
    let mostFrequentKeyword: String?
}

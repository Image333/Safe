//
//  FileManagementService.swift
//  Safe
//
//  Created by Imane on 19/09/2025.
//

import Foundation

/// Service de gestion des fichiers d'enregistrement
final class FileManagementService: ObservableObject {
    
    // MARK: - Properties
    private let documentsPath: URL
    
    init() {
        documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - Public Methods
    
    /// Récupère tous les enregistrements d'urgence
    func getAllRecordings() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            return files.filter { url in
                let isAudioFile = url.pathExtension == "m4a" || url.pathExtension == "wav"
                let isEmergencyRecording = url.lastPathComponent.contains("emergency")
                return isAudioFile && isEmergencyRecording
            }.sorted { $0.lastPathComponent > $1.lastPathComponent } // Plus récents en premier
        } catch {
            return []
        }
    }
    
    /// Supprime un enregistrement
    func deleteRecording(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }
    
    /// Supprime tous les enregistrements
    func deleteAllRecordings() -> Bool {
        let recordings = getAllRecordings()
        var success = true
        
        for recording in recordings {
            if !deleteRecording(at: recording) {
                success = false
            }
        }
        
        return success
    }
    
    /// Obtient la taille d'un fichier en bytes
    func getFileSize(for url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    /// Formate la taille du fichier pour l'affichage
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Obtient la date de création d'un fichier
    func getCreationDate(for url: URL) -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.creationDate] as? Date
        } catch {
            return nil
        }
    }
}

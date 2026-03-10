//
//  EmergencyShareService.swift
//  Safe
//
//  Service de partage d'enregistrements d'urgence
//

import SwiftUI
import UIKit

class EmergencyShareService {
    
    /// Partage un enregistrement d'urgence avec les contacts
    /// - Parameters:
    ///   - recordingURL: URL de l'enregistrement audio
    ///   - contacts: Liste des contacts à prévenir
    ///   - viewController: Contrôleur de vue pour présenter le partage
    func shareEmergencyRecording(
        recordingURL: URL,
        contacts: [Contact],
        from viewController: UIViewController
    ) {
        // Vérifier que le fichier existe
        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            return
        }
        
        // Créer le message de partage
        let contactNames = contacts.prefix(3).map { $0.name }.joined(separator: ", ")
        let message = """
        🚨 ALERTE D'URGENCE
        
        Un enregistrement d'urgence a été déclenché.
        Contacts concernés: \(contactNames)
        
        Fichier audio ci-joint.
        """
        
        // Créer les items à partager
        let itemsToShare: [Any] = [message, recordingURL]
        
        // Créer le contrôleur de partage
        let activityController = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )
        
        // Exclure certaines options si nécessaire
        activityController.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .print
        ]
        
        // Présenter le partage
        if let popoverController = activityController.popoverPresentationController {
            popoverController.sourceView = viewController.view
            popoverController.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
        }
        
        viewController.present(activityController, animated: true)
    }
    
    func createEmergencyMessage(
        keyword: String,
        timestamp: Date,
        contacts: [Contact]
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        
        let contactList = contacts.prefix(5).map { "• \($0.name) (\($0.phone))" }.joined(separator: "\n")
        
        return """
        🚨 ALERTE D'URGENCE SAFE
        
        Mot-clé détecté: "\(keyword)"
        Date: \(formatter.string(from: timestamp))
        
        Contacts à prévenir:
        \(contactList)
        
        Un enregistrement audio est joint à ce message.
        """
    }
}

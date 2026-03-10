//
//  AutoMessageService.swift
//  Safe
//
//  Service d'envoi automatique d'emails avec audio via SMTP
//

import Foundation
import UIKit


class AutoMessageService: NSObject, ObservableObject {
    
    static let shared = AutoMessageService()
    
    private var emailCompletionHandler: ((Bool) -> Void)?
    
    /// Envoie un email automatiquement avec l'enregistrement audio via SMTP
    /// - Parameters:
    ///   - recordingURL: URL de l'enregistrement audio
    ///   - contacts: Liste des contacts à qui envoyer
    ///   - keyword: Mot-clé qui a déclenché l'alerte
    func sendAutomaticMessage(
        recordingURL: URL,
        to contacts: [Contact],
        keyword: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        // Configurer le service SMTP avec les variables d'environnement
        SMTPEmailService.shared.configure(with: SMTPConfig.fromEnvironment)
        
        // Récupérer le nom de l'utilisateur connecté
        let authManager = AuthManager()
        let userName = authManager.currentUser?.fullName ?? "L'utilisateur"
        
        // Récupérer la localisation actuelle
        LocationService.shared.getCurrentLocation { location in
            SMTPEmailService.shared.sendEmergencyEmail(
                recordingURL: recordingURL,
                to: contacts,
                keyword: keyword,
                userName: userName,
                location: location
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion?(true)
                    case .failure(_):
                        completion?(false)
                    }
                }
            }
        }
    }
}

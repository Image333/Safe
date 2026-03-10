//
//  VoiceMonitoringCoordinator.swift
//  Safe
//
//  Created by System on 19/09/2025.
//

import Foundation
import SwiftUI

/// Coordinateur pour la surveillance vocale avec gestion proactive des permissions
class VoiceMonitoringCoordinator: ObservableObject {
    
    @Published var isMonitoringActive = false
    @Published var permissionStatus: MonitoringPermissionStatus = .notRequested
    @Published var showingPermissionAlert = false
    
    private let permissionService = PermissionService()
    @Injected(\.voiceMonitoringService) private var voiceMonitoringService
    
    enum MonitoringPermissionStatus {
        case notRequested
        case requesting
        case granted
        case partiallyGranted
        case denied
        
        var description: String {
            switch self {
            case .notRequested:
                return "Permissions non demandées"
            case .requesting:
                return "Demande en cours..."
            case .granted:
                return "Toutes les permissions accordées"
            case .partiallyGranted:
                return "Certaines permissions manquantes"
            case .denied:
                return "Permissions refusées"
            }
        }
    }
    
    /// Active la surveillance avec demande automatique des permissions
    func activateMonitoring() {
        Task {
            do {
                await MainActor.run {
                    permissionStatus = .requesting
                    // Ne plus afficher automatiquement l'alerte - elle sera affichée seulement en cas de problème
                    // showingPermissionAlert = true
                }
                
                
                // Timeout de 10 secondes pour éviter de rester bloqué sur "Demande en cours"
                let permissionsGranted = try await withTimeout(seconds: 10) {
                    await self.permissionService.requestAllPermissionsProactively()
                }
                
                // Attendre un peu pour que l'UI se mette à jour
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 secondes
                
                await MainActor.run {
                    if permissionsGranted {
                        permissionStatus = .granted
                        isMonitoringActive = true
                        
                        // Démarrer réellement la surveillance
                        startVoiceMonitoring()
                        
                    } else if permissionService.areEssentialPermissionsGranted() {
                        permissionStatus = .partiallyGranted
                        isMonitoringActive = true
                        
                        // Démarrer avec les permissions partielles
                        startVoiceMonitoring()
                        
                    } else {
                        permissionStatus = .denied
                        isMonitoringActive = false
                        // Afficher l'alerte uniquement si les permissions sont refusées
                        showingPermissionAlert = true
                    }
                    
                }
            } catch {
                // En cas d'erreur ou timeout, réinitialiser l'état
                await MainActor.run {
                    showingPermissionAlert = true  // Afficher l'alerte en cas d'erreur
                    permissionStatus = .denied
                    isMonitoringActive = false
                }
            }
        }
    }
    
    /// Fonction helper pour ajouter un timeout
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    struct TimeoutError: Error {}
    
    /// Désactive la surveillance
    func deactivateMonitoring() {
        isMonitoringActive = false
        permissionStatus = .notRequested
        
        // Arrêter la surveillance
        voiceMonitoringService.stopScheduledListening()
        
    }
    
    /// Démarre effectivement la surveillance vocale
    private func startVoiceMonitoring() {
        
        // Utiliser le service de surveillance existant
        voiceMonitoringService.startScheduledListening()
        
    }
    
    /// Ouvre les réglages de l'application
    func openAppSettings() {
        permissionService.openAppSettings()
    }
    
    /// Réessaye de demander les permissions
    func retryPermissions() {
        activateMonitoring()
    }
    
    /// Ferme l'alerte de permissions
    func dismissPermissionAlert() {
        showingPermissionAlert = false
        permissionStatus = .notRequested
    }
}

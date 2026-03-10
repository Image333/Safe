//
//  BackgroundTaskService.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import UIKit
import AVFoundation
import Combine

/// Service de gestion des tâches en arrière-plan
/// 
/// Permet à l'application de continuer la surveillance vocale même lorsqu'elle
/// n'est pas au premier plan, dans les limites des capacités iOS.
final class BackgroundTaskService: BackgroundTaskServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isBackgroundTaskActive: Bool = false
    @Published private(set) var backgroundTimeRemaining: TimeInterval = 0
    @Published private(set) var taskStartTime: Date?
    
    // MARK: - Private Properties
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        setupBackgroundNotifications()
    }
    
    // MARK: - BackgroundTaskServiceProtocol Implementation
    
    func startBackgroundTask() {
        // Éviter de démarrer plusieurs tâches
        guard backgroundTaskIdentifier == .invalid else {
            return
        }
        
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(
            withName: "VoiceMonitoringTask"
        ) { [weak self] in
            // Cette closure est appelée quand le temps est presque écoulé
            self?.handleBackgroundTaskExpiration()
        }
        
        guard backgroundTaskIdentifier != .invalid else {
            return
        }
        
        // Marquer le début
        taskStartTime = Date()
        isBackgroundTaskActive = true
        
        // Démarrer le timer de surveillance avec une stratégie plus agressive
        startBackgroundTimer()
        
        
        // Planifier une vérification proactive du temps
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            self?.checkAndCleanupEarly()
        }
    }
    
    func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else {
            return
        }
        
        
        // Arrêter le timer
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        
        // Terminer la tâche
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
        
        // Mettre à jour l'état
        isBackgroundTaskActive = false
        backgroundTimeRemaining = 0
        taskStartTime = nil
        
    }
    
    func configureBackgroundAudio() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord, 
                mode: .default, 
                options: [.mixWithOthers, .allowBluetoothHFP, .defaultToSpeaker]
            )
            try audioSession.setActive(true)
        } catch {
        }
    }
    
    func getRemainingBackgroundTime() -> TimeInterval {
        return UIApplication.shared.backgroundTimeRemaining
    }
    
    func isBackgroundTaskRunning() -> Bool {
        return backgroundTaskIdentifier != .invalid && isBackgroundTaskActive
    }
    
    func getBackgroundTaskDuration() -> TimeInterval? {
        guard let startTime = taskStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    func requestExtendedBackgroundTime() -> Bool {
        // iOS ne permet pas de prolonger arbitrairement le temps d'arrière-plan
        // Mais on peut optimiser notre usage existant
        
        guard isBackgroundTaskRunning() else {
            return false
        }
        
        let remaining = getRemainingBackgroundTime()
        let _ = safeDoubleToInt(remaining)
        
        // Si moins de 30 secondes restantes, préparer l'arrêt (seulement si ce n'est pas infinity)
        if remaining.isFinite && remaining < 30 {
            
            // Envoyer une notification pour informer l'utilisateur
            NotificationCenter.default.post(
                name: .backgroundTaskWillExpire,
                object: nil,
                userInfo: ["remainingTime": remaining]
            )
            
            return false
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func startBackgroundTimer() {
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateBackgroundStatus()
        }
    }
    
    private func checkAndCleanupEarly() {
        guard isBackgroundTaskRunning() else { return }
        
        let elapsed = getBackgroundTaskDuration() ?? 0
        let remaining = getRemainingBackgroundTime()
        
        // Si on approche des 30 secondes ou s'il ne reste que peu de temps
        if elapsed > 25 || (remaining.isFinite && remaining < 30) {
            handleBackgroundTaskExpiration()
        } else {
            // Programmer une autre vérification dans 10 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                self?.checkAndCleanupEarly()
            }
        }
    }
    
    private func updateBackgroundStatus() {
        guard isBackgroundTaskRunning() else {
            backgroundTimer?.invalidate()
            backgroundTimer = nil
            return
        }
        
        let remaining = getRemainingBackgroundTime()
        let elapsed = getBackgroundTaskDuration() ?? 0
        
        DispatchQueue.main.async { [weak self] in
            self?.backgroundTimeRemaining = remaining
        }
        
        // Log périodique pour le debugging avec validation sécurisée
        let _ = safeDoubleToInt(remaining)
        let elapsedInt = Int(elapsed)
        
        if elapsedInt > 0 && elapsedInt % 15 == 0 {
        }
        
        // Nettoyage proactif si on approche de la limite de 30 secondes
        if elapsed > 25 || (remaining.isFinite && remaining < 20) {
            handleBackgroundTaskExpiration()
        }
    }
    
    private func handleBackgroundTaskExpiration() {
        
        // Notifier les autres services de l'expiration imminente
        NotificationCenter.default.post(
            name: .backgroundTaskWillExpire,
            object: nil
        )
        
        // Effectuer un nettoyage rapide
        performQuickCleanup()
        
        // Terminer la tâche proprement
        endBackgroundTask()
    }
    
    private func performQuickCleanup() {
        // Actions de nettoyage rapide avant l'arrêt forcé
        
        // Sauvegarder les données critiques
        // Arrêter les processus non essentiels
        // Envoyer une notification à l'utilisateur si nécessaire
        
        // Notification pour l'interface utilisateur
        NotificationCenter.default.post(
            name: .backgroundTaskDidExpire,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        
        // La tâche de surveillance démarrera la tâche en arrière-plan
        // selon ses besoins
    }
    
    @objc private func appWillEnterForeground() {
        
        // Terminer la tâche en arrière-plan si elle est active
        if isBackgroundTaskRunning() {
            endBackgroundTask()
        }
    }
    
    // MARK: - Deinitializer
    
    deinit {
        endBackgroundTask()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Helper Methods
    
    /// Conversion sécurisée de Double vers Int pour éviter les crashes
    private func safeDoubleToInt(_ value: Double) -> Int {
        if value.isInfinite {
            return Int.max
        }
        if value.isNaN {
            return 0
        }
        if value > Double(Int.max) {
            return Int.max
        }
        if value < Double(Int.min) {
            return Int.min
        }
        return Int(value)
    }
}

// MARK: - Background Configuration

extension BackgroundTaskService {
    
    /// Configuration recommandée pour les capacités d'arrière-plan
    static func configureBackgroundModes() -> [String] {
        return [
            "audio",                    // Pour l'enregistrement audio continu
            "background-processing"     // Pour les tâches de traitement
        ]
    }
    
    /// Informations sur les limites iOS pour l'arrière-plan
    var backgroundLimitations: BackgroundLimitations {
        let systemTime = getRemainingBackgroundTime()
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        return BackgroundLimitations(
            maxDuration: systemTime,
            isLowPowerModeEnabled: isLowPowerMode,
            recommendedStrategy: isLowPowerMode ? .minimal : .extended
        )
    }
}

// MARK: - Supporting Types

struct BackgroundLimitations {
    let maxDuration: TimeInterval
    let isLowPowerModeEnabled: Bool
    let recommendedStrategy: BackgroundStrategy
}

enum BackgroundStrategy {
    case minimal    // Utilisation minimale en arrière-plan
    case extended   // Utilisation étendue si possible
}

// MARK: - Notification Names

extension Notification.Name {
    static let backgroundTaskWillExpire = Notification.Name("backgroundTaskWillExpire")
    static let backgroundTaskDidExpire = Notification.Name("backgroundTaskDidExpire")
}

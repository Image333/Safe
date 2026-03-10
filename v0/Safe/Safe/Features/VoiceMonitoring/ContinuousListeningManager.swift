//
//  ContinuousListeningManager.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import AVFoundation
import Speech
import UIKit
import UserNotifications

class ContinuousListeningManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isListening = false
    @Published var detectedText = ""
    @Published var isScheduledListening = false
    
    private let keywords = ["aide", "secours", "urgence", "help", "emergency"]
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Timer pour vérifier les programmations
    private var scheduleTimer: Timer?
    
    // Anti-rebond pour éviter les détections multiples
    private var lastKeywordDetection: Date = Date.distantPast
    private let keywordCooldown: TimeInterval = 5.0 // 5 secondes entre détections
    
    var onKeywordDetected: (() -> Void)?
    
    // MARK: - Permission Cache for Performance
    private var lastPermissionCheck: Date = Date.distantPast
    private var cachedPermissions: (mic: Bool, speech: Bool) = (false, false)
    private let permissionCacheTimeout: TimeInterval = AppConfig.Permissions.cacheTimeout
    
    init() {
        setupNotifications()
        startScheduleTimer()
    }
    
    // MARK: - Schedule Timer
    
    private func startScheduleTimer() {
        // Vérifie toutes les minutes si on doit démarrer/arrêter l'écoute
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkScheduleAndUpdate()
        }
    }
    
    private func checkScheduleAndUpdate() {
        // Logique simple basée sur l'heure actuelle
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        // Écoute active entre 17h et 17h30
        let shouldBeListening = (hour == 17 && minute < 30)
        
        if shouldBeListening && !isListening {
            startScheduledListening()
        } else if !shouldBeListening && isScheduledListening {
            stopScheduledListening()
        }
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
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
    
    @objc private func appWillEnterBackground() {
        if isScheduledListening {
            startBackgroundTask()
        }
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundTask()
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Configurer l'audio pour continuer en arrière-plan
        configureAudioForBackground()
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func configureAudioForBackground() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configuration spéciale pour l'arrière-plan
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat, // Mode critique pour la sécurité
                options: [.allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
            )
            
            // Activer l'audio en arrière-plan
            try audioSession.setActive(true)
            
            
        } catch {
        }
    }
    
    // MARK: - Listening Control
    
    func startScheduledListening() {
        isScheduledListening = true
        startContinuousListening()
    }
    
    func stopScheduledListening() {
        isScheduledListening = false
        stopContinuousListening()
    }
    
    private func startContinuousListening() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return
        }
        
        // Demander l'autorisation si nécessaire
        requestPermissions { [weak self] granted in
            if granted {
                DispatchQueue.main.async {
                    self?.beginSpeechRecognition()
                }
            }
        }
    }
    
    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        
        // Vérifier d'abord les permissions actuelles de manière optimisée
        let currentPerms = checkPermissions()
        if currentPerms.mic && currentPerms.speech {
            completion(true)
            return
        }
        
        // Utiliser async/await pour des demandes plus rapides et parallèles
        Task {
            let currentMicGranted = currentPerms.mic
            let currentSpeechGranted = currentPerms.speech
            
            // Demander les permissions en parallèle pour gagner du temps
            async let micRequest: Bool = {
                if currentMicGranted { return true }
                return await withCheckedContinuation { continuation in
                    if #available(iOS 17.0, *) {
                        AVAudioApplication.requestRecordPermission { granted in
                            continuation.resume(returning: granted)
                        }
                    } else {
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }()
            
            async let speechRequest: Bool = {
                if currentSpeechGranted { return true }
                return await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { status in
                        continuation.resume(returning: status == .authorized)
                    }
                }
            }()
            
            let (finalMicGranted, finalSpeechGranted) = await (micRequest, speechRequest)
            
            await MainActor.run {
                let success = finalMicGranted && finalSpeechGranted
                if success {
                } else {
                }
                completion(success)
            }
        }
    }
    
    private func beginSpeechRecognition() {
        stopCurrentRecognition()
        
        let perms = checkPermissions()
        if !perms.mic || !perms.speech {
            requestPermissions { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.beginSpeechRecognition()
                    }
                } else {
                    self?.isListening = false
                }
            }
            return
        }
        
        // Validation préalable du système audio avec retry
        var audioValid = false
        for attempt in 1...3 {
            if validateAudioSetup() {
                audioValid = true
                break
            }
            
            if attempt < 3 {
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        if !audioValid {
            retryWithSimpleFormat()
            return
        }
        
        do {
            // Configuration de la reconnaissance
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { 
                return 
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // Utiliser le format audio natif du système
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            
            // Installer le tap avec le format natif
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            // Préparer et démarrer le moteur
            audioEngine.prepare()
            try audioEngine.start()
            
            // Tâche de reconnaissance avec gestion des erreurs
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                self?.handleRecognitionResult(result: result, error: error)
            }
            
            isListening = true
            
            // Remettre à zéro le compteur de retry car tout fonctionne
            let retryKey = "speechRetryCount_\(Date().timeIntervalSince1970 / 3600)"
            UserDefaults.standard.set(0, forKey: retryKey)
            
        } catch {
            retryWithSimpleFormat()
        }
    }
    
    private func retryWithSimpleFormat() {
        do {
            // Nettoyer complètement
            stopCurrentRecognition()
            audioEngine.reset()
            
            // Configuration audio très basique
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(false)
            Thread.sleep(forTimeInterval: 0.5)
            try audioSession.setActive(true)
            
            
            // Attendre un peu plus longtemps pour la stabilisation
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.beginSpeechRecognition()
            }
            
        } catch {
            isListening = false
        }
    }
    
    private func validateAudioSetup() -> Bool {
        let perms = checkPermissions()
        if !perms.mic || !perms.speech {
            return false
        }
        
        // Vérifier la session audio
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configuration de la session audio si nécessaire
            try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
            
            // Vérifier le moteur audio
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)
            
            guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
                return false
            }
            
            return true
            
        } catch {
            return false
        }
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let result = result {
                let transcription = result.bestTranscription.formattedString.lowercased()
                self?.detectedText = transcription
                self?.checkForKeywords(in: transcription)
                
                // Si on reçoit des résultats, c'est que la reconnaissance fonctionne
                if !transcription.isEmpty {
                    let retryKey = "speechRetryCount_\(Date().timeIntervalSince1970 / 3600)"
                    UserDefaults.standard.set(0, forKey: retryKey)
                }
            }
            
            // Gérer les erreurs et redémarrer si nécessaire
            if let error = error {
                
                // Si c'est une erreur de permission, re-vérifier et redemander
                if error.localizedDescription.contains("denied access") {
                    
                    
                    // Vérifier l'état actuel des permissions
                    let perms = self?.checkPermissions()
                    
                    if perms?.speech == false {
                        // Redemander les permissions
                        self?.requestPermissions { [weak self] granted in
                            if granted {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    self?.beginSpeechRecognition()
                                }
                            } else {
                                self?.isListening = false
                                self?.isScheduledListening = false
                            }
                        }
                    } else {
                        self?.isListening = false
                        
                        // Essayer de redémarrer après un délai plus long, mais pas plus de 3 fois
                        let maxRetries = 3
                        let retryKey = "speechRetryCount_\(Date().timeIntervalSince1970 / 3600)" // Par heure
                        let currentRetry = UserDefaults.standard.integer(forKey: retryKey)
                        
                        if currentRetry < maxRetries {
                            UserDefaults.standard.set(currentRetry + 1, forKey: retryKey)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                                if self?.isScheduledListening == true {
                                    self?.beginSpeechRecognition()
                                }
                            }
                        } else {
                            // Reset pour la prochaine heure
                            let nextHourKey = "speechRetryCount_\(Date().timeIntervalSince1970 / 3600 + 1)"
                            UserDefaults.standard.set(0, forKey: nextHourKey)
                            self?.isScheduledListening = false
                        }
                    }
                } else {
                    // Pour les autres erreurs, redémarrer après une pause si on est toujours en écoute programmée
                    if self?.isScheduledListening == true {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self?.beginSpeechRecognition()
                        }
                    }
                }
            }
            
            // Redémarrer si la reconnaissance se termine naturellement
            if result?.isFinal == true && self?.isScheduledListening == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.beginSpeechRecognition()
                }
            }
        }
    }
    
    private func checkForKeywords(in text: String) {
        // Vérifier le délai anti-rebond
        let now = Date()
        if now.timeIntervalSince(lastKeywordDetection) < keywordCooldown {
            return // Ignorer si trop récent
        }
        
        for keyword in keywords {
            if text.contains(keyword) {
                
                // Mettre à jour le timestamp
                lastKeywordDetection = now
                
                // Déclencher l'enregistrement
                onKeywordDetected?()
                
                // Envoyer une notification critique
                sendCriticalNotification(keyword: keyword)
                break
            }
        }
    }
    
    private func sendCriticalNotification(keyword: String) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 URGENCE DÉTECTÉE"
        content.body = "Mot-clé '\(keyword)' détecté - Enregistrement démarré"
        content.sound = .defaultCritical
        content.categoryIdentifier = "EMERGENCY_DETECTED"
        
        let request = UNNotificationRequest(
            identifier: "emergency_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func stopContinuousListening() {
        stopCurrentRecognition()
        endBackgroundTask()
    }
    
    private func stopCurrentRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
            
            // Retirer le tap avec gestion d'erreur
            let inputNode = audioEngine.inputNode
            if inputNode.numberOfInputs > 0 {
                inputNode.removeTap(onBus: 0)
            }
        }
        
        // Terminer la requête de reconnaissance
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Nettoyer les références
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
    
    // MARK: - Schedule Integration
    
    func checkAndUpdateSchedule() {
        checkScheduleAndUpdate()
    }
    
    // MARK: - Permission Check
    
    func checkPermissions() -> (mic: Bool, speech: Bool) {
        // Vérifier le cache des permissions
        let now = Date()
        if now.timeIntervalSince(lastPermissionCheck) < permissionCacheTimeout {
            return cachedPermissions
        }
        
        let micGranted: Bool
        
        if #available(iOS 17.0, *) {
            micGranted = (AVAudioApplication.shared.recordPermission == .granted)
        } else {
            micGranted = (AVAudioSession.sharedInstance().recordPermission == .granted)
        }
        
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let speechGranted = (speechStatus == .authorized)
        
        // Mettre à jour le cache
        cachedPermissions = (mic: micGranted, speech: speechGranted)
        lastPermissionCheck = now
        
        return (mic: micGranted, speech: speechGranted)
    }
    
    /// Force la mise à jour du cache des permissions
    func refreshPermissionCache() {
        lastPermissionCheck = Date.distantPast
        _ = checkPermissions()
    }
    
    // MARK: - Audio Engine Reset
    
    private func resetAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        audioEngine.reset()
        
        // Laisser le temps au système de se réinitialiser
        Thread.sleep(forTimeInterval: 0.5)
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        scheduleTimer?.invalidate()
        stopContinuousListening()
    }
}

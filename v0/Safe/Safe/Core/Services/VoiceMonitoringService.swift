//
//  VoiceMonitoringService.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import Combine
import SwiftUI
import CoreLocation

/// Service principal de surveillance vocale
/// 
/// Coordonne la surveillance programmée, la détection de mots-clés
/// et l'enregistrement automatique en cas d'urgence.
final class VoiceMonitoringService: VoiceMonitoringServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isScheduledListening: Bool = false  
    @Published private(set) var detectedText: String = ""
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var recordingDuration: Double = 0.0
    
    /// Alias pour maintenir la compatibilité avec l'interface
    var lastDetectedText: String { detectedText }
    
    // MARK: - Dependencies
    private let audioEngineService: AudioEngineServiceProtocol
    private let speechRecognitionService: SpeechRecognitionServiceProtocol
    private let keywordDetectionService: KeywordDetectionServiceProtocol
    private let scheduleService: any ScheduleManagementServiceProtocol
    private let backgroundTaskService: BackgroundTaskServiceProtocol
    private let permissionService: PermissionServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let recordingService: AudioRecordingServiceProtocol
    private let mappingService: any KeywordMappingServiceProtocol = LocalKeywordMappingService()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var recognitionCancellable: AnyCancellable?
    private var scheduleTimer: Timer?
    private var recordingTimer: Timer?
    
    // Callback pour déclencher l'enregistrement
    var onKeywordDetected: (() -> Void)?
    
    // MARK: - Initialization
    
    init(
        audioEngineService: AudioEngineServiceProtocol,
        speechRecognitionService: SpeechRecognitionServiceProtocol,
        keywordDetectionService: KeywordDetectionServiceProtocol,
        scheduleService: any ScheduleManagementServiceProtocol,
        backgroundTaskService: BackgroundTaskServiceProtocol,
        permissionService: PermissionServiceProtocol,
        notificationService: NotificationServiceProtocol,
        recordingService: AudioRecordingServiceProtocol
    ) {
        self.audioEngineService = audioEngineService
        self.speechRecognitionService = speechRecognitionService
        self.keywordDetectionService = keywordDetectionService
        self.scheduleService = scheduleService
        self.backgroundTaskService = backgroundTaskService
        self.permissionService = permissionService
        self.notificationService = notificationService
        self.recordingService = recordingService
        
        setupServices()
    }
    
    // MARK: - Public Methods
    
    func startScheduledListening() {
        isScheduledListening = true
        startScheduleTimer()
        startContinuousListening()
    }
    
    func stopScheduledListening() {
        isScheduledListening = false
        scheduleTimer?.invalidate()
        scheduleTimer = nil
        stopContinuousListening()
    }
    
    func startMonitoring() {
        startContinuousListening()
    }
    
    func stopMonitoring() {
        stopContinuousListening()
        stopContinuousListening()
    }
    
    func checkAndUpdateSchedule() {
        let shouldBeListening = scheduleService.checkCurrentTimeSlot()
        

        
        // Démarrer si on est dans la plage, que le mode programmé n'est PAS déjà actif, et qu'on n'écoute pas encore
        // IMPORTANT: Ne pas redémarrer si isScheduledListening est déjà true pour éviter la boucle infinie !
        if shouldBeListening && !isListening && !isScheduledListening {
            startScheduledListening()
        }
        // Arrêter si on est hors plage et qu'on écoute encore
        else if !shouldBeListening && isScheduledListening {
            stopScheduledListening()
        }
        // Si on est hors plage et qu'on écoute toujours (ne devrait pas arriver)
        else if !shouldBeListening && isListening {
            stopScheduledListening()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupServices() {
        setupKeywordDetection()
        setupNotifications()
        setupBackgroundHandling()
    }
    
    private func setupKeywordDetection() {
        keywordDetectionService.setCooldownPeriod(5.0)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppEnterForeground()
            }
            .store(in: &cancellables)
        
        // Écouter l'activation du schedule pour démarrer automatiquement la surveillance
        NotificationCenter.default.publisher(for: .scheduleEnabled)
            .sink { [weak self] _ in
                self?.startScheduledListening()
            }
            .store(in: &cancellables)
        
        
        // Écouter la désactivation du schedule pour arrêter la surveillance
        NotificationCenter.default.publisher(for: .scheduleDisabled)
            .sink { [weak self] _ in
 
                self?.stopScheduledListening()
            }
            .store(in: &cancellables)
        
        // Écouter le début de lecture pour arrêter temporairement la surveillance
        NotificationCenter.default.publisher(for: Notification.Name("AudioPlaybackWillStartNotification"))
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Sauvegarder l'état actuel AVANT d'arrêter
                let wasListeningBefore = self.isListening
                
                // Arrêter proprement la surveillance si active
                if wasListeningBefore {
                    self.stopContinuousListening()
                }
                
                // Stocker l'état pour la reprise
                UserDefaults.standard.set(wasListeningBefore, forKey: "wasListeningBeforePlayback")
            }
            .store(in: &cancellables)
        
        // Écouter la fin de lecture pour reprendre la surveillance
        NotificationCenter.default.publisher(for: Notification.Name("AudioPlaybackDidFinishNotification"))
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Récupérer l'état sauvegardé
                let wasListeningBefore = UserDefaults.standard.bool(forKey: "wasListeningBeforePlayback")
                
                // Reprendre la surveillance si elle était active avant
                if wasListeningBefore && self.isScheduledListening {
                    // Attendre que les ressources audio soient complètement libérées
                    // Délai augmenté à 3 secondes pour éviter les conflits hardware
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        guard let self = self else { return }
                        self.startContinuousListening()
                    }
                }
                
                // Nettoyer la sauvegarde
                UserDefaults.standard.removeObject(forKey: "wasListeningBeforePlayback")
            }
            .store(in: &cancellables)
    }
    
    private func setupBackgroundHandling() {
        // Gestion des tâches en arrière-plan avec timeout intelligent
        backgroundTaskService.configureBackgroundAudio()
        
        // Écouter les notifications d'expiration de tâche
        NotificationCenter.default.publisher(for: .backgroundTaskWillExpire)
            .sink { [weak self] _ in
                self?.handleBackgroundTaskExpiration()
            }
            .store(in: &cancellables)
    }
    
    private func handleBackgroundTaskExpiration() {
        
        // Arrêter l'enregistrement en cours s'il y en a un
        if isRecording {
            stopEmergencyRecording()
        }
        
        // Simplement arrêter la tâche sans redémarrer automatiquement
        // Cela évite les redémarrages intempestifs
        backgroundTaskService.endBackgroundTask()
    }
    
    private func startScheduleTimer() {
        // Démarrer le timer seulement si la surveillance programmée est explicitement activée
        // Ne pas démarrer automatiquement au lancement
        scheduleTimer?.invalidate()
        
        // Vérifier immédiatement l'horaire au démarrage
        checkAndUpdateSchedule()
        
        // Puis vérifier toutes les minutes
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            // Vérifier que la surveillance programmée est toujours activée avant de continuer
            guard let self = self, self.isScheduledListening else {
                return
            }
            
            // Vérifier l'état du micro pour éviter les incohérences
            self.verifyListeningState()
            
            self.checkAndUpdateSchedule()
        }
        
    }
    
    private func startContinuousListening() {
        
        // Si on est en mode programmé, vérifier qu'on est bien dans la plage horaire
        if isScheduledListening {
            let isInTimeSlot = scheduleService.checkCurrentTimeSlot()
            if !isInTimeSlot {
                return
            }
        }
        
        guard speechRecognitionService.isAvailable else {
            return
        }
        

        
        // Vérifier et demander les permissions
        requestPermissionsIfNeeded()
            .sink { [weak self] granted in
                if granted {
                    self?.beginSpeechRecognition()
                } else {
                }
            }
            .store(in: &cancellables)
    }
    
    private func requestPermissionsIfNeeded() -> AnyPublisher<Bool, Never> {
        return permissionService.requestAllPermissions()
    }
    
    private func beginSpeechRecognition() {
        
        // Validation du système audio
        let isValid = audioEngineService.validateAudioSetup()
        
        guard isValid else {
            retryRecognitionLater()
            return
        }
        
        
        // Démarrer la reconnaissance
        audioEngineService.startRecognition { [weak self] result in
            switch result {
            case .success:
                self?.startSpeechRecognitionStream()
            case .failure(_):
                self?.retryRecognitionLater()
            }
        }
    }
    
    private func startSpeechRecognitionStream() {
        
        speechRecognitionService.startContinuousRecognition()
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        // Mettre isListening à false si la reconnaissance échoue
                        self?.isListening = false
                        self?.handleRecognitionError(error)
                    }
                },
                receiveValue: { [weak self] transcription in
                    self?.processTranscription(transcription)
                }
            )
            .store(in: &cancellables)
        
        
        // Vérifier que le moteur audio est réellement actif avant de mettre isListening à true
        let engineIsRunning = audioEngineService.isEngineRunning
        
        if engineIsRunning {
            isListening = true
        } else {
            isListening = false
        }
    }
    
    private func processTranscription(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.detectedText = text
            self?.checkForKeywords(in: text)
        }
    }
    
    private func checkForKeywords(in text: String) {
        let detectedKeywords = keywordDetectionService.detectKeywords(in: text)
        
        for detectedKeyword in detectedKeywords {
            
            // Récupérer les contacts associés à ce mot-clé
            let contactIds = mappingService.getContactIdsForKeyword(detectedKeyword.keyword)
            
            if !contactIds.isEmpty {
                
                // Envoyer une notification spécifique pour ce mot-clé
                sendTargetedEmergencyNotification(keyword: detectedKeyword.keyword, contactIds: contactIds)
            } else {
                // Envoyer notification générale
                notificationService.sendEmergencyNotification(keyword: detectedKeyword.keyword)
            }
            
            // Redémarrer la reconnaissance vocale pour avoir une nouvelle session propre
            restartRecognitionAfterKeywordDetection()
            
            // Déclencher l'enregistrement d'urgence de façon plus robuste
            startEmergencyRecording(for: detectedKeyword.keyword)
            
            break // Un seul déclenchement par détection
        }
    }
    
    /// Envoie une notification ciblée pour un mot-clé avec contacts spécifiques
    private func sendTargetedEmergencyNotification(keyword: String, contactIds: [Int]) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 Alerte '\(keyword)' détectée"
        content.body = "Enregistrement en cours et envoi automatique par email."
        content.sound = .defaultCritical
        content.categoryIdentifier = "EMERGENCY_AUTO"
        content.userInfo = [
            "keyword": keyword,
            "contactIds": contactIds
        ]
        
        let request = UNNotificationRequest(
            identifier: "emergency_keyword_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
            } else {
            }
        }
    }
    
    private func restartRecognitionAfterKeywordDetection() {
        
        // Effacer le texte détecté
        detectedText = ""
        speechRecognitionService.clearTranscription()
        
        // Arrêter complètement la reconnaissance et le moteur audio
        speechRecognitionService.stopRecognition()
        audioEngineService.stopRecognition()
        
        // Annuler l'abonnement actuel
        recognitionCancellable?.cancel()
        recognitionCancellable = nil
        
        // Redémarrer après un délai plus long pour laisser le hardware audio se libérer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, self.isListening else { return }
            
            
            // Redémarrer le moteur audio d'abord
            self.audioEngineService.startRecognition { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    
                    // Puis redémarrer la reconnaissance vocale
                    self.recognitionCancellable = self.speechRecognitionService
                        .startContinuousRecognition()
                        .receive(on: DispatchQueue.main)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(_) = completion {
                                }
                            },
                            receiveValue: { [weak self] transcription in
                                self?.processTranscription(transcription)
                            }
                        )
                    
                case .failure(_):
                    // Réessayer avec un délai plus long
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.beginSpeechRecognition()
                    }
                }
            }
        }
    }
    
    private func startEmergencyRecording(for keyword: String) {
        
        // Callback pour l'interface utilisateur
        onKeywordDetected?()
        
        // Démarrer l'enregistrement avec gestion d'erreur
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.recordingService.startEmergencyRecording()
            
            // Mettre à jour l'état sur le main thread
            DispatchQueue.main.async {
                self?.isRecording = true
                self?.startRecordingTimer()
                
                // Planifier l'envoi automatique après 10 secondes
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.5) { [weak self] in
                    self?.handleRecordingCompletion(for: keyword)
                }
            }
        }
    }
    
    /// Gère la fin de l'enregistrement et l'envoi automatique
    private func handleRecordingCompletion(for keyword: String) {
        
        // Récupérer le mode d'envoi pour ce mot-clé
        let sendMode = mappingService.getSendModeForKeyword(keyword)
        
        guard let mode = sendMode else {
            return
        }
        
        switch mode {
        case .recordOnly:
            // Juste une notification locale
            sendRecordOnlyNotification(keyword: keyword)
            
        case .sendToContacts:
            triggerAutomaticSend(for: keyword)
        }
    }
    
    /// Envoie une notification pour un enregistrement sans envoi
    private func sendRecordOnlyNotification(keyword: String) {
        let content = UNMutableNotificationContent()
        content.title = "🎙️ Enregistrement sauvegardé"
        content.body = "Mot-clé '\(keyword)' détecté. Enregistrement disponible dans vos fichiers."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "record_only_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Déclenche l'envoi automatique d'email
    private func triggerAutomaticSend(for keyword: String) {
        // Récupérer le dernier enregistrement
        guard let lastRecording = recordingService.getAllRecordings().first else {
            return
        }
        
        // Récupérer les contacts pour ce mot-clé
        let contactIds = mappingService.getContactIdsForKeyword(keyword)
        
        guard !contactIds.isEmpty else {
            return
        }
        
        // Charger les contacts depuis l'API (ou cache)
        Task {
            await sendMessageToContacts(
                recordingURL: lastRecording,
                contactIds: contactIds,
                keyword: keyword
            )
        }
    }
    
    /// Envoie le message aux contacts
    private func sendMessageToContacts(
        recordingURL: URL,
        contactIds: [Int],
        keyword: String
    ) async {
        
        // Configurer le service SMTP avec AppConfig (plus fiable)
        let smtpConfig = SMTPConfig(
            host: AppConfig.SMTP.host,
            port: AppConfig.SMTP.port,
            username: AppConfig.SMTP.username,
            password: AppConfig.SMTP.password,
            fromEmail: AppConfig.SMTP.fromEmail,
            fromName: AppConfig.SMTP.fromName
        )
        
        SMTPEmailService.shared.configure(with: smtpConfig)
        
        // Charger les vrais contacts depuis l'API
        // Note: Pour un POC, on utilise l'instance partagée d'AuthManager
        // En production, il faudrait l'injecter via DependencyContainer
        let authManager = AuthManager()
        guard let token = authManager.token else {
            return
        }
        
        do {
            let allContacts = try await APIService.shared.getContacts(token: token)
            let targetContacts = allContacts.filter { contactIds.contains($0.id) }
            
            if targetContacts.isEmpty {
                return
            }
            
            // Récupérer le nom de l'utilisateur
            let userName = authManager.currentUser?.fullName ?? "L'utilisateur"
            
            // Récupérer la localisation avant l'envoi d'email
            LocationService.shared.getCurrentLocation { location in
                SMTPEmailService.shared.sendEmergencyEmail(
                    recordingURL: recordingURL,
                    to: targetContacts,
                    keyword: keyword,
                    userName: userName,
                    location: location
                ) { result in
                    switch result {
                    case .success:
                        self.sendEmailSentNotification(keyword: keyword, contactCount: targetContacts.count)
                    case .failure(let error):
                        self.sendEmailFailedNotification(keyword: keyword, error: error)
                    }
                }
            }
        } catch {
            // Erreur lors de l'envoi d'email
        }
    }
    
    /// Notification email envoyé avec succès
    private func sendEmailSentNotification(keyword: String, contactCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "✅ Email(s) envoyé(s)"
        content.body = "Alerte '\(keyword)' envoyée à \(contactCount) contact(s) par email."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "email_sent_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Notification échec envoi email
    private func sendEmailFailedNotification(keyword: String, error: Error) {
        let content = UNMutableNotificationContent()
        content.title = "❌ Échec envoi email"
        content.body = "Impossible d'envoyer l'alerte '\(keyword)': \(error.localizedDescription)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "email_failed_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingDuration = 0.0
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, self.isRecording else {
                timer.invalidate()
                return
            }
            
            self.recordingDuration += 0.1
            
            // Arrêter automatiquement après 10 secondes
            if self.recordingDuration >= 10.0 {
                timer.invalidate()
                self.stopEmergencyRecording()
            }
        }
    }
    
    private func stopEmergencyRecording() {
        guard isRecording else { return }
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        recordingService.stopRecording()
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.recordingDuration = 0.0
        }
    }
    
    private func stopContinuousListening() {
        guard isListening else {
            return
        }
        
        
        // Arrêter dans l'ordre inverse du démarrage
        speechRecognitionService.stopRecognition()
        audioEngineService.stopRecognition()
        backgroundTaskService.endBackgroundTask()
        
        isListening = false
    }
    
    /// Vérifie que l'état isListening correspond vraiment à l'état du micro
    func verifyListeningState() {
        let engineIsRunning = audioEngineService.isEngineRunning
        
        // Si isListening est true mais que le moteur n'est pas actif, corriger l'incohérence
        if isListening && !engineIsRunning {
            isListening = false
        }
        // Si isListening est false mais que le moteur est actif, corriger aussi
        else if !isListening && engineIsRunning {
            isListening = true
        }
    }
    
    private func retryRecognitionLater() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if self?.isScheduledListening == true {
                self?.beginSpeechRecognition()
            }
        }
    }
    
    private func handleRecognitionError(_ error: SpeechRecognitionError) {
        // Vérifier si nous sommes toujours dans une plage horaire active
        guard isScheduledListening else {
            return
        }
        
        // Vérifier l'horaire avant de réessayer
        let shouldBeListening = scheduleService.checkCurrentTimeSlot()
        if !shouldBeListening {
            stopScheduledListening()
            return
        }
        
        switch error {
        case .notAuthorized:
            // Redemander les permissions
            requestPermissionsIfNeeded()
                .sink { [weak self] granted in
                    if granted {
                        self?.retryRecognitionLater()
                    } else {
                        self?.stopScheduledListening()
                    }
                }
                .store(in: &cancellables)
            
        case .audioEngineError:
            retryRecognitionLater()
            
        case .recognitionFailed:
            // Ne pas réessayer systématiquement pour les erreurs d'annulation (code 301)
            // Attendre plus longtemps avant de réessayer (10s au lieu de 5s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
                guard let self = self else { return }
                // Vérifier à nouveau l'horaire et l'état
                if self.isScheduledListening && self.scheduleService.checkCurrentTimeSlot() {
                    self.beginSpeechRecognition()
                } else {
                }
            }
            
        case .notAvailable:
            stopScheduledListening()
        }
    }
    
    private func handleAppEnterBackground() {
        if isScheduledListening {
            backgroundTaskService.startBackgroundTask()
        }
    }
    
    private func handleAppEnterForeground() {
        backgroundTaskService.endBackgroundTask()
    }
    
    // MARK: - Deinitializer
    
    deinit {
        scheduleTimer?.invalidate()
        recordingTimer?.invalidate()
        stopContinuousListening()
        cancellables.forEach { $0.cancel() }
    }
}

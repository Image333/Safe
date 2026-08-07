import Foundation
import AVFoundation
import Speech

/// Gestionnaire principal de l'écoute vocale en arrière-plan
final class VoiceTriggerManager: NSObject {
    static let shared = VoiceTriggerManager()
    
    // MARK: - Configuration
    private var keyword: String = ""
    private var recordingDurationSec: Int = 15
    private var scheduleConfig: ScheduleConfig?
    
    // MARK: - State
    private(set) var isListening = false
    private(set) var isRecording = false
    
    // MARK: - Audio Components
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Recording Components
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    
    // MARK: - Schedule Timer
    private var scheduleCheckTimer: Timer?
    
    // MARK: - Callbacks
    var onKeywordDetected: (() -> Void)?
    var onRecordingStarted: (() -> Void)?
    var onRecordingFinished: ((URL) -> Void)?
    var onError: ((Error) -> Void)?
    
    private override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func configure(keyword: String, recordingDurationSec: Int, schedule: ScheduleConfig?) {
        self.keyword = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.recordingDurationSec = max(5, min(600, recordingDurationSec))
        self.scheduleConfig = schedule
    }
    
    func startListening() throws {
        guard !isListening else { return }
        guard !keyword.isEmpty else {
            throw VoiceTriggerError.noKeyword
        }
        
        // Vérifier les permissions
        try checkPermissions()
        
        // Configurer la session audio pour le background
        try configureAudioSession()
        
        // Démarrer l'écoute si dans la plage horaire
        if isWithinSchedule() {
            try startSpeechRecognition()
        }
        
        // Démarrer le timer de vérification de plage horaire
        startScheduleCheckTimer()
        
        isListening = true
        print("🎤 VoiceTrigger: Écoute démarrée pour '\(keyword)'")
    }
    
    func stopListening() {
        guard isListening else { return }
        
        stopScheduleCheckTimer()
        stopSpeechRecognition()
        stopRecording()
        
        isListening = false
        print("🎤 VoiceTrigger: Écoute arrêtée")
    }
    
    // MARK: - Schedule Management
    
    private func startScheduleCheckTimer() {
        // Vérifier toutes les minutes si on est dans la plage horaire
        scheduleCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkScheduleAndUpdateListening()
        }
    }
    
    private func stopScheduleCheckTimer() {
        scheduleCheckTimer?.invalidate()
        scheduleCheckTimer = nil
    }
    
    private func checkScheduleAndUpdateListening() {
        let shouldBeActive = isWithinSchedule()
        let isCurrentlyRecognizing = recognitionTask != nil
        
        if shouldBeActive && !isCurrentlyRecognizing {
            // Démarrer l'écoute
            do {
                try startSpeechRecognition()
                print("🎤 VoiceTrigger: Entrée dans la plage horaire - écoute activée")
            } catch {
                print("⚠️ VoiceTrigger: Erreur démarrage écoute: \(error)")
            }
        } else if !shouldBeActive && isCurrentlyRecognizing {
            // Arrêter l'écoute (hors plage horaire)
            stopSpeechRecognition()
            print("🎤 VoiceTrigger: Hors plage horaire - écoute suspendue")
        }
    }
    
    private func isWithinSchedule() -> Bool {
        guard let schedule = scheduleConfig, schedule.enabled else {
            return true // Pas de plage configurée = toujours actif
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Obtenir le jour actuel (0 = Dimanche, 1 = Lundi, ...)
        let weekday = calendar.component(.weekday, from: now) - 1 // weekday est 1-based
        
        // Vérifier si le jour est dans la liste
        guard schedule.days.contains(weekday) else {
            return false
        }
        
        // Vérifier l'heure
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentMinutes = hour * 60 + minute
        
        let startMinutes = schedule.startHour * 60 + schedule.startMinute
        let endMinutes = schedule.endHour * 60 + schedule.endMinute
        
        // Gérer le cas où la plage traverse minuit
        if startMinutes > endMinutes {
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        } else {
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        }
    }
    
    // MARK: - Permissions
    
    private func checkPermissions() throws {
        // Vérifier permission micro
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        guard micStatus == .granted else {
            throw VoiceTriggerError.microphonePermissionDenied
        }
        
        // Vérifier permission reconnaissance vocale
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        guard speechStatus == .authorized else {
            throw VoiceTriggerError.speechRecognitionPermissionDenied
        }
    }
    
    // MARK: - Audio Session
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers, .duckOthers]
        )
        
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Speech Recognition
    
    private func startSpeechRecognition() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceTriggerError.speechRecognizerUnavailable
        }
        
        // Arrêter toute tâche précédente
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Créer le moteur audio
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw VoiceTriggerError.audioEngineCreationFailed
        }
        
        // Créer la requête de reconnaissance
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceTriggerError.recognitionRequestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Pour de meilleurs résultats
        
        // Configurer le nœud d'entrée audio
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Démarrer le moteur audio
        audioEngine.prepare()
        try audioEngine.start()
        
        // Démarrer la reconnaissance
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
    }
    
    private func stopSpeechRecognition() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            // Si c'est une erreur de timeout ou d'arrêt normal, redémarrer
            let nsError = error as NSError
            if nsError.domain == "kAFAssistantErrorDomain" {
                // Redémarrer l'écoute après une courte pause
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.isListening, self.isWithinSchedule() else { return }
                    try? self.startSpeechRecognition()
                }
            } else {
                print("⚠️ VoiceTrigger: Erreur reconnaissance: \(error)")
                onError?(error)
            }
            return
        }
        
        guard let result = result else { return }
        
        let transcription = result.bestTranscription.formattedString.lowercased()
        print("🎤 Transcription: '\(transcription)' | Mot-clé recherché: '\(keyword)' | isFinal: \(result.isFinal)")
        
        // Vérifier si le mot-clé est détecté (comparaison flexible)
        let keywordLower = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let transcriptionLower = transcription.lowercased()
        
        if transcriptionLower.contains(keywordLower) {
            print("🚨 VoiceTrigger: Mot-clé '\(keyword)' DÉTECTÉ dans '\(transcription)'!")
            triggerRecording()
        }
        
        // Si la reconnaissance est finale, redémarrer pour continuer l'écoute
        if result.isFinal && isListening && isWithinSchedule() {
            stopSpeechRecognition()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                try? self?.startSpeechRecognition()
            }
        }
    }
    
    // MARK: - Recording
    
    private func triggerRecording() {
        guard !isRecording else { return }
        
        // Arrêter temporairement la reconnaissance pour enregistrer
        stopSpeechRecognition()
        
        onKeywordDetected?()
        
        do {
            try startRecording()
        } catch {
            print("⚠️ VoiceTrigger: Erreur démarrage enregistrement: \(error)")
            onError?(error)
            // Reprendre l'écoute
            if isListening && isWithinSchedule() {
                try? startSpeechRecognition()
            }
        }
    }
    
    private func startRecording() throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("emergency_\(Date().timeIntervalSince1970).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()
        
        isRecording = true
        onRecordingStarted?()
        
        print("🔴 VoiceTrigger: Enregistrement démarré (\(recordingDurationSec)s)")
        
        // Timer pour arrêter l'enregistrement
        recordingTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(recordingDurationSec), repeats: false) { [weak self] _ in
            self?.stopRecording()
        }
    }
    
    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard isRecording, let recorder = audioRecorder else { return }
        
        let url = recorder.url
        recorder.stop()
        audioRecorder = nil
        isRecording = false
        
        print("⬛ VoiceTrigger: Enregistrement terminé")
        onRecordingFinished?(url)
        
        // Reprendre l'écoute si toujours actif
        if isListening && isWithinSchedule() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                try? self?.startSpeechRecognition()
            }
        }
    }
    
    // MARK: - Interruption Handling
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🎤 VoiceTrigger: Interruption audio - pause")
            stopSpeechRecognition()
            
        case .ended:
            print("🎤 VoiceTrigger: Fin interruption audio")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && isListening && isWithinSchedule() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        try? self?.configureAudioSession()
                        try? self?.startSpeechRecognition()
                    }
                }
            }
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            // Route audio changée, redémarrer si nécessaire
            if isListening && isWithinSchedule() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.stopSpeechRecognition()
                    try? self?.startSpeechRecognition()
                }
            }
        default:
            break
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceTriggerManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("⚠️ VoiceTrigger: Enregistrement échoué")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("⚠️ VoiceTrigger: Erreur encodage: \(error)")
            onError?(error)
        }
    }
}

// MARK: - Supporting Types

struct ScheduleConfig {
    let enabled: Bool
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let days: [Int] // 0 = Dimanche, 1 = Lundi, ...
}

enum VoiceTriggerError: LocalizedError {
    case noKeyword
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case speechRecognizerUnavailable
    case audioEngineCreationFailed
    case recognitionRequestCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .noKeyword:
            return "Aucun mot-clé configuré"
        case .microphonePermissionDenied:
            return "Permission micro refusée"
        case .speechRecognitionPermissionDenied:
            return "Permission reconnaissance vocale refusée"
        case .speechRecognizerUnavailable:
            return "Reconnaissance vocale non disponible"
        case .audioEngineCreationFailed:
            return "Impossible de créer le moteur audio"
        case .recognitionRequestCreationFailed:
            return "Impossible de créer la requête de reconnaissance"
        }
    }
}

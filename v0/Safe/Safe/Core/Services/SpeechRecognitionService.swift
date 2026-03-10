//
//  SpeechRecognitionService.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import Speech
import AVFoundation
import Combine

/// Service de reconnaissance vocale
/// 
/// Implémente la reconnaissance vocale continue avec gestion d'erreurs robuste.
/// Conforme aux principes SOLID et Clean Architecture.
final class SpeechRecognitionService: NSObject, SpeechRecognitionServiceProtocol, ObservableObject {
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngineService: AudioEngineServiceProtocol
    
    // MARK: - Published Properties
    @Published private(set) var transcribedText: String = ""
    @Published private(set) var recognitionStatus: RecognitionStatus = .idle
    
    // MARK: - Private Publishers
    private let transcriptionSubject = PassthroughSubject<String, SpeechRecognitionError>()
    private let statusSubject = PassthroughSubject<RecognitionStatus, Never>()
    
    // MARK: - Initialization
    
    init(audioEngineService: AudioEngineServiceProtocol, locale: Locale = Locale(identifier: "fr-FR")) {
        self.audioEngineService = audioEngineService
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        super.init()
        
        setupRecognizer()
    }
    
    // MARK: - SpeechRecognitionServiceProtocol Implementation
    
    var isAvailable: Bool {
        guard let recognizer = speechRecognizer else { return false }
        return recognizer.isAvailable
    }
    
    var currentLocale: Locale {
        return speechRecognizer?.locale ?? Locale(identifier: "fr-FR")
    }
    
    func requestAuthorization() -> AnyPublisher<Bool, Never> {
        return Future<Bool, Never> { promise in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    let granted = (status == .authorized)
                    promise(.success(granted))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func startContinuousRecognition() -> AnyPublisher<String, SpeechRecognitionError> {
        // Nettoyer les ressources existantes
        stopRecognition()
        
        // Vérifier la disponibilité
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            let error = SpeechRecognitionError.notAvailable
            transcriptionSubject.send(completion: .failure(error))
            return transcriptionSubject.eraseToAnyPublisher()
        }
        
        // Vérifier les permissions
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            let error = SpeechRecognitionError.notAuthorized
            transcriptionSubject.send(completion: .failure(error))
            return transcriptionSubject.eraseToAnyPublisher()
        }
        
        // Créer la requête de reconnaissance
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            let error = SpeechRecognitionError.recognitionFailed
            transcriptionSubject.send(completion: .failure(error))
            return transcriptionSubject.eraseToAnyPublisher()
        }
        
        // Configuration de la requête
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Démarrer la tâche de reconnaissance
        startRecognitionTask(with: recognitionRequest, using: speechRecognizer)
        
        // Configurer le tap audio
        setupAudioTap(for: recognitionRequest)
        
        // Mettre à jour le statut
        updateRecognitionStatus(.listening)
        
        return transcriptionSubject.eraseToAnyPublisher()
    }
    
    func stopRecognition() {
        // Arrêter la tâche de reconnaissance
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Terminer la requête
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Mettre à jour le statut
        updateRecognitionStatus(.idle)
        
    }
    
    func checkPermissions() -> AnyPublisher<Bool, Never> {
        return Future<Bool, Never> { promise in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    promise(.success(status == .authorized))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func setLocale(_ locale: Locale) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        setupRecognizer()
    }
    
    func clearTranscription() {
        DispatchQueue.main.async { [weak self] in
            self?.transcribedText = ""
        }
    }
    
    // MARK: - Private Methods
    
    private func setupRecognizer() {
        speechRecognizer?.delegate = self
    }
    
    private func startRecognitionTask(with request: SFSpeechAudioBufferRecognitionRequest, using recognizer: SFSpeechRecognizer) {
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }
    }
    
    private func setupAudioTap(for request: SFSpeechAudioBufferRecognitionRequest) {
        do {
            // Obtenir le format natif de l'input
            let inputFormat = audioEngineService.getCurrentInputFormat()
            
            // Vérifier que le format est valide avant de l'utiliser
            guard inputFormat.sampleRate > 0 else {
                
                // Utiliser un format par défaut fiable pour la reconnaissance vocale
                let defaultFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: 16000, // 16 kHz est idéal pour la reconnaissance vocale
                    channels: 1,
                    interleaved: false
                )
                
                // Installer le tap avec le format par défaut
                try audioEngineService.installTap(
                    on: 0,
                    bufferSize: 1024,
                    format: defaultFormat
                ) { [weak request] buffer, _ in
                    request?.append(buffer)
                }
                
                return
            }
            
            // Installer le tap avec le format natif
            try audioEngineService.installTap(
                on: 0,
                bufferSize: 1024,
                format: inputFormat
            ) { [weak request] buffer, _ in
                request?.append(buffer)
            }
            
            
        } catch {
            transcriptionSubject.send(completion: .failure(.audioEngineError))
        }
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        var isFinal = false
        
        if let result = result {
            // Transcription disponible
            let transcription = result.bestTranscription.formattedString
            
            DispatchQueue.main.async { [weak self] in
                self?.transcribedText = transcription
            }
            
            // Envoyer la transcription
            transcriptionSubject.send(transcription)
            
            isFinal = result.isFinal
        }
        
        if let error = error {
            let nsError = error as NSError
            
            // L'erreur 301 (annulation) peut être normale, ne pas la traiter comme une vraie erreur
            if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                // Ne pas envoyer d'erreur ni mettre à jour le statut
                return
            }
            
            let recognitionError = mapSpeechError(error)
            transcriptionSubject.send(completion: .failure(recognitionError))
            updateRecognitionStatus(.error)
        }
        
        if isFinal {
            // Effacer la transcription pour éviter la détection en boucle
            DispatchQueue.main.async { [weak self] in
                self?.transcribedText = ""
            }
            
            // Redémarrer automatiquement pour une écoute continue
            restartRecognitionForContinuousListening()
        }
    }
    
    private func restartRecognitionForContinuousListening() {
        // Ne redémarrer que si on est en mode écoute active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Vérifier que la reconnaissance est toujours en mode écoute
            guard self.recognitionStatus == .listening else {
                return
            }
            
            // Redémarrer la reconnaissance pour l'écoute continue
            let _ = self.startContinuousRecognition()
        }
    }
    
    private func updateRecognitionStatus(_ status: RecognitionStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.recognitionStatus = status
            self?.statusSubject.send(status)
        }
    }
    
    private func mapSpeechError(_ error: Error) -> SpeechRecognitionError {
        if let nsError = error as NSError? {
            switch nsError.code {
            case 1700: // kSpeechRecognitionErrorCodeNotAuthorized
                return .notAuthorized
            case 1701: // kSpeechRecognitionErrorCodeNotAvailable  
                return .notAvailable
            default:
                return .recognitionFailed
            }
        }
        
        return .recognitionFailed
    }
    
    // MARK: - Deinitializer
    
    deinit {
        stopRecognition()
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async { [weak self] in
            if available {
                self?.updateRecognitionStatus(.idle)
            } else {
                self?.updateRecognitionStatus(.unavailable)
            }
        }
    }
}

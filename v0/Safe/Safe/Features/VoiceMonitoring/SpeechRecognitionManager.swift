//
//  SpeechRecognitionManager.swift
//  Safe
//
//  Created by Imane on 04/08/2025.
//

import Foundation
import Speech
import AVFoundation

class SpeechRecognitionManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isListening = false
    @Published var detectedText = ""
    @Published var keywordDetected = false
    
    // Mots-clés à détecter
    // TODO remplacer 
    private let keywords = ["aide", "secours", "help", "fleur"]
    
    // Callback pour déclencher l'enregistrement
    var onKeywordDetected: (() -> Void)?
    
    init() {
        requestSpeechAuthorization { _ in }
    }
    
    private func requestSpeechAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    completion(true)
                case .denied, .restricted, .notDetermined:
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }
    
    func startListening() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return
        }
        
        // Demander l'autorisation microphone avec API iOS 17+
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self?.startSpeechRecognition()
                    } else {
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self?.startSpeechRecognition()
                    } else {
                    }
                }
            }
        }
    }
    
    private func startSpeechRecognition() {
        // Nettoyer les tâches précédentes
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Configuration de la session audio
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }
        
        // requête de reconnaissance
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configuration du moteur audio
        let inputNode = audioEngine.inputNode
        
        // Créer un format audio compatible
        let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            return
        }
        
        // Démarrer la reconnaissance
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    let transcription = result.bestTranscription.formattedString.lowercased()
                    self?.detectedText = transcription
                    self?.checkForKeywords(in: transcription)
                }
                
                if error != nil || result?.isFinal == true {
                    // Redémarrer l'écoute après une pause
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if self?.isListening == true {
                            self?.startSpeechRecognition()
                        }
                    }
                }
            }
        }
        
        isListening = true
    }
    
    private func checkForKeywords(in text: String) {
        for keyword in keywords {
            if text.contains(keyword) {
                keywordDetected = true
                onKeywordDetected?()
                break
            }
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        
        // Désactiver la session audio
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
        }
    }
}

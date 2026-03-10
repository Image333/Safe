//
//  AudioEngineService.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import AVFoundation
import Combine
import UIKit

/// Service de gestion du moteur audio
/// 
/// Responsable de la configuration et de la gestion du moteur audio AVFoundation.
/// Applique les principes Clean Architecture avec séparation des responsabilités.
final class AudioEngineService: AudioEngineServiceProtocol, ObservableObject {
    
    // MARK: - Private Properties
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioSession: AVAudioSession?
    private var interruptionObserver: NSObjectProtocol?
    
    // MARK: - Published Properties
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var audioLevel: Float = 0.0
    
    // Flag pour empêcher le redémarrage automatique pendant la lecture d'enregistrements
    private var isPlaybackInProgress: Bool = false
    // Flag pour éviter les appels multiples de la notification de fin de lecture
    private var isHandlingPlaybackFinish: Bool = false
    
    // MARK: - Initialization
    
    init() {
        setupInterruptionObserver()
        setupAdditionalObservers()
    }
    
    // MARK: - AudioEngineServiceProtocol Implementation
    
    var isEngineRunning: Bool {
        return audioEngine.isRunning
    }
    
    var currentInputFormat: AVAudioFormat? {
        return inputNode?.inputFormat(forBus: 0)
    }
    
    func validateAudioSetup() -> Bool {
        if audioSession == nil {
            setupAudioSession()
        }
        
        guard let audioSession = audioSession else {
            return false
        }
        
        if #available(iOS 17.0, *) {
            guard AVAudioApplication.shared.recordPermission == .granted else {
                return false
            }
        } else {
            guard audioSession.recordPermission == .granted else {
                return false
            }
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        guard inputFormat.sampleRate > 0 else {
            return false
        }
        
        return true
    }
    
    func startRecognition(completion: @escaping (Result<Void, AudioEngineError>) -> Void) {
        if audioSession == nil {
            setupAudioSession()
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        if !checkMicrophonePermission() {
            completion(.failure(.microphonePermissionDenied))
            return
        }
        
        if audioEngine.isRunning {
            stopRecognition()
        }
        
        do {
            do {
                try audioSession?.setActive(false, options: [])
                Thread.sleep(forTimeInterval: 0.2)
                try audioSession?.setActive(true, options: [.notifyOthersOnDeactivation])
            } catch let error as NSError {
                if error.domain != "NSOSStatusErrorDomain" || error.code != 560557684 {
                    // Continue despite errors
                }
            }
            
            Thread.sleep(forTimeInterval: 0.5)
            
            try prepareAudioEngine()
            
            do {
                try audioEngine.start()
                isRecording = true
                completion(.success(()))
            } catch let error as NSError {
                if error.domain == "NSOSStatusErrorDomain" && error.code == 560557684 {
                    isRecording = true
                    completion(.success(()))
                } else if error.domain == "com.apple.coreaudio.avfaudio" && error.code == 2003329396 {
                    handleAudioEngineBlockage(completion: completion)
                } else {
                    let engineError = mapAVAudioEngineError(error)
                    completion(.failure(engineError))
                }
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == "NSOSStatusErrorDomain" && nsError.code == 560557684 {
                isRecording = true
                completion(.success(()))
            } else if nsError.domain == "com.apple.coreaudio.avfaudio" && nsError.code == 2003329396 {
                handleAudioEngineBlockage(completion: completion)
            } else {
                try? audioSession?.setActive(false, options: [])
                let engineError = mapAVAudioEngineError(error)
                completion(.failure(engineError))
            }
        }
    }
    
    private func checkMicrophonePermission() -> Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }
    
    func stopRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        try? audioSession?.setActive(false, options: [])
        isRecording = false
    }
    
    func installTap(on bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) throws {
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: bus)
        
        let inputFormat = inputNode.inputFormat(forBus: bus)
        let tapFormat = format ?? AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: inputFormat.channelCount,
            interleaved: false
        )
        
        guard let finalTapFormat = tapFormat, finalTapFormat.sampleRate > 0 else {
            throw AudioEngineError.invalidAudioFormat
        }
        
        inputNode.installTap(onBus: bus, bufferSize: bufferSize, format: finalTapFormat, block: block)
    }
    
    func getInputNode() -> AVAudioInputNode {
        return audioEngine.inputNode
    }
    
    func getCurrentInputFormat() -> AVAudioFormat {
        let inputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        
        if inputFormat.sampleRate <= 0 {
            return AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            )!
        }
        
        return inputFormat
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        // Ignorer les erreurs spécifiques connues qui n'affectent pas la fonctionnalité
        let setupWithErrorHandling = { [weak self] in
            do {
                // Configuration pour éviter les erreurs "Failed to set properties"
                
                // 1. Première étape: désactiver la session existante pour nettoyer l'état
                try self?.audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
                
                // Petit délai pour laisser la session se réinitialiser
                Thread.sleep(forTimeInterval: 0.2)
                
                // 2. Configuration plus robuste - avec des options pour prioritiser l'enregistrement
                // Options simplifiées et plus stables pour éviter les erreurs de compatibilité
                let configOptions: [(AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)] = [
                    // Option 1: Configuration optimale pour l'enregistrement avec compatibilité Bluetooth
                    (.playAndRecord, .default, [.mixWithOthers, .allowBluetoothHFP, .defaultToSpeaker]),
                    
                    // Option 2: Configuration simple d'enregistrement sans options complexes
                    (.record, .default, [.mixWithOthers]),
                    
                    // Option 3: Configuration spécifique pour la parole
                    (.playAndRecord, .spokenAudio, [.mixWithOthers, .allowBluetoothHFP])
                ]
                
                var configSuccess = false
                var lastError: Error?
                
                // Essayer chaque configuration jusqu'à ce qu'une réussisse
                for (category, mode, options) in configOptions {
                    do {
                        try self?.audioSession?.setCategory(category, mode: mode, options: options)
                        configSuccess = true
                        break
                    } catch {
                        lastError = error
                    }
                }
                
                if !configSuccess {
                    if let error = lastError {
                        let nsError = error as NSError
                        if nsError.domain != "NSOSStatusErrorDomain" || nsError.code != 560557684 {
                            throw error
                        }
                    } else {
                        throw NSError(domain: "AudioEngineServiceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Configuration de session échouée"])
                    }
                }
                
                // 3. Configurer des préférences de manière séparée, ignorer les erreurs
                // Utiliser des valeurs plus stables et universellement supportées
                try? self?.audioSession?.setPreferredSampleRate(48000.0) // Valeur plus standard
                try? self?.audioSession?.setPreferredIOBufferDuration(0.05) // Augmenter pour plus de stabilité
                
                // 4. Ajouter un observateur pour la notification de DÉBUT de lecture
                NotificationCenter.default.addObserver(
                    self as Any,
                    selector: #selector(self?.handleAudioPlaybackWillStart),
                    name: Notification.Name("AudioPlaybackWillStartNotification"),
                    object: nil
                )
                
                // 5. Ajouter un observateur pour la notification personnalisée de fin de lecture
                NotificationCenter.default.addObserver(
                    self as Any,
                    selector: #selector(self?.handleAudioPlaybackDidFinish),
                    name: Notification.Name("AudioPlaybackDidFinishNotification"),
                    object: nil
                )
                
                // 6. Ajouter un observateur pour la notification de fin d'enregistrement
                NotificationCenter.default.addObserver(
                    self as Any,
                    selector: #selector(self?.handleAudioRecordingDidFinish),
                    name: Notification.Name("AudioRecordingDidFinishNotification"),
                    object: nil
                )
                
            } catch {
                let nsError = error as NSError
                if nsError.domain != "NSOSStatusErrorDomain" || nsError.code != 560557684 {
                    try? self?.audioSession?.setCategory(.record, options: .mixWithOthers)
                }
            }
        }
        
        // Exécuter la configuration sur un thread en arrière-plan
        // pour éviter le blocage de l'interface utilisateur
        DispatchQueue.global(qos: .userInitiated).async {
            setupWithErrorHandling()
        }
    }
    
    @objc private func handleAudioPlaybackWillStart() {
        isPlaybackInProgress = true
    }
    
    @objc private func handleAudioPlaybackDidFinish() {
        guard !isHandlingPlaybackFinish else {
            return
        }
        
        isHandlingPlaybackFinish = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.isPlaybackInProgress = false
            self?.isHandlingPlaybackFinish = false
        }
    }
    
    @objc private func handleAudioRecordingDidFinish() {
        // Delegate restart handling to VoiceMonitoringService
    }
    
    private func setupAdditionalObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemInterruption),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .categoryChange:
            if isRecording && !audioEngine.isRunning && !isPlaybackInProgress {
                restartRecognitionAfterInterruption()
            }
        default:
            break
        }
    }
    
    @objc private func handleSystemInterruption(notification: Notification) {
        if isRecording && !audioEngine.isRunning && !isPlaybackInProgress {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.restartRecognitionAfterInterruption()
            }
        }
    }
    
    private func prepareAudioEngine() throws {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        
        Thread.sleep(forTimeInterval: 0.3)
        
        do {
            try audioSession?.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            // Continue despite errors
        }
        
        Thread.sleep(forTimeInterval: 0.2)
        
        inputNode = audioEngine.inputNode
        
        guard let inputNode = inputNode else {
            throw AudioEngineError.configurationFailed
        }
        
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        guard inputFormat.sampleRate > 0 else {
            throw AudioEngineError.invalidAudioFormat
        }
        
        inputNode.removeTap(onBus: 0)
        let bufferSize: AVAudioFrameCount = 4096
        
        do {
            let tapFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: inputFormat.sampleRate,
                channels: 1,
                interleaved: false
            )
            
            guard let format = tapFormat else {
                throw AudioEngineError.invalidAudioFormat
            }
            
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { _, _ in
                // Silent tap to activate audio input
            }
        } catch {
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { _, _ in
                // Silent tap
            }
        }
        
        audioEngine.prepare()
        Thread.sleep(forTimeInterval: 0.2)
    }
    
    private func mapAVAudioEngineError(_ error: Error) -> AudioEngineError {
        if let nsError = error as NSError? {
            if nsError.domain == "NSOSStatusErrorDomain" && nsError.code == 560557684 {
                return .configurationWarning
            }
            
            if nsError.code == 2003329396 {
                return .hardwareConfigurationError
            }
            
            switch nsError.code {
            case -50:
                return .invalidAudioFormat
            case 1701:
                return .audioSessionError
            case 561015905:
                return .cannotStartInCurrentContext
            default:
                return .unknownError(error)
            }
        }
        
        return .unknownError(error)
    }
    
    // MARK: - Interruption Handling
    
    private func setupInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main) { [weak self] notification in
                guard let self = self else { return }
                
                guard let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                    return
                }
                
                switch type {
                case .began:
                    break
                    
                case .ended:
                    if self.isPlaybackInProgress {
                        return
                    }
                    
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                       AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                        if self.isRecording {
                            self.restartRecognitionAfterInterruption()
                        }
                    }
                @unknown default:
                    break
                }
            }
    }
    
    private func restartRecognitionAfterInterruption() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            
            if !self.audioEngine.isRunning && self.isRecording {
                self.setupAudioSession()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startRecognition { result in
                        switch result {
                        case .success:
                            break
                        case .failure:
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.startRecognition { _ in }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func handleAudioEngineBlockage(completion: @escaping (Result<Void, AudioEngineError>) -> Void) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.reset()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.audioSession?.setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                // Continue despite errors
            }
            
            Thread.sleep(forTimeInterval: 2.0)
            
            self.audioEngine = AVAudioEngine()
            self.setupAudioSession()
            
            Thread.sleep(forTimeInterval: 1.0)
            
            do {
                try self.audioSession?.setActive(true, options: [.notifyOthersOnDeactivation])
            } catch {
                // Continue despite errors
            }
            
            Thread.sleep(forTimeInterval: 1.0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                
                self.startRecognition { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case .failure:
                        completion(.failure(.hardwareConfigurationError))
                    }
                }
            }
        }
    }
    
    // MARK: - Deinitializer
    
    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("AudioPlaybackWillStartNotification"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("AudioPlaybackDidFinishNotification"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("AudioRecordingDidFinishNotification"), object: nil)
        
        stopRecognition()
        try? audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
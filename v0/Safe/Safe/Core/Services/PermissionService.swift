//
//  PermissionService.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import AVFoundation
import Speech
import UserNotifications
import Combine
import UIKit

/// Service de gestion des permissions
/// 
/// Centralise la gestion de toutes les permissions requises par l'application.
/// Implémente les bonnes pratiques UX pour les demandes de permissions.
final class PermissionService: PermissionServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var microphonePermission: PermissionStatus = .notDetermined
    @Published private(set) var speechRecognitionPermission: PermissionStatus = .notDetermined  
    @Published private(set) var notificationPermission: PermissionStatus = .notDetermined
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        checkAllCurrentPermissions()
    }
    
    // MARK: - PermissionServiceProtocol Implementation
    
    func checkMicrophonePermission() -> PermissionStatus {
        if #available(iOS 17.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            switch status {
            case .granted:
                return .authorized
            case .denied:
                return .denied
            case .undetermined:
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        } else {
            let status = AVAudioSession.sharedInstance().recordPermission
            return mapAudioPermissionStatus(status)
        }
    }
    
    func checkSpeechRecognitionPermission() -> PermissionStatus {
        let status = SFSpeechRecognizer.authorizationStatus()
        return mapSpeechAuthorizationStatus(status)
    }
    
    func requestAllPermissions() -> AnyPublisher<Bool, Never> {
        // Utiliser une approche synchrone pour minimiser les délais
        return Future<Bool, Never> { [weak self] promise in
            Task {
                guard let self = self else {
                    promise(.success(false))
                    return
                }
                
                // Vérifier d'abord les permissions actuelles de manière optimisée
                let currentMic = self.checkMicrophonePermission()
                let currentSpeech = self.checkSpeechRecognitionPermission()
                let currentNotif = await self.checkNotificationPermissionAsync()
                
                // Si tout est déjà autorisé, retourner immédiatement
                if currentMic == .authorized && currentSpeech == .authorized && currentNotif == .authorized {
                    await MainActor.run {
                        self.microphonePermission = .authorized
                        self.speechRecognitionPermission = .authorized
                        self.notificationPermission = .authorized
                    }
                    promise(.success(true))
                    return
                }
                
                // Demander les permissions en parallèle pour gagner du temps
                async let micResult: Bool = {
                    if currentMic == .authorized { return true }
                    return await self.requestMicrophonePermissionAsync()
                }()
                
                async let speechResult: Bool = {
                    if currentSpeech == .authorized { return true }
                    return await self.requestSpeechRecognitionPermissionAsync()
                }()
                
                async let notifResult: Bool = {
                    if currentNotif == .authorized { return true }
                    return await self.requestNotificationPermissionAsync()
                }()
                
                let (micGranted, speechGranted, notifGranted) = await (micResult, speechResult, notifResult)
                
                await MainActor.run {
                    self.microphonePermission = micGranted ? .authorized : .denied
                    self.speechRecognitionPermission = speechGranted ? .authorized : .denied
                    self.notificationPermission = notifGranted ? .authorized : .denied
                }
                
                let allGranted = micGranted && speechGranted && notifGranted
                promise(.success(allGranted))
            }
        }.eraseToAnyPublisher()
    }
    
    func requestMicrophonePermission() -> AnyPublisher<Bool, Never> {
        return Future<Bool, Never> { [weak self] promise in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        self?.microphonePermission = granted ? .authorized : .denied
                        promise(.success(granted))
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        self?.microphonePermission = granted ? .authorized : .denied
                        promise(.success(granted))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func requestSpeechRecognitionPermission() -> AnyPublisher<Bool, Never> {
        return Future<Bool, Never> { [weak self] promise in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    let granted = status == .authorized
                    self?.speechRecognitionPermission = self?.mapSpeechAuthorizationStatus(status) ?? .denied
                    promise(.success(granted))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func requestNotificationPermission() -> AnyPublisher<Bool, Never> {
        return Future<Bool, Never> { [weak self] promise in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                DispatchQueue.main.async {
                    self?.notificationPermission = granted ? .authorized : .denied
                    
                    if error != nil {
                    }
                    
                    promise(.success(granted))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func checkAllCurrentPermissions() {
        updateMicrophonePermissionStatus()
        updateSpeechRecognitionPermissionStatus()
        checkNotificationPermission()
    }
    
    func areAllPermissionsGranted() -> Bool {
        return microphonePermission == .authorized &&
               speechRecognitionPermission == .authorized &&
               notificationPermission == .authorized
    }
    
    func getMissingPermissions() -> [PermissionType] {
        var missing: [PermissionType] = []
        
        if microphonePermission != .authorized {
            missing.append(.microphone)
        }
        
        if speechRecognitionPermission != .authorized {
            missing.append(.speechRecognition)
        }
        
        if notificationPermission != .authorized {
            missing.append(.notifications)
        }
        
        return missing
    }
    
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else {
            return
        }
        
        UIApplication.shared.open(settingsUrl) { success in
        }
    }
    
    // MARK: - Private Methods
    
    private func updateMicrophonePermissionStatus() {
        if #available(iOS 17.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            switch status {
            case .granted:
                microphonePermission = .authorized
            case .denied:
                microphonePermission = .denied
            case .undetermined:
                microphonePermission = .notDetermined
            @unknown default:
                microphonePermission = .notDetermined
            }
        } else {
            let status = AVAudioSession.sharedInstance().recordPermission
            microphonePermission = mapAudioPermissionStatus(status)
        }
    }
    
    private func updateSpeechRecognitionPermissionStatus() {
        let status = SFSpeechRecognizer.authorizationStatus()
        speechRecognitionPermission = mapSpeechAuthorizationStatus(status)
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationPermission = self?.mapNotificationAuthorizationStatus(settings.authorizationStatus) ?? .notDetermined
            }
        }
    }
    
    private func mapAudioPermissionStatus(_ status: AVAudioSession.RecordPermission) -> PermissionStatus {
        switch status {
        case .granted:
            return .authorized
        case .denied:
            return .denied
        case .undetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    private func mapSpeechAuthorizationStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    private func mapNotificationAuthorizationStatus(_ status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .provisional:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .ephemeral:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
}

// MARK: - PermissionService Extension for User Interface

extension PermissionService {
    
    /// Retourne un message descriptif pour une permission donnée
    func getPermissionDescription(for type: PermissionType) -> String {
        switch type {
        case .microphone:
            return "L'application a besoin d'accéder au microphone pour détecter les mots-clés d'urgence."
        case .speechRecognition:
            return "La reconnaissance vocale est nécessaire pour analyser vos paroles et détecter les situations d'urgence."
        case .notifications:
            return "Les notifications permettent de vous alerter même lorsque l'application est en arrière-plan."
        }
    }
    
    /// Retourne un titre pour une permission donnée
    func getPermissionTitle(for type: PermissionType) -> String {
        switch type {
        case .microphone:
            return "Accès au microphone"
        case .speechRecognition:
            return "Reconnaissance vocale"
        case .notifications:
            return "Notifications"
        }
    }
}

// MARK: - Async Permission Methods (Optimized)
    
extension PermissionService {
    
    private func requestMicrophonePermissionAsync() async -> Bool {
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
    }
    
    private func requestSpeechRecognitionPermissionAsync() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    private func requestNotificationPermissionAsync() async -> Bool {
        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func checkNotificationPermissionAsync() async -> PermissionStatus {
        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                // Implémentation directe du mappage dans le closure sans référence à self
                let status: PermissionStatus
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    status = .authorized
                case .denied:
                    status = .denied
                case .notDetermined:
                    status = .notDetermined
                @unknown default:
                    status = .notDetermined
                }
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - Proactive Permission Management
    
extension PermissionService {
    
    /// Demande toutes les permissions nécessaires de manière proactive
    /// Cette méthode doit être appelée dès qu'on active la surveillance
    func requestAllPermissionsProactively() async -> Bool {
        
        // Demander d'abord les permissions de base en parallèle
        async let micResult = requestMicrophonePermissionAsync()
        async let speechResult = requestSpeechRecognitionPermissionAsync()
        async let notifResult = requestNotificationPermissionAsync()
        
        let (micGranted, speechGranted, notifGranted) = await (micResult, speechResult, notifResult)
        
        // Demander ensuite les permissions d'arrière-plan si les autres sont accordées
        var backgroundGranted = true
        if micGranted && speechGranted {
            backgroundGranted = await requestBackgroundPermissions()
        }
        
        await MainActor.run {
            self.microphonePermission = micGranted ? .authorized : .denied
            self.speechRecognitionPermission = speechGranted ? .authorized : .denied
            self.notificationPermission = notifGranted ? .authorized : .denied
        }
        
        let allGranted = micGranted && speechGranted && notifGranted && backgroundGranted
        
        return allGranted
    }
    
    /// Demande les permissions d'arrière-plan nécessaires
    private func requestBackgroundPermissions() async -> Bool {
        
        // Configuration pour l'exécution en arrière-plan
        let configurationSuccess = await MainActor.run { () -> Bool in
            // Demander l'autorisation d'exécution en arrière-plan
            let audioSession = AVAudioSession.sharedInstance()
            
            do {
                // Configuration pour permettre l'audio en arrière-plan
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [
                        .allowBluetoothHFP,
                        .allowBluetoothA2DP,
                        .mixWithOthers,
                        .defaultToSpeaker,
                        .duckOthers
                    ]
                )
                
                // Demander les notifications critiques pour l'arrière-plan
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound, .criticalAlert, .providesAppNotificationSettings]
                ) { granted, error in
                    if error != nil {
                    }
                }
                
                return true
                
            } catch {
                return false
            }
        }
        
        return configurationSuccess
    }
    
    /// Vérifie si toutes les permissions essentielles sont accordées
    func areEssentialPermissionsGranted() -> Bool {
        let micOk = microphonePermission == .authorized
        let speechOk = speechRecognitionPermission == .authorized
        
        
        return micOk && speechOk
    }
}

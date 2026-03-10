//
//  PermissionsManager.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import AVFoundation
import Speech
import UserNotifications
import SwiftUI

/// Class that manages the app’s permissions (microphone, speech recognition, notifications).
class PermissionsManager: ObservableObject {
    // Current status of each permission, observable from SwiftUI
    @Published var microphonePermission: PermissionStatus = .notDetermined
    @Published var speechRecognitionPermission: PermissionStatus = .notDetermined
    @Published var notificationPermission: PermissionStatus = .notDetermined
    
    init() {
        // Check all permissions when the manager is initialized
        checkAllPermissions()
    }
    
    // MARK: - Global Permission Check
    
    /// Checks all required permissions for the app
    func checkAllPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        checkNotificationPermission()
    }
    
    // MARK: - Microphone Permission
    
    /// Checks the microphone permission status
    func checkMicrophonePermission() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
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
            // Compatibility for iOS versions < 17
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                microphonePermission = .authorized
            case .denied:
                microphonePermission = .denied
            case .undetermined:
                microphonePermission = .notDetermined
            @unknown default:
                microphonePermission = .notDetermined
            }
        }
    }
    
    /// Requests microphone permission from the user
    func requestMicrophonePermission() {
        // Optimisation : vérifier d'abord si déjà autorisé
        if microphonePermission == .authorized {
            return
        }
        
        // Vérifier le cooldown pour éviter les demandes trop fréquentes
        guard canRequestPermissions() else {
            return
        }
        
        markPermissionRequested()
        
        Task {
            await requestMicrophonePermissionAsync()
        }
    }
    
    // MARK: - Speech Recognition Permission
    
    /// Checks the speech recognition permission status
    func checkSpeechRecognitionPermission() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechRecognitionPermission = .authorized
        case .denied:
            speechRecognitionPermission = .denied
        case .restricted:
            speechRecognitionPermission = .restricted
        case .notDetermined:
            speechRecognitionPermission = .notDetermined
        @unknown default:
            speechRecognitionPermission = .notDetermined
        }
    }
    
    /// Requests speech recognition permission from the user
    func requestSpeechRecognitionPermission() {
        // Optimisation : vérifier d'abord si déjà autorisé
        if speechRecognitionPermission == .authorized {
            return
        }
        
        // Vérifier le cooldown pour éviter les demandes trop fréquentes
        guard canRequestPermissions() else {
            return
        }
        
        markPermissionRequested()
        
        Task {
            await requestSpeechRecognitionPermissionAsync()
        }
    }
    
    // MARK: - Notification Permission
    
    /// Checks the notification permission status
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    self?.notificationPermission = .authorized
                case .denied:
                    self?.notificationPermission = .denied
                case .notDetermined:
                    self?.notificationPermission = .notDetermined
                case .provisional, .ephemeral:
                    // Both cases mean the app can send notifications (temporarily or quietly)
                    self?.notificationPermission = .authorized
                @unknown default:
                    self?.notificationPermission = .notDetermined
                }
            }
        }
    }
    
    /// Requests notification permission from the user (including critical alerts)
    func requestNotificationPermission() {
        // Optimisation : vérifier d'abord si déjà autorisé
        if notificationPermission == .authorized {
            return
        }
        
        // Vérifier le cooldown pour éviter les demandes trop fréquentes
        guard canRequestPermissions() else {
            return
        }
        
        markPermissionRequested()
        
        Task {
            await requestNotificationPermissionAsync()
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Checks if essential permissions (microphone + speech recognition) are granted
    func areEssentialPermissionsGranted() -> Bool {
        return microphonePermission == .authorized && speechRecognitionPermission == .authorized
    }
    
    /// Checks if all permissions (microphone + speech recognition + notifications) are granted
    func areAllPermissionsGranted() -> Bool {
        return microphonePermission == .authorized && 
               speechRecognitionPermission == .authorized && 
               notificationPermission == .authorized
    }
    
    /// Requests all permissions at once
    func requestAllPermissions() {
        // Vérifier le cooldown pour éviter les demandes trop fréquentes
        guard canRequestPermissions() else {
            return
        }
        
        markPermissionRequested()
        
        Task {
            // Demander toutes les permissions en parallèle pour plus de rapidité
            async let micRequest: Void = requestMicrophonePermissionAsync()
            async let speechRequest: Void = requestSpeechRecognitionPermissionAsync()
            async let notifRequest: Void = requestNotificationPermissionAsync()
            
            // Attendre que toutes les demandes soient terminées
            _ = await micRequest
            _ = await speechRequest
            _ = await notifRequest
        }
    }
    
    // MARK: - Async Methods (Optimized)
    
    private func requestMicrophonePermissionAsync() async {
        let granted = await withCheckedContinuation { continuation in
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
        
        await MainActor.run {
            self.microphonePermission = granted ? .authorized : .denied
        }
    }
    
    private func requestSpeechRecognitionPermissionAsync() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        await MainActor.run {
            switch status {
            case .authorized:
                self.speechRecognitionPermission = .authorized
            case .denied:
                self.speechRecognitionPermission = .denied
            case .restricted:
                self.speechRecognitionPermission = .restricted
            case .notDetermined:
                self.speechRecognitionPermission = .notDetermined
            @unknown default:
                self.speechRecognitionPermission = .notDetermined
            }
        }
    }
    
    private func requestNotificationPermissionAsync() async {
        let granted = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        
        await MainActor.run {
            self.notificationPermission = granted ? .authorized : .denied
        }
    }
}

// MARK: - Permission Status Extensions

/// Extension to add extra info (text, color, icon) depending on the permission status
extension PermissionStatus {
    /// Human-readable name of the status
    var displayName: String {
        switch self {
        case .notDetermined:
            return "Not determined"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .restricted:
            return "Restricted"
        }
    }
    
    /// Associated color for UI display (SwiftUI)
    var color: SwiftUI.Color {
        switch self {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        }
    }
    
    /// SF Symbol icon name associated with the status
    var icon: String {
        switch self {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        }
    }
}

import SwiftUI

// MARK: - Permission Request Cooldown
private var lastPermissionRequestTime: Date = Date.distantPast

private func canRequestPermissions() -> Bool {
    let now = Date()
    let timeSinceLastRequest = now.timeIntervalSince(lastPermissionRequestTime)
    return timeSinceLastRequest >= AppConfig.Permissions.requestCooldown
}

private func markPermissionRequested() {
    lastPermissionRequestTime = Date()
}

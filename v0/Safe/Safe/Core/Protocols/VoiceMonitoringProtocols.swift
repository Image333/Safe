//
//  VoiceMonitoringProtocols.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import Combine
import AVFoundation
import Speech
import UserNotifications

// MARK: - Voice Monitoring Service Protocol

/// Service principal de surveillance vocale
protocol VoiceMonitoringServiceProtocol: ObservableObject {
    var isListening: Bool { get }
    var isScheduledListening: Bool { get }
    var detectedText: String { get }
    var lastDetectedText: String { get }
    var isRecording: Bool { get }
    var recordingDuration: Double { get }
    
    func startScheduledListening()
    func stopScheduledListening()
    func startMonitoring()
    func stopMonitoring()
    func checkAndUpdateSchedule()
}

// MARK: - Audio Engine Protocol

/// Gestion du moteur audio pour la reconnaissance vocale
protocol AudioEngineServiceProtocol {
    var isEngineRunning: Bool { get }
    var currentInputFormat: AVAudioFormat? { get }
    
    func validateAudioSetup() -> Bool
    func startRecognition(completion: @escaping (Result<Void, AudioEngineError>) -> Void)
    func stopRecognition()
    func installTap(on bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) throws
    func getInputNode() -> AVAudioInputNode
    func getCurrentInputFormat() -> AVAudioFormat
}

// MARK: - Speech Recognition Protocol

/// Service de reconnaissance vocale
protocol SpeechRecognitionServiceProtocol {
    var isAvailable: Bool { get }
    
    func requestAuthorization() -> AnyPublisher<Bool, Never>
    func startContinuousRecognition() -> AnyPublisher<String, SpeechRecognitionError>
    func stopRecognition()
    func clearTranscription()
}

// MARK: - Keyword Detection Protocol

/// Détection des mots-clés d'urgence
protocol KeywordDetectionServiceProtocol {
    func detectKeywords(in text: String) -> [DetectedKeyword]
    func setKeywords(_ keywords: [String])
    func addKeyword(_ keyword: String)
    func removeKeyword(_ keyword: String)
    func getKeywordList() -> [String]
    func setCooldownPeriod(_ interval: TimeInterval)
    func clearDetectionHistory()
    func getDetectionPublisher() -> AnyPublisher<DetectedKeyword, Never>
}

// MARK: - Schedule Management Protocol

/// Gestion des programmations de surveillance
protocol ScheduleManagementServiceProtocol: ObservableObject {
    var currentSchedule: MonitoringSchedule? { get }
    var isInActiveTimeSlot: Bool { get }
    var isScheduledMode: Bool { get }
    
    func setSchedule(_ schedule: MonitoringSchedule)
    func checkCurrentTimeSlot() -> Bool
    func getNextActiveTime() -> Date?
    func toggleScheduledMode()
    func enableSchedule()
    func disableSchedule()
    func getRemainingTime() -> TimeInterval?
    func getTimeUntilNextActivation() -> TimeInterval?
}

// MARK: - Background Task Protocol

/// Gestion des tâches en arrière-plan
protocol BackgroundTaskServiceProtocol {
    var isBackgroundTaskActive: Bool { get }
    
    func startBackgroundTask()
    func endBackgroundTask()
    func configureBackgroundAudio()
}

// MARK: - Permission Management Protocol

/// Gestion des permissions système
protocol PermissionServiceProtocol {
    func checkMicrophonePermission() -> PermissionStatus
    func checkSpeechRecognitionPermission() -> PermissionStatus
    func requestMicrophonePermission() -> AnyPublisher<Bool, Never>
    func requestSpeechRecognitionPermission() -> AnyPublisher<Bool, Never>
    func requestAllPermissions() -> AnyPublisher<Bool, Never>
}

// MARK: - Notification Service Protocol

/// Service de notifications d'urgence
protocol NotificationServiceProtocol {
    func sendEmergencyNotification(keyword: String)
    func requestNotificationPermission() -> AnyPublisher<Bool, Never>
    func scheduleTestNotification()
}

// MARK: - Audio Recording Protocol

/// Service d'enregistrement audio
protocol AudioRecordingServiceProtocol {
    var isRecording: Bool { get }
    var recordingDuration: TimeInterval { get }
    
    func startEmergencyRecording()
    func stopRecording()
    func getAllRecordings() -> [URL]
    func deleteRecording(at url: URL)
}

// MARK: - Data Models

struct MonitoringSchedule {
    let startTime: TimeOfDay
    let endTime: TimeOfDay
    let isEnabled: Bool
    let daysOfWeek: Set<WeekDay>
}

struct TimeOfDay: Comparable {
    let hour: Int
    let minute: Int
    
    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        if lhs.hour != rhs.hour {
            return lhs.hour < rhs.hour
        }
        return lhs.minute < rhs.minute
    }
}

enum WeekDay: Int, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

struct DetectedKeyword {
    let keyword: String
    let detectedAt: Date
    let confidence: Double
    let context: String
    
    init(keyword: String, detectedAt: Date = Date(), confidence: Double = 1.0, context: String = "") {
        self.keyword = keyword
        self.detectedAt = detectedAt
        self.confidence = confidence
        self.context = context
    }
}

struct EmergencyNotification {
    let id: String
    let keyword: String
    let timestamp: Date
    let title: String
    let message: String
}

enum RecordingStatus {
    case idle
    case recording
    case paused
    case error
}

enum RecognitionStatus {
    case idle
    case listening
    case processing
    case error
    case unavailable
}

// MARK: - Error Types

enum AudioEngineError: LocalizedError {
    case configurationFailed
    case formatNotSupported
    case deviceUnavailable
    case invalidAudioFormat
    case audioSessionError
    case cannotStartInCurrentContext
    case microphonePermissionDenied
    case configurationWarning
    case hardwareConfigurationError
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .configurationFailed:
            return "Échec de configuration du moteur audio"
        case .formatNotSupported:
            return "Format audio non supporté"
        case .deviceUnavailable:
            return "Périphérique audio indisponible"
        case .invalidAudioFormat:
            return "Format audio invalide"
        case .audioSessionError:
            return "Erreur de session audio"
        case .cannotStartInCurrentContext:
            return "Impossible de démarrer dans le contexte actuel"
        case .microphonePermissionDenied:
            return "Permission d'accès au microphone refusée"
        case .configurationWarning:
            return "Avertissement de configuration (non critique)"
        case .hardwareConfigurationError:
            return "Problème de configuration matérielle audio (réessayez après un moment)"
        case .unknownError(let error):
            return "Erreur inconnue: \(error.localizedDescription)"
        }
    }
}

enum SpeechRecognitionError: LocalizedError {
    case notAuthorized
    case notAvailable
    case audioEngineError
    case recognitionFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Permission reconnaissance vocale refusée"
        case .notAvailable:
            return "Reconnaissance vocale indisponible"
        case .audioEngineError:
            return "Erreur du moteur audio"
        case .recognitionFailed:
            return "Échec de la reconnaissance"
        }
    }
}

enum PermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum PermissionType {
    case microphone
    case speechRecognition
    case notifications
}

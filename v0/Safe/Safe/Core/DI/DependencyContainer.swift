//
//  DependencyContainer.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import SwiftUI

/// Conteneur d'injection de dépendances
/// 
/// Implémente le pattern Dependency Injection pour une architecture Clean Code.
/// Centralise la création et la gestion des services avec inversion de contrôle.
final class DependencyContainer: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DependencyContainer()
    
    // MARK: - Private Properties
    private var services: [String: Any] = [:]
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    private init() {
        registerServices()
    }
    
    // MARK: - Service Registration
    
    private func registerServices() {
        
        // Services de base (sans dépendances)
        registerService(PermissionService(), as: "PermissionServiceProtocol")
        registerService(AudioEngineService(), as: "AudioEngineServiceProtocol")
        registerService(KeywordDetectionService(), as: "KeywordDetectionServiceProtocol")
        registerService(ScheduleManagementService(), as: "ScheduleManagementServiceProtocol")
        registerService(BackgroundTaskService(), as: "BackgroundTaskServiceProtocol")
        registerService(NotificationService(), as: "NotificationServiceProtocol")
        registerService(AppIconService(), as: "AppIconService")
        
        // Services avec dépendances
        registerSpeechRecognitionService()
        registerAudioRecordingService()
        registerVoiceMonitoringService()
        
    }
    
    private func registerSpeechRecognitionService() {
        let audioEngineService = resolveService(named: "AudioEngineServiceProtocol", as: (any AudioEngineServiceProtocol).self)
        let speechService = SpeechRecognitionService(audioEngineService: audioEngineService)
        registerService(speechService, as: "SpeechRecognitionServiceProtocol")
    }
    
    private func registerAudioRecordingService() {
        // Utilise l'AudioRecordingManager existant adapté en service
        let recordingService = AudioRecordingServiceAdapter()
        registerService(recordingService, as: "AudioRecordingServiceProtocol")
    }
    
    private func registerVoiceMonitoringService() {
        let voiceMonitoringService = VoiceMonitoringService(
            audioEngineService: resolveService(named: "AudioEngineServiceProtocol", as: (any AudioEngineServiceProtocol).self),
            speechRecognitionService: resolveService(named: "SpeechRecognitionServiceProtocol", as: (any SpeechRecognitionServiceProtocol).self),
            keywordDetectionService: resolveService(named: "KeywordDetectionServiceProtocol", as: (any KeywordDetectionServiceProtocol).self),
            scheduleService: resolveService(named: "ScheduleManagementServiceProtocol", as: (any ScheduleManagementServiceProtocol).self),
            backgroundTaskService: resolveService(named: "BackgroundTaskServiceProtocol", as: (any BackgroundTaskServiceProtocol).self),
            permissionService: resolveService(named: "PermissionServiceProtocol", as: (any PermissionServiceProtocol).self),
            notificationService: resolveService(named: "NotificationServiceProtocol", as: (any NotificationServiceProtocol).self),
            recordingService: resolveService(named: "AudioRecordingServiceProtocol", as: (any AudioRecordingServiceProtocol).self)
        )
        
        registerService(voiceMonitoringService, as: "VoiceMonitoringServiceProtocol")
    }
    
    // MARK: - Generic Service Methods
    
    func register<T>(_ service: T, for protocolType: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: protocolType)
        services[key] = service
        
    }
    
    func resolve<T>(_ protocolType: T.Type) -> T {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: protocolType)
        
        guard let service = services[key] as? T else {
            fatalError("❌ Service non trouvé pour le type: \(key)")
        }
        
        return service
    }
    
    // MARK: - Protocol-specific registration methods
    
    private func registerService<T>(_ service: T, as protocolName: String) {
        lock.lock()
        defer { lock.unlock() }
        services[protocolName] = service
    }
    
    private func resolveService<T>(named protocolName: String, as type: T.Type) -> T {
        lock.lock()
        defer { lock.unlock() }
        
        guard let service = services[protocolName] as? T else {
            fatalError("❌ Service non trouvé pour le type: \(protocolName)")
        }
        
        return service
    }
    
    // MARK: - Convenience Methods
    
    var voiceMonitoringService: any VoiceMonitoringServiceProtocol {
        return resolveService(named: "VoiceMonitoringServiceProtocol", as: (any VoiceMonitoringServiceProtocol).self)
    }
    
    var permissionService: any PermissionServiceProtocol {
        return resolveService(named: "PermissionServiceProtocol", as: (any PermissionServiceProtocol).self)
    }
    
    var scheduleService: any ScheduleManagementServiceProtocol {
        return resolveService(named: "ScheduleManagementServiceProtocol", as: (any ScheduleManagementServiceProtocol).self)
    }
    
    var notificationService: any NotificationServiceProtocol {
        return resolveService(named: "NotificationServiceProtocol", as: (any NotificationServiceProtocol).self)
    }
    
    var keywordDetectionService: any KeywordDetectionServiceProtocol {
        return resolveService(named: "KeywordDetectionServiceProtocol", as: (any KeywordDetectionServiceProtocol).self)
    }
    
    var backgroundTaskService: any BackgroundTaskServiceProtocol {
        return resolveService(named: "BackgroundTaskServiceProtocol", as: (any BackgroundTaskServiceProtocol).self)
    }
    
    var appIconService: AppIconService {
        return resolveService(named: "AppIconService", as: AppIconService.self)
    }
}

// MARK: - SwiftUI Environment Integration

extension DependencyContainer {
    
    /// Clé d'environnement SwiftUI pour l'injection de dépendances
    struct DependencyContainerKey: EnvironmentKey {
        static let defaultValue: DependencyContainer = .shared
    }
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainer.DependencyContainerKey.self] }
        set { self[DependencyContainer.DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Modifier for Dependency Injection

struct WithDependencies: ViewModifier {
    let container: DependencyContainer
    
    func body(content: Content) -> some View {
        content
            .environment(\.dependencyContainer, container)
    }
}

extension View {
    func withDependencies(_ container: DependencyContainer = .shared) -> some View {
        modifier(WithDependencies(container: container))
    }
}

// MARK: - Property Wrapper for Service Injection

@propertyWrapper
struct Injected<T> {
    private let keyPath: KeyPath<DependencyContainer, T>
    
    init(_ keyPath: KeyPath<DependencyContainer, T>) {
        self.keyPath = keyPath
    }
    
    var wrappedValue: T {
        return DependencyContainer.shared[keyPath: keyPath]
    }
}

// MARK: - Adapter pour AudioRecordingManager existant

/// Adaptateur pour intégrer l'AudioRecordingManager existant dans l'architecture Clean
final class AudioRecordingServiceAdapter: AudioRecordingServiceProtocol {
    private let recordingManager = AudioRecordingManager()
    
    var isRecording: Bool {
        return recordingManager.isRecording
    }
    
    var recordingDuration: TimeInterval {
        return recordingManager.recordingDuration
    }
    
    func startEmergencyRecording() {
        recordingManager.startRecording()
    }
    
    func stopRecording() {
        recordingManager.stopRecording()
    }
    
    func getAllRecordings() -> [URL] {
        return recordingManager.getAllRecordings()
    }
    
    func deleteRecording(at url: URL) {
        recordingManager.deleteRecording(at: url)
    }
}

// MARK: - Service Location Helpers

extension DependencyContainer {
    
    /// Configuration pour les tests unitaires
    static func createTestContainer() -> DependencyContainer {
        let container = DependencyContainer()
        // Configuration spécifique aux tests avec des mocks
        return container
    }
    
    /// Réinitialisation du conteneur
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        services.removeAll()
        registerServices()
        
    }
    
    /// Vérification de l'état des services
    var registeredServiceCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return services.count
    }
    
    /// Liste des services enregistrés (debugging)
    var registeredServices: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(services.keys).sorted()
    }
}

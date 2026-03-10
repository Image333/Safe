//
//  NotificationService.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import UserNotifications
import Combine

/// Service de notifications d'urgence
/// 
/// Gère l'envoi de notifications critiques lors de la détection de mots-clés d'urgence.
/// Implémente des notifications prioritaires avec sons d'alerte personnalisés.
final class NotificationService: NSObject, NotificationServiceProtocol, ObservableObject {
    
    // MARK: - Private Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private var notificationHistory: [EmergencyNotification] = []
    
    // MARK: - Published Properties
    @Published private(set) var pendingNotifications: Int = 0
    @Published private(set) var lastNotificationSent: Date?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupNotificationDelegate()
        configureNotificationCategories()
    }
    
    // MARK: - NotificationServiceProtocol Implementation
    
    func sendEmergencyNotification(keyword: String) {
        let notification = EmergencyNotification(
            id: UUID().uuidString,
            keyword: keyword,
            timestamp: Date(),
            title: "🚨 Alerte d'urgence détectée",
            message: "Mot-clé d'urgence détecté: \"\(keyword)\""
        )
        
        scheduleNotification(notification)
        recordNotification(notification)
        
    }
    
    func sendScheduleNotification(message: String) {
        let notification = EmergencyNotification(
            id: UUID().uuidString,
            keyword: "schedule",
            timestamp: Date(),
            title: "📅 Surveillance programmée",
            message: message
        )
        
        scheduleNotification(notification, isEmergency: false)
        recordNotification(notification)
        
    }
    
    func sendStatusNotification(title: String, message: String) {
        let notification = EmergencyNotification(
            id: UUID().uuidString,
            keyword: "status",
            timestamp: Date(),
            title: title,
            message: message
        )
        
        scheduleNotification(notification, isEmergency: false)
        recordNotification(notification)
        
    }
    
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        
        notificationHistory.removeAll()
        pendingNotifications = 0
        
    }
    
    func getNotificationHistory() -> [EmergencyNotification] {
        return notificationHistory.sorted { $0.timestamp > $1.timestamp }
    }
    
    func requestNotificationPermission() -> AnyPublisher<Bool, Never> {
        return Future<Bool, Never> { [weak self] promise in
            let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
            
            self?.notificationCenter.requestAuthorization(options: options) { granted, error in
                DispatchQueue.main.async {
                    if error != nil {
                    }
                    
                    promise(.success(granted))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test de Notification"
        content.body = "Ceci est un test de notification d'urgence. Votre système fonctionne correctement."
        content.sound = .default
        content.categoryIdentifier = "EMERGENCY"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-notification-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if error != nil {
            } else {
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationDelegate() {
        notificationCenter.delegate = self
    }
    
    private func configureNotificationCategories() {
        // Action pour les notifications d'urgence
        let emergencyAction = UNNotificationAction(
            identifier: "EMERGENCY_ACTION",
            title: "Voir les détails",
            options: [.foreground]
        )
        
        let emergencyCategory = UNNotificationCategory(
            identifier: "EMERGENCY_ALERT",
            actions: [emergencyAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Action pour les notifications de programmation
        let scheduleAction = UNNotificationAction(
            identifier: "SCHEDULE_ACTION",
            title: "Ouvrir l'app",
            options: [.foreground]
        )
        
        let scheduleCategory = UNNotificationCategory(
            identifier: "SCHEDULE_INFO",
            actions: [scheduleAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([emergencyCategory, scheduleCategory])
    }
    
    private func scheduleNotification(_ notification: EmergencyNotification, isEmergency: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = isEmergency ? .defaultCritical : .default
        content.badge = NSNumber(value: pendingNotifications + 1)
        
        // Configuration spécifique aux urgences
        if isEmergency {
            content.categoryIdentifier = "EMERGENCY_ALERT"
            content.interruptionLevel = .critical
            
            // Données utilisateur pour le suivi
            content.userInfo = [
                "notificationId": notification.id,
                "keyword": notification.keyword,
                "timestamp": ISO8601DateFormatter().string(from: notification.timestamp),
                "isEmergency": true
            ]
        } else {
            content.categoryIdentifier = "SCHEDULE_INFO"
            content.interruptionLevel = .active
            
            content.userInfo = [
                "notificationId": notification.id,
                "timestamp": ISO8601DateFormatter().string(from: notification.timestamp),
                "isEmergency": false
            ]
        }
        
        // Déclenchement immédiat
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { [weak self] error in
            DispatchQueue.main.async {
                if error != nil {
                } else {
                    self?.pendingNotifications += 1
                    self?.lastNotificationSent = Date()
                }
            }
        }
    }
    
    private func recordNotification(_ notification: EmergencyNotification) {
        notificationHistory.append(notification)
        
        // Limiter l'historique à 100 notifications
        if notificationHistory.count > 100 {
            notificationHistory.removeFirst(notificationHistory.count - 100)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Afficher les notifications même quand l'app est au premier plan
        let isEmergency = notification.request.content.userInfo["isEmergency"] as? Bool ?? false
        
        if isEmergency {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.banner, .badge])
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        
        switch actionIdentifier {
        case "EMERGENCY_ACTION":
            handleEmergencyAction(userInfo: userInfo)
        case "SCHEDULE_ACTION":
            handleScheduleAction(userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            // Ouverture normale de la notification
            handleDefaultAction(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleEmergencyAction(userInfo: [AnyHashable: Any]) {
        guard let keyword = userInfo["keyword"] as? String else { return }
        
        
        // Ici, on pourrait déclencher des actions spécifiques
        // comme ouvrir une vue de détails ou envoyer des données
        
        // Notification pour informer l'interface
        NotificationCenter.default.post(
            name: .emergencyNotificationTapped,
            object: nil,
            userInfo: ["keyword": keyword]
        )
    }
    
    private func handleScheduleAction(userInfo: [AnyHashable: Any]) {
        
        // Ouvrir l'application sur l'écran de programmation
        NotificationCenter.default.post(
            name: .scheduleNotificationTapped,
            object: nil
        )
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        let isEmergency = userInfo["isEmergency"] as? Bool ?? false
        
        if isEmergency {
            handleEmergencyAction(userInfo: userInfo)
        } else {
            handleScheduleAction(userInfo: userInfo)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let emergencyNotificationTapped = Notification.Name("emergencyNotificationTapped")
    static let scheduleNotificationTapped = Notification.Name("scheduleNotificationTapped")
}

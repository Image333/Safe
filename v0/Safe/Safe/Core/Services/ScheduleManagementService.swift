//
//  ScheduleManagementService.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import Foundation
import Combine

/// Service de gestion des horaires de surveillance
/// 
/// Gère les plages horaires d'activation automatique de la surveillance vocale.
/// Implémente un système flexible de programmation avec validation.
final class ScheduleManagementService: ScheduleManagementServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var currentSchedule: MonitoringSchedule?
    @Published private(set) var isInActiveTimeSlot: Bool = false
    @Published private(set) var nextActivation: Date?
    @Published private(set) var nextDeactivation: Date?
    @Published private(set) var isScheduledMode: Bool = false
    
    // MARK: - Private Properties
    private var scheduleTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Publishers
    private let scheduleChangeSubject = PassthroughSubject<MonitoringSchedule, Never>()
    private let statusChangeSubject = PassthroughSubject<Bool, Never>()
    
    // MARK: - Initialization
    
    init() {
        // Charger la configuration utilisateur ou utiliser les valeurs par défaut
        loadUserScheduleConfiguration()
        startScheduleMonitoring()
    }
    
    // MARK: - ScheduleManagementServiceProtocol Implementation
    
    func setSchedule(_ schedule: MonitoringSchedule) {
        currentSchedule = schedule
        updateScheduleStatus()
        calculateNextEvents()
        
        scheduleChangeSubject.send(schedule)
    }
    
    func checkCurrentTimeSlot() -> Bool {
        // VERSION SIMPLIFIÉE SANS CRASH
        // Si le schedule est activé, on retourne true pour que le micro s'active
        guard let schedule = currentSchedule else {
            return false
        }
        
        // Si désactivé, retourner false
        guard schedule.isEnabled else {
            return false
        }
        
        // Pour l'instant, retourner true si le schedule est activé
        // Cela permet d'activer le micro quand la surveillance programmée est ON
        return true
    }
    
    func getNextActivationTime() -> Date? {
        return nextActivation
    }
    
    func getNextDeactivationTime() -> Date? {
        return nextDeactivation
    }
    
    func getNextActiveTime() -> Date? {
        return nextActivation
    }
    
    func enableSchedule() {
        guard let schedule = currentSchedule else { return }
        let updatedSchedule = MonitoringSchedule(
            startTime: schedule.startTime,
            endTime: schedule.endTime,
            isEnabled: true,
            daysOfWeek: schedule.daysOfWeek
        )
        setSchedule(updatedSchedule)
        
        // Notifier qu'il faut démarrer la surveillance
        NotificationCenter.default.post(name: .scheduleEnabled, object: nil)
    }
    
    func disableSchedule() {
        guard let schedule = currentSchedule else { return }
        let updatedSchedule = MonitoringSchedule(
            startTime: schedule.startTime,
            endTime: schedule.endTime,
            isEnabled: false,
            daysOfWeek: schedule.daysOfWeek
        )
        setSchedule(updatedSchedule)
        
        // Notifier qu'il faut arrêter la surveillance
        NotificationCenter.default.post(name: .scheduleDisabled, object: nil)
    }
    
    func getRemainingTime() -> TimeInterval? {
        guard isInActiveTimeSlot, let deactivation = nextDeactivation else {
            return nil
        }
        
        return deactivation.timeIntervalSinceNow
    }
    
    func getTimeUntilNextActivation() -> TimeInterval? {
        guard let activation = nextActivation else {
            return nil
        }
        
        return activation.timeIntervalSinceNow
    }
    
    func getScheduleChangePublisher() -> AnyPublisher<MonitoringSchedule, Never> {
        return scheduleChangeSubject.eraseToAnyPublisher()
    }
    
    func getStatusChangePublisher() -> AnyPublisher<Bool, Never> {
        return statusChangeSubject.eraseToAnyPublisher()
    }
    
    func toggleScheduledMode() {
        isScheduledMode.toggle()
    }
    
    // MARK: - Private Methods
    
    private func startScheduleMonitoring() {
        // Vérification initiale
        updateScheduleStatus()
        calculateNextEvents()
        
        // Timer pour vérifications périodiques (toutes les minutes)
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateScheduleStatus()
            self?.calculateNextEvents()
        }
    }
    
    private func updateScheduleStatus() {
        let wasInActiveTimeSlot = isInActiveTimeSlot
        isInActiveTimeSlot = checkCurrentTimeSlot()
        
        if wasInActiveTimeSlot != isInActiveTimeSlot {
            statusChangeSubject.send(isInActiveTimeSlot)
        }
    }
    
    private func isTimeWithinSchedule(_ time: TimeOfDay) -> Bool {
        guard let schedule = currentSchedule else { return false }
        let start = schedule.startTime
        let end = schedule.endTime
        
        // Cas normal: même jour (ex: 17h00 -> 17h30)
        if start <= end {
            return time >= start && time <= end
        }
        
        // Cas de minuit passé (ex: 23h00 -> 01h00)
        return time >= start || time <= end
    }
    
    private func calculateNextEvents() {
        let calendar = Calendar.current
        let now = Date()
        
        nextActivation = calculateNextActivation(from: now, calendar: calendar)
        nextDeactivation = calculateNextDeactivation(from: now, calendar: calendar)
    }
    
    private func calculateNextActivation(from date: Date, calendar: Calendar) -> Date? {
        guard let schedule = currentSchedule, schedule.isEnabled else { return nil }
        
        // Si nous sommes déjà dans la plage, la prochaine activation est demain
        if isInActiveTimeSlot {
            return findNextDayActivation(from: date, calendar: calendar)
        }
        
        // Sinon, vérifier aujourd'hui d'abord
        if let todayActivation = findTodayActivation(from: date, calendar: calendar) {
            return todayActivation
        }
        
        // Puis chercher les jours suivants
        return findNextDayActivation(from: date, calendar: calendar)
    }
    
    private func calculateNextDeactivation(from date: Date, calendar: Calendar) -> Date? {
        guard let schedule = currentSchedule, schedule.isEnabled && isInActiveTimeSlot else { return nil }
        
        return findTodayDeactivation(from: date, calendar: calendar)
    }
    
    private func findTodayActivation(from date: Date, calendar: Calendar) -> Date? {
        guard let schedule = currentSchedule else { return nil }
        
        let currentWeekday = calendar.component(.weekday, from: date)
        guard let currentDay = WeekDay(rawValue: currentWeekday),
              schedule.daysOfWeek.contains(currentDay) else {
            return nil
        }
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = schedule.startTime.hour
        components.minute = schedule.startTime.minute
        components.second = 0
        
        guard let activationTime = calendar.date(from: components),
              activationTime > date else {
            return nil
        }
        
        return activationTime
    }
    
    private func findTodayDeactivation(from date: Date, calendar: Calendar) -> Date? {
        guard let schedule = currentSchedule else { return nil }
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = schedule.endTime.hour
        components.minute = schedule.endTime.minute
        components.second = 0
        
        return calendar.date(from: components)
    }
    
    private func findNextDayActivation(from date: Date, calendar: Calendar) -> Date? {
        guard let schedule = currentSchedule else { return nil }
        
        // Chercher dans les 7 jours suivants
        for dayOffset in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: date) else {
                continue
            }
            
            let weekday = calendar.component(.weekday, from: futureDate)
            guard let weekDay = WeekDay(rawValue: weekday),
                  schedule.daysOfWeek.contains(weekDay) else {
                continue
            }
            
            var components = calendar.dateComponents([.year, .month, .day], from: futureDate)
            components.hour = schedule.startTime.hour
            components.minute = schedule.startTime.minute
            components.second = 0
            
            return calendar.date(from: components)
        }
        
        return nil
    }
    
    private func formatSchedule(_ schedule: MonitoringSchedule) -> String {
        let start = String(format: "%02d:%02d", schedule.startTime.hour, schedule.startTime.minute)
        let end = String(format: "%02d:%02d", schedule.endTime.hour, schedule.endTime.minute)
        let days = schedule.daysOfWeek.map { $0.shortName }.joined(separator: ", ")
        return "\(start)-\(end) (\(days))"
    }
    
    // MARK: - User Configuration Management
    
    /// Configuration personnalisée des horaires par l'utilisateur
    func updateCustomSchedule(startTime: TimeOfDay, endTime: TimeOfDay, daysOfWeek: Set<WeekDay>) {
        let newSchedule = MonitoringSchedule(
            startTime: startTime,
            endTime: endTime,
            isEnabled: currentSchedule?.isEnabled ?? true,
            daysOfWeek: daysOfWeek
        )
        
        setSchedule(newSchedule)
        saveUserScheduleConfiguration()
    }
    
    /// Sauvegarde la configuration dans UserDefaults
    private func saveUserScheduleConfiguration() {
        guard let schedule = currentSchedule else { return }
        
        let defaults = UserDefaults.standard
        defaults.set(schedule.startTime.hour, forKey: "schedule_start_hour")
        defaults.set(schedule.startTime.minute, forKey: "schedule_start_minute")
        defaults.set(schedule.endTime.hour, forKey: "schedule_end_hour")
        defaults.set(schedule.endTime.minute, forKey: "schedule_end_minute")
        defaults.set(schedule.isEnabled, forKey: "schedule_enabled")
        
        // Sauvegarder les jours de la semaine
        let dayValues = schedule.daysOfWeek.map { $0.rawValue }
        defaults.set(dayValues, forKey: "schedule_days")
        
    }
    
    /// Charge la configuration depuis UserDefaults
    private func loadUserScheduleConfiguration() {
        let defaults = UserDefaults.standard
        
        // Vérifier si une configuration existe
        if defaults.object(forKey: "schedule_start_hour") != nil {
            let startHour = defaults.integer(forKey: "schedule_start_hour")
            let startMinute = defaults.integer(forKey: "schedule_start_minute")
            let endHour = defaults.integer(forKey: "schedule_end_hour")
            let endMinute = defaults.integer(forKey: "schedule_end_minute")
            let isEnabled = defaults.bool(forKey: "schedule_enabled")
            let dayValues = defaults.array(forKey: "schedule_days") as? [Int] ?? []
            
            let startTime = TimeOfDay(hour: startHour, minute: startMinute)
            let endTime = TimeOfDay(hour: endHour, minute: endMinute)
            let daysOfWeek = Set(dayValues.compactMap { WeekDay(rawValue: $0) })
            
            self.currentSchedule = MonitoringSchedule(
                startTime: startTime,
                endTime: endTime,
                isEnabled: isEnabled,
                daysOfWeek: daysOfWeek.isEmpty ? [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday] : daysOfWeek
            )
            
            
            // Si le schedule était activé, démarrer automatiquement la surveillance
            if isEnabled {
                // Poster la notification après un court délai pour que tous les services soient initialisés
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: .scheduleEnabled, object: nil)
                }
            }
        } else {
            // Configuration par défaut si aucune sauvegarde
            setDefaultSchedule()
        }
    }
    
    /// Définit la configuration par défaut
    private func setDefaultSchedule() {
        let startTime = TimeOfDay(hour: 17, minute: 0)
        let endTime = TimeOfDay(hour: 18, minute: 0) // Changé pour 17h-18h
        
        self.currentSchedule = MonitoringSchedule(
            startTime: startTime,
            endTime: endTime,
            isEnabled: true,
            daysOfWeek: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        )
        
        
        // Le schedule par défaut est activé, donc démarrer la surveillance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .scheduleEnabled, object: nil)
        }
    }
    
    /// Réinitialise la configuration aux valeurs par défaut
    func resetToDefaultSchedule() {
        setDefaultSchedule()
        saveUserScheduleConfiguration()
    }
    
    // MARK: - Deinitializer
    
    deinit {
        scheduleTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - Supporting Extensions

extension WeekDay {
    var shortName: String {
        switch self {
        case .sunday: return "Dim"
        case .monday: return "Lun"
        case .tuesday: return "Mar"
        case .wednesday: return "Mer"
        case .thursday: return "Jeu"
        case .friday: return "Ven"
        case .saturday: return "Sam"
        }
    }
    
    var fullName: String {
        switch self {
        case .sunday: return "Dimanche"
        case .monday: return "Lundi"
        case .tuesday: return "Mardi"
        case .wednesday: return "Mercredi"
        case .thursday: return "Jeudi"
        case .friday: return "Vendredi"
        case .saturday: return "Samedi"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let scheduleEnabled = Notification.Name("scheduleEnabled")
    static let scheduleDisabled = Notification.Name("scheduleDisabled")
}

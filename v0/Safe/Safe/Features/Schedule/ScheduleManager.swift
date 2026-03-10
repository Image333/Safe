//
//  ScheduleManager.swift
//  Safe
//
//  Created by Imane on 14/08/2025.
//

import Foundation
import SwiftUI
import Combine

/// Gestionnaire de planification pour faciliter l'intégration
/// 
/// Wrapper autour du ScheduleManagementService pour simplifier l'utilisation
/// dans les vues SwiftUI et fournir des utilitaires supplémentaires.
@MainActor
final class ScheduleManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isScheduleEnabled: Bool = false
    @Published var currentStatus: String = "Configuration initiale..."
    @Published var nextEvent: String = ""
    @Published var remainingTime: String = ""
    
    // MARK: - Private Properties
    private let scheduleService: ScheduleManagementService
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    
    init(scheduleService: ScheduleManagementService) {
        self.scheduleService = scheduleService
        setupObservers()
        updateStatus()
        startPeriodicUpdates()
    }
    
    // MARK: - Public Methods
    
    /// Configure un horaire personnalisé
    func setCustomSchedule(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        days: [WeekDay]
    ) {
        let startTime = TimeOfDay(hour: startHour, minute: startMinute)
        let endTime = TimeOfDay(hour: endHour, minute: endMinute)
        let daysSet = Set(days)
        
        scheduleService.updateCustomSchedule(
            startTime: startTime,
            endTime: endTime,
            daysOfWeek: daysSet
        )
    }
    
    /// Configurations prédéfinies
    func setWorkHours() {
        setCustomSchedule(
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0,
            days: [.monday, .tuesday, .wednesday, .thursday, .friday]
        )
    }
    
    func setAfternoonSchedule() {
        setCustomSchedule(
            startHour: 14, startMinute: 0,
            endHour: 18, endMinute: 0,
            days: WeekDay.allCases
        )
    }
    
    func setEveningSchedule() {
        setCustomSchedule(
            startHour: 18, startMinute: 0,
            endHour: 22, endMinute: 0,
            days: WeekDay.allCases
        )
    }
    
    func set24_7Schedule() {
        setCustomSchedule(
            startHour: 0, startMinute: 0,
            endHour: 23, endMinute: 59,
            days: WeekDay.allCases
        )
    }
    
    /// Active/désactive la surveillance programmée
    func toggleSchedule() {
        if isScheduleEnabled {
            scheduleService.disableSchedule()
        } else {
            scheduleService.enableSchedule()
        }
    }
    
    /// Réinitialise aux valeurs par défaut
    func resetToDefaults() {
        scheduleService.resetToDefaultSchedule()
    }
    
    /// Obtient les informations de planification actuelles
    func getCurrentScheduleInfo() -> (startTime: String, endTime: String, days: String)? {
        guard let schedule = scheduleService.currentSchedule else { return nil }
        
        let startTime = String(format: "%02d:%02d", schedule.startTime.hour, schedule.startTime.minute)
        let endTime = String(format: "%02d:%02d", schedule.endTime.hour, schedule.endTime.minute)
        let days = schedule.daysOfWeek.map { $0.shortName }.joined(separator: ", ")
        
        return (startTime, endTime, days)
    }
    
    /// Vérifie si on est actuellement dans une plage active
    var isCurrentlyActive: Bool {
        return scheduleService.isInActiveTimeSlot
    }
    
    /// Obtient le service sous-jacent pour des utilisations avancées
    var underlyingService: ScheduleManagementService {
        return scheduleService
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observer les changements d'état
        scheduleService.$isInActiveTimeSlot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatus()
            }
            .store(in: &cancellables)
        
        scheduleService.$currentSchedule
            .receive(on: DispatchQueue.main)
            .sink { [weak self] schedule in
                self?.isScheduleEnabled = schedule?.isEnabled ?? false
                self?.updateStatus()
            }
            .store(in: &cancellables)
        
        scheduleService.$nextActivation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNextEvent()
            }
            .store(in: &cancellables)
        
        scheduleService.$nextDeactivation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNextEvent()
            }
            .store(in: &cancellables)
    }
    
    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatus()
                self?.updateNextEvent()
                self?.updateRemainingTime()
            }
        }
    }
    
    private func updateStatus() {
        if !isScheduleEnabled {
            currentStatus = "Surveillance programmée désactivée"
        } else if scheduleService.isInActiveTimeSlot {
            currentStatus = "🟢 Surveillance active"
        } else {
            currentStatus = "🔴 Surveillance inactive"
        }
    }
    
    private func updateNextEvent() {
        if scheduleService.isInActiveTimeSlot {
            // Actuellement actif, afficher quand ça se terminera
            if let nextDeactivation = scheduleService.getNextDeactivationTime() {
                nextEvent = "Fin à \(formatTime(nextDeactivation))"
            } else {
                nextEvent = "Surveillance continue"
            }
        } else {
            // Actuellement inactif, afficher quand ça commencera
            if let nextActivation = scheduleService.getNextActiveTime() {
                nextEvent = "Début à \(formatTime(nextActivation))"
            } else {
                nextEvent = "Aucune activation programmée"
            }
        }
    }
    
    private func updateRemainingTime() {
        if scheduleService.isInActiveTimeSlot {
            if let remaining = scheduleService.getRemainingTime(), remaining > 0 {
                remainingTime = "Temps restant: \(formatDuration(remaining))"
            } else {
                remainingTime = ""
            }
        } else {
            if let timeUntil = scheduleService.getTimeUntilNextActivation(), timeUntil > 0 {
                remainingTime = "Dans: \(formatDuration(timeUntil))"
            } else {
                remainingTime = ""
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        if Calendar.current.isDateInToday(date) {
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        // Vérifier si la valeur est valide avant la conversion
        guard seconds.isFinite && seconds >= 0 else {
            return "∞"
        }
        
        // Protection contre les valeurs trop grandes
        let safeSeconds = min(seconds, Double(Int.max))
        
        let hours = Int(safeSeconds) / 3600
        let minutes = (Int(safeSeconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else if minutes > 0 {
            return "\(minutes)min"
        } else {
            return "< 1min"
        }
    }
    
    // MARK: - Deinitializer
    
    deinit {
        updateTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - SwiftUI Helpers

extension ScheduleManager {
    /// Créé une vue de configuration des horaires
    func createScheduleView() -> some View {
        ScheduleView(scheduleService: scheduleService)
    }
    
    /// Status view compact pour affichage dans d'autres vues
    func createStatusView() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentStatus)
                .font(.caption)
                .foregroundColor(isCurrentlyActive ? .green : .secondary)
            
            if !nextEvent.isEmpty {
                Text(nextEvent)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !remainingTime.isEmpty {
                Text(remainingTime)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }
}

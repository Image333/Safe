//
//  ScheduleView.swift
//  Safe
//
//  Created by Imane on 14/08/2025.
//

import SwiftUI

/// Vue de configuration des horaires de surveillance
/// 
/// Permet à l'utilisateur de personnaliser ses créneaux de surveillance
struct ScheduleView: View {
    @StateObject private var scheduleService: ScheduleManagementService
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var selectedDays: Set<WeekDay> = []
    @State private var isEnabled = true
    @State private var showingDeleteAlert = false
    
    init(scheduleService: ScheduleManagementService) {
        _scheduleService = StateObject(wrappedValue: scheduleService)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Status Section
                Section(header: Text("État de la surveillance")) {
                    HStack {
                        Circle()
                            .fill(scheduleService.isInActiveTimeSlot ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text(scheduleService.isInActiveTimeSlot ? "Surveillance active" : "Surveillance inactive")
                            .foregroundColor(scheduleService.isInActiveTimeSlot ? .green : .red)
                        
                        Spacer()
                    }
                    
                    if let nextActivation = scheduleService.getNextActiveTime() {
                        HStack {
                            Image(systemName: "clock")
                            Text("Prochaine activation: \(formatDate(nextActivation))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: - Schedule Configuration
                Section(header: Text("Configuration des horaires")) {
                    Toggle("Activer la surveillance programmée", isOn: $isEnabled)
                        .onChange(of: isEnabled) { _, newValue in
                            if newValue {
                                scheduleService.enableSchedule()
                            } else {
                                scheduleService.disableSchedule()
                            }
                        }
                    
                    if isEnabled {
                        DatePicker("Heure de début", selection: $startTime, displayedComponents: .hourAndMinute)
                            .onChange(of: startTime) { _, _ in
                                updateSchedule()
                            }
                        
                        DatePicker("Heure de fin", selection: $endTime, displayedComponents: .hourAndMinute)
                            .onChange(of: endTime) { _, _ in
                                updateSchedule()
                            }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Jours de la semaine")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(WeekDay.allCases, id: \.self) { day in
                                    DayToggleButton(
                                        day: day,
                                        isSelected: selectedDays.contains(day)
                                    ) {
                                        toggleDay(day)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // MARK: - Presets Section
                Section(header: Text("Configurations prédéfinies")) {
                    Button("Horaires de bureau (9h-17h)") {
                        setPresetSchedule(start: (9, 0), end: (17, 0), days: [.monday, .tuesday, .wednesday, .thursday, .friday])
                    }
                    
                    Button("Après-midi (14h-18h)") {
                        setPresetSchedule(start: (14, 0), end: (18, 0), days: WeekDay.allCases)
                    }
                    
                    Button("Soirée (18h-22h)") {
                        setPresetSchedule(start: (18, 0), end: (22, 0), days: WeekDay.allCases)
                    }
                    
                    Button("24h/7j") {
                        setPresetSchedule(start: (0, 0), end: (23, 59), days: WeekDay.allCases)
                    }
                }
                
                // MARK: - Reset Section
                Section {
                    Button("Réinitialiser aux valeurs par défaut") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Horaires de surveillance")
            .onAppear {
                loadCurrentSchedule()
            }
            .alert("Réinitialiser", isPresented: $showingDeleteAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Réinitialiser", role: .destructive) {
                    resetToDefaults()
                }
            } message: {
                Text("Êtes-vous sûr de vouloir réinitialiser les horaires aux valeurs par défaut ?")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCurrentSchedule() {
        guard let schedule = scheduleService.currentSchedule else { return }
        
        // Convertir TimeOfDay en Date pour les pickers
        var startComponents = DateComponents()
        startComponents.hour = schedule.startTime.hour
        startComponents.minute = schedule.startTime.minute
        startTime = Calendar.current.date(from: startComponents) ?? Date()
        
        var endComponents = DateComponents()
        endComponents.hour = schedule.endTime.hour
        endComponents.minute = schedule.endTime.minute
        endTime = Calendar.current.date(from: endComponents) ?? Date()
        
        selectedDays = schedule.daysOfWeek
        isEnabled = schedule.isEnabled
    }
    
    private func updateSchedule() {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)
        
        let startTimeOfDay = TimeOfDay(hour: startHour, minute: startMinute)
        let endTimeOfDay = TimeOfDay(hour: endHour, minute: endMinute)
        
        // Validation: l'heure de fin doit être après l'heure de début
        if endTimeOfDay <= startTimeOfDay {
            // Ajouter une heure à l'heure de début pour l'heure de fin
            let adjustedEndTimeOfDay = TimeOfDay(
                hour: (startHour + 1) % 24,
                minute: startMinute
            )
            
            scheduleService.updateCustomSchedule(
                startTime: startTimeOfDay,
                endTime: adjustedEndTimeOfDay,
                daysOfWeek: selectedDays.isEmpty ? Set(WeekDay.allCases) : selectedDays
            )
        } else {
            scheduleService.updateCustomSchedule(
                startTime: startTimeOfDay,
                endTime: endTimeOfDay,
                daysOfWeek: selectedDays.isEmpty ? Set(WeekDay.allCases) : selectedDays
            )
        }
    }
    
    private func toggleDay(_ day: WeekDay) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
        
        if !selectedDays.isEmpty {
            updateSchedule()
        }
    }
    
    private func setPresetSchedule(start: (Int, Int), end: (Int, Int), days: [WeekDay]) {
        let startTimeOfDay = TimeOfDay(hour: start.0, minute: start.1)
        let endTimeOfDay = TimeOfDay(hour: end.0, minute: end.1)
        
        selectedDays = Set(days)
        
        // Mettre à jour les dates pour les pickers
        var startComponents = DateComponents()
        startComponents.hour = start.0
        startComponents.minute = start.1
        startTime = Calendar.current.date(from: startComponents) ?? Date()
        
        var endComponents = DateComponents()
        endComponents.hour = end.0
        endComponents.minute = end.1
        endTime = Calendar.current.date(from: endComponents) ?? Date()
        
        scheduleService.updateCustomSchedule(
            startTime: startTimeOfDay,
            endTime: endTimeOfDay,
            daysOfWeek: selectedDays
        )
    }
    
    private func resetToDefaults() {
        scheduleService.resetToDefaultSchedule()
        loadCurrentSchedule()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Day Toggle Button

struct DayToggleButton: View {
    let day: WeekDay
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(day.fullName)
                    .font(.caption)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct ScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView(scheduleService: ScheduleManagementService())
    }
}

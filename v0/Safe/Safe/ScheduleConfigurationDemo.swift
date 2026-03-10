//
//  ScheduleConfigurationDemo.swift
//  Safe
//
//  Created by Imane on 14/08/2025.
//

import SwiftUI

/// Vue de démonstration pour tester la configuration des horaires
struct ScheduleConfigurationDemo: View {
    @StateObject private var scheduleManager: ScheduleManager
    
    init() {
        let container = DependencyContainer.shared
        let scheduleService = container.scheduleService as! ScheduleManagementService
        _scheduleManager = StateObject(wrappedValue: ScheduleManager(scheduleService: scheduleService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Configuration des Horaires de Surveillance")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Status actuel
                GroupBox("État Actuel") {
                    scheduleManager.createStatusView()
                }
                
                // Configurations rapides
                GroupBox("Configurations Rapides") {
                    VStack(spacing: 12) {
                        Button("Horaires de Bureau (9h-17h)") {
                            scheduleManager.setWorkHours()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Après-midi (14h-18h)") {
                            scheduleManager.setAfternoonSchedule()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Soirée (18h-22h)") {
                            scheduleManager.setEveningSchedule()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("24h/7j") {
                            scheduleManager.set24_7Schedule()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Lien vers la configuration complète
                NavigationLink("Configuration Avancée") {
                    scheduleManager.createScheduleView()
                }
                .buttonStyle(.borderedProminent)
                
                // Contrôles de test
                GroupBox("Contrôles de Test") {
                    VStack(spacing: 8) {
                        Button(scheduleManager.isScheduleEnabled ? "Désactiver Surveillance" : "Activer Surveillance") {
                            scheduleManager.toggleSchedule()
                        }
                        .foregroundColor(scheduleManager.isScheduleEnabled ? .red : .green)
                        
                        Button("Réinitialiser aux Défauts") {
                            scheduleManager.resetToDefaults()
                        }
                        .foregroundColor(.orange)
                    }
                }
                
                // Informations de debug
                if let info = scheduleManager.getCurrentScheduleInfo() {
                    GroupBox("Informations de Debug") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Début: \(info.startTime)")
                            Text("Fin: \(info.endTime)")
                            Text("Jours: \(info.days)")
                            Text("Active: \(scheduleManager.isCurrentlyActive ? "Oui" : "Non")")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Test Horaires")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Preview
struct ScheduleConfigurationDemo_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleConfigurationDemo()
    }
}

//
//  SettingsView.swift
//  Safe

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var notificationsEnabled = true
    @State private var locationEnabled = true
    @State private var soundEnabled = true
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // Section Utilisateur
                if let user = authManager.currentUser {
                    Section("Mon compte") {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(user.fullName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 5)
                        
                        Button("Se déconnecter") {
                            showLogoutAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Notifications") {
                    Toggle("Activer les notifications", isOn: $notificationsEnabled)
                    Toggle("Notifications sonores", isOn: $soundEnabled)
                }
                
                Section("Localisation") {
                    Toggle("Partage de localisation", isOn: $locationEnabled)
                    
                    if locationEnabled {
                        HStack {
                            Text("Précision")
                            Spacer()
                            Text("Élevée")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Application") {
                    NavigationLink("Icône de l'application") {
                        AppIconSettingsView()
                    }
                    
                    NavigationLink("Horaires de surveillance") {
                        ScheduleView(scheduleService: DependencyContainer.shared.scheduleService as! ScheduleManagementService)
                    }
                    
                    NavigationLink("Mots-clés d'urgence") {
                        KeywordSettingsView()
                    }
                    
                    NavigationLink("Liaisons Mot-clé/Contact") {
                        KeywordContactMappingView()
                    }
                    
                    
                    NavigationLink("Aide") {
                        HelpView()
                    }
                    
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Réglages")
            .alert("Déconnexion", isPresented: $showLogoutAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Se déconnecter", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Êtes-vous sûr de vouloir vous déconnecter ?")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
}

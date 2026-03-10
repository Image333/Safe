//
//  QuickMonitoringToggle.swift
//  Safe
//
//  Created by System on 19/09/2025.
//

import SwiftUI

struct QuickMonitoringToggle: View {
    @StateObject private var coordinator = VoiceMonitoringCoordinator()
    
    var body: some View {
        VStack(spacing: 16) {
            // Toggle principal
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Surveillance vocale")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(coordinator.permissionStatus.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if coordinator.permissionStatus == .requesting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.8)
                } else {
                    Toggle("", isOn: $coordinator.isMonitoringActive)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .onChange(of: coordinator.isMonitoringActive) { _, newValue in
                            if newValue {
                                coordinator.activateMonitoring()
                            } else {
                                coordinator.deactivateMonitoring()
                            }
                        }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Statut détaillé si nécessaire
            if coordinator.permissionStatus == .partiallyGranted || coordinator.permissionStatus == .denied {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Action requise")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    Text("Certaines permissions sont nécessaires pour un fonctionnement optimal.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Button("Réessayer") {
                            coordinator.retryPermissions()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        
                        Button("Réglages") {
                            coordinator.openAppSettings()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .alert("Permissions requises", isPresented: $coordinator.showingPermissionAlert) {
            Button("OK", role: .cancel) {
                coordinator.dismissPermissionAlert()
            }
        } message: {
            Text(coordinator.permissionStatus.description + "\n\nL'application nécessite les permissions microphone et reconnaissance vocale pour fonctionner.")
        }
    }
}

#Preview {
    QuickMonitoringToggle()
        .padding()
}

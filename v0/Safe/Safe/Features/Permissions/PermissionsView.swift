//
//  PermissionsView.swift
//  Safe
//
//  Created by Imane on 11/08/2025.
//

import SwiftUI

// A view that guides the user through granting required permissions (microphone, speech recognition, notifications).
struct PermissionsView: View {
    @StateObject private var permissionsManager = PermissionsManager()
    @Environment(\.dismiss) private var dismiss
    @State private var isRequestingPermissions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // MARK: - Header Section
                VStack(spacing: 15) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Required Permissions")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("To enable voice monitoring, the app requires the following permissions:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // MARK: - Permissions List
                VStack(spacing: 15) {
                    PermissionRowView(
                        title: "Microphone",
                        description: "Needed to listen and detect emergency keywords",
                        icon: "mic.fill",
                        status: permissionsManager.microphonePermission,
                        isLoading: isRequestingPermissions,
                        action: {
                            requestIndividualPermission {
                                permissionsManager.requestMicrophonePermission()
                            }
                        }
                    )
                    
                    PermissionRowView(
                        title: "Speech Recognition",
                        description: "Needed to analyze speech and identify emergency words",
                        icon: "waveform",
                        status: permissionsManager.speechRecognitionPermission,
                        isLoading: isRequestingPermissions,
                        action: {
                            requestIndividualPermission {
                                permissionsManager.requestSpeechRecognitionPermission()
                            }
                        }
                    )
                    
                    PermissionRowView(
                        title: "Notifications",
                        description: "Needed to alert you about schedules and detections",
                        icon: "bell.fill",
                        status: permissionsManager.notificationPermission,
                        isLoading: isRequestingPermissions,
                        action: {
                            requestIndividualPermission {
                                permissionsManager.requestNotificationPermission()
                            }
                        }
                    )
                }
                
                Spacer()
                
                // MARK: - Important Information Box
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("Important")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Continuous background listening is not possible on iOS due to security and battery restrictions. The app will use notifications to remind you to activate monitoring during your scheduled times.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                // MARK: - Action Buttons
                VStack(spacing: 10) {
                    // Main button changes depending on whether essential permissions are granted
                    if !permissionsManager.areEssentialPermissionsGranted() {
                        Button(action: requestAllPermissions) {
                            HStack {
                                if isRequestingPermissions {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text("Autoriser toutes les permissions")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isRequestingPermissions ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isRequestingPermissions)
                        
                        // Bouton pour passer/fermer même sans permissions
                        Button("Passer") {
                            dismiss()
                        }
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                    } else {
                        Button("Continuer") {
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    // Shortcut to open iOS Settings
                    Button("Ouvrir les Réglages") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Refresh permissions each time the view appears
                permissionsManager.checkAllPermissions()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func requestAllPermissions() {
        guard !isRequestingPermissions else { return }
        
        isRequestingPermissions = true
        
        Task {
            // Petite vibration haptic pour feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            await MainActor.run {
                permissionsManager.requestAllPermissions()
            }
            
            // Attendre que les permissions système se mettent à jour
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 secondes
            
            // Rafraîchir l'état des permissions
            await MainActor.run {
                permissionsManager.checkAllPermissions()
                isRequestingPermissions = false
            }
        }
    }
    
    private func requestIndividualPermission(action: @escaping () -> Void) {
        guard !isRequestingPermissions else { return }
        
        isRequestingPermissions = true
        
        Task {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            await MainActor.run {
                action()
            }
            
            // Attendre que la permission système se mette à jour
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde
            
            await MainActor.run {
                permissionsManager.checkAllPermissions()
                isRequestingPermissions = false
            }
        }
    }
}

// A reusable row that displays a permission with its status and an action button.
struct PermissionRowView: View {
    let title: String
    let description: String
    let icon: String
    let status: PermissionStatus
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Permission icon
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 30)
            
            // Permission details
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            // Status display + request button if not authorized
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: status.icon)
                        .foregroundColor(status.color)
                    
                    Text(status.displayName)
                        .font(.caption)
                        .foregroundColor(status.color)
                }
                
                if status != .authorized {
                    Button(action: action) {
                        HStack(spacing: 4) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.6)
                            } else {
                                Text("Autoriser")
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isLoading ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .disabled(isLoading)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    PermissionsView()
}

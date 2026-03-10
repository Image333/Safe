//
//  VoiceMonitoringView.swift
//  Safe
//
//  Created by Imane on 04/08/2025.
//

import SwiftUI

struct VoiceMonitoringView: View {
    @Injected(\.voiceMonitoringService) private var voiceMonitoringService
    @Injected(\.scheduleService) private var scheduleService
    @Injected(\.permissionService) private var permissionService
    @StateObject private var audioPlaybackService = AudioPlaybackService()
    @StateObject private var fileManagementService = FileManagementService()
    @State private var showAlert = false
    @State private var recordings: [URL] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Status de la programmation automatique
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Surveillance automatique")
                                .font(.headline)
                            
                            let isInSchedule = scheduleService.isInActiveTimeSlot
                            
                            if isInSchedule {
                                Text("Créneau actif: 17h00-17h30")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            } else {
                                Text("Prochain créneau: 17h00-17h30")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Status de l'écoute
                VStack(spacing: 15) {
                    Image(systemName: voiceMonitoringService.isListening ? "ear.fill" : "ear")
                        .font(.system(size: 60))
                        .foregroundColor(voiceMonitoringService.isListening ? .green : .gray)
                        .scaleEffect(voiceMonitoringService.isListening ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: voiceMonitoringService.isListening)
                    
                    VStack(spacing: 4) {
                        Text(voiceMonitoringService.isListening ? "Écoute active..." : "Écoute désactivée")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(voiceMonitoringService.isListening ? .green : .secondary)
                        
                        if voiceMonitoringService.isScheduledListening {
                            Text("Mode automatique")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Controles
                VStack(spacing: 20) {
                    if voiceMonitoringService.isScheduledListening {
                        VStack(spacing: 10) {
                            Text("Écoute programmée en cours")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            Text("L'écoute se fait automatiquement selon votre programmation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    } else {
                        Button(action: {
                            // Test manuel de l'écoute
                            if voiceMonitoringService.isListening {
                                voiceMonitoringService.stopMonitoring()
                            } else {
                                voiceMonitoringService.startMonitoring()
                            }
                        }) {
                            HStack {
                                Image(systemName: voiceMonitoringService.isListening ? "stop.circle.fill" : "play.circle.fill")
                                Text(voiceMonitoringService.isListening ? "Arrêter test" : "Tester l'écoute")
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                            .background(voiceMonitoringService.isListening ? Color.red : Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    
                    // Mots-clés détectés
                    if !voiceMonitoringService.lastDetectedText.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Derniers mots détectés:")
                                .font(.headline)
                            
                            Text(voiceMonitoringService.lastDetectedText)
                                .font(.body)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Status d'enregistrement
                    if voiceMonitoringService.isRecording {
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "record.circle.fill")
                                    .foregroundColor(.red)
                                    .scaleEffect(1.2)
                                Text("Enregistrement en cours...")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.red)
                            
                            Text(String(format: "%.1f / 10.0 sec", voiceMonitoringService.recordingDuration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
                
                // Liste des enregistrements
                if !recordings.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Enregistrements d'urgence:")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(recordings, id: \.self) { url in
                                    RecordingRowView(url: url) {
                                        loadRecordings()
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Surveillance Vocale")
            .onAppear {
                setupVoiceMonitoring()
                loadRecordings()
            }
            .onDisappear {
                // La gestion de l'arrêt est maintenant dans le service
                if !scheduleService.isScheduledMode {
                    voiceMonitoringService.stopMonitoring()
                }
            }
            .alert("Mot-clé détecté!", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text("Un enregistrement de 10 secondes a été démarré.")
            }
        }
    }
    
    private func setupVoiceMonitoring() {
        // Configuration initiale - les callbacks sont maintenant intégrés dans les services
        loadRecordings()
    }
    
    private func loadRecordings() {
        recordings = fileManagementService.getAllRecordings()
    }
}

struct RecordingRowView: View {
    let url: URL
    let onDelete: () -> Void
    @StateObject private var audioPlaybackService = AudioPlaybackService()
    @StateObject private var fileManagementService = FileManagementService()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatFileName(url.lastPathComponent))
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(formatDate(from: url))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let size = fileManagementService.getFileSize(for: url) {
                    Text(fileManagementService.formatFileSize(size))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 15) {
                Button(action: {
                    audioPlaybackService.playRecording(at: url)
                }) {
                    Image(systemName: audioPlaybackService.currentPlayingURL == url && audioPlaybackService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundColor(audioPlaybackService.currentPlayingURL == url && audioPlaybackService.isPlaying ? .orange : .blue)
                }
                
                Button(action: {
                    if fileManagementService.deleteRecording(at: url) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formatFileName(_ fileName: String) -> String {
        return fileName.replacingOccurrences(of: "emergency_", with: "Urgence ")
            .replacingOccurrences(of: ".m4a", with: "")
    }
    
    private func formatDate(from url: URL) -> String {
        let timeInterval = url.lastPathComponent
            .replacingOccurrences(of: "emergency_", with: "")
            .replacingOccurrences(of: ".m4a", with: "")
        
        if let timestamp = Double(timeInterval) {
            let date = Date(timeIntervalSince1970: timestamp)
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        return "Date inconnue"
    }
}

#Preview {
    VoiceMonitoringView()
}

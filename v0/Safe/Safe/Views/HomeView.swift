//
//  HomeView.swift
//  Safe

import SwiftUI

struct HomeView: View {
    @StateObject private var scheduleManager: ScheduleManager
    @StateObject private var audioPlaybackService = AudioPlaybackService()
    @StateObject private var fileManagementService = FileManagementService()
    @Injected(\.voiceMonitoringService) private var voiceMonitoringService
    @State private var showAlert = false
    @State private var recordings: [URL] = []
    @State private var showRecordings = false
    
    init() {
        let container = DependencyContainer.shared
        let scheduleService = container.scheduleService as! ScheduleManagementService
        _scheduleManager = StateObject(wrappedValue: ScheduleManager(scheduleService: scheduleService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Bienvenue dans Safe")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // MARK: - Schedule Status Widget
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(scheduleManager.isCurrentlyActive ? .green : .orange)
                        Text("Surveillance programmée")
                            .font(.headline)
                        Spacer()
                        NavigationLink {
                            scheduleManager.createScheduleView()
                        } label: {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    scheduleManager.createStatusView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // MARK: - Mes enregistrements
                VStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showRecordings.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                                .foregroundColor(.blue)
                            Text("Mes enregistrements")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: showRecordings ? "chevron.up" : "chevron.down")
                                .foregroundColor(.blue)
                                .rotationEffect(.degrees(showRecordings ? 180 : 0))
                                .animation(.easeInOut(duration: 0.3), value: showRecordings)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    if showRecordings {
                        if recordings.isEmpty {
                            Text("Aucun enregistrement trouvé")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 10)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(recordings, id: \.self) { url in
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                            .foregroundColor(.blue)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Audio")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            
                                            Text(formatDate(from: url))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 12) {
                                            Button(action: {
                                                audioPlaybackService.playRecording(at: url)
                                            }) {
                                                Image(systemName: audioPlaybackService.currentPlayingURL == url && audioPlaybackService.isPlaying ? "pause.fill" : "play.fill")
                                                    .font(.caption)
                                                    .foregroundColor(audioPlaybackService.currentPlayingURL == url && audioPlaybackService.isPlaying ? .orange : .green)
                                            }
                                            
                                            Button(action: {
                                                if fileManagementService.deleteRecording(at: url) {
                                                    loadRecordings()
                                                }
                                            }) {
                                                Image(systemName: "trash.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                                }
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Safe")
            .onAppear {
                loadRecordings()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Recharger les enregistrements quand l'app revient au premier plan
                loadRecordings()
            }
            .onReceive(NotificationCenter.default.publisher(for: .emergencyRecordingComplete)) { _ in
                // Recharger les enregistrements quand un nouvel enregistrement est créé
                loadRecordings()
            }
        }
    }
    
    private func loadRecordings() {
        recordings = fileManagementService.getAllRecordings()
    }
    
    private func formatDate(from url: URL) -> String {
        let fileName = url.lastPathComponent
        let timeInterval = fileName
            .replacingOccurrences(of: "emergency_", with: "")
            .replacingOccurrences(of: ".m4a", with: "")
            .replacingOccurrences(of: ".wav", with: "")
        
        if let timestamp = Double(timeInterval) {
            let date = Date(timeIntervalSince1970: timestamp)
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "fr_FR")
            return formatter.string(from: date)
        }
        
        return "Date inconnue"
    }
}

#Preview {
    HomeView()
}

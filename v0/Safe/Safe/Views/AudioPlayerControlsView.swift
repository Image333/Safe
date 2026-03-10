//
//  AudioPlayerControlsView.swift
//  Safe
//
//  Created by Imane on 19/09/2025.
//

import SwiftUI

/// Vue des contrôles de lecture audio avec barre de progression
struct AudioPlayerControlsView: View {
    @ObservedObject var audioService: AudioPlaybackService
    let url: URL
    
    var body: some View {
        VStack(spacing: 8) {
            // Barre de progression
            if audioService.currentPlayingURL == url && audioService.isPlaying {
                ProgressView(value: audioService.playbackProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 4)
                    .cornerRadius(2)
            }
            
            // Contrôles de lecture
            HStack(spacing: 16) {
                // Bouton play/pause
                Button(action: {
                    if audioService.currentPlayingURL == url && audioService.isPlaying {
                        audioService.pausePlayback()
                    } else if audioService.currentPlayingURL == url && !audioService.isPlaying {
                        audioService.resumePlayback()
                    } else {
                        audioService.playRecording(at: url)
                    }
                }) {
                    Image(systemName: getPlayButtonIcon())
                        .font(.title2)
                        .foregroundColor(getPlayButtonColor())
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                }
                
                // Bouton stop (si en cours de lecture)
                if audioService.currentPlayingURL == url {
                    Button(action: {
                        audioService.stopPlayback()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.red.opacity(0.1)))
                    }
                }
            }
        }
    }
    
    private func getPlayButtonIcon() -> String {
        if audioService.currentPlayingURL == url {
            return audioService.isPlaying ? "pause.fill" : "play.fill"
        } else {
            return "play.fill"
        }
    }
    
    private func getPlayButtonColor() -> Color {
        if audioService.currentPlayingURL == url && audioService.isPlaying {
            return .orange
        } else {
            return .blue
        }
    }
}

/// Vue d'un enregistrement avec contrôles audio avancés
struct EnhancedRecordingRowView: View {
    let url: URL
    let onDelete: () -> Void
    @StateObject private var audioPlaybackService = AudioPlaybackService()
    @StateObject private var fileManagementService = FileManagementService()
    
    var body: some View {
        VStack(spacing: 12) {
            // Informations du fichier
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatFileName(url.lastPathComponent))
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text(formatDate(from: url))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let size = fileManagementService.getFileSize(for: url) {
                        Text(fileManagementService.formatFileSize(size))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Bouton suppression
                Button(action: {
                    if fileManagementService.deleteRecording(at: url) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
            
            // Contrôles audio
            AudioPlayerControlsView(audioService: audioPlaybackService, url: url)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func formatFileName(_ fileName: String) -> String {
        // Enlever l'extension et formatter le nom
        let nameWithoutExtension = fileName.replacingOccurrences(of: ".m4a", with: "").replacingOccurrences(of: ".wav", with: "")
        
        // Remplacer les underscores par des espaces
        let formatted = nameWithoutExtension.replacingOccurrences(of: "_", with: " ")
        
        // Capitaliser les mots
        return formatted.capitalized
    }
    
    private func formatDate(from url: URL) -> String {
        if let date = fileManagementService.getCreationDate(for: url) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "fr_FR")
            return formatter.string(from: date)
        } else {
            return "Date inconnue"
        }
    }
}
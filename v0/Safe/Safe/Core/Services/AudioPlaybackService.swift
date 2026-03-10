//
//  AudioPlaybackService.swift
//  Safe
//
//  Created by Imane on 19/09/2025.
//

import Foundation
import AVFoundation
import Combine

/// Service de lecture audio pour les enregistrements
final class AudioPlaybackService: NSObject, ObservableObject {
    
    // MARK: - Properties
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isPlaying: Bool = false
    @Published var currentPlayingURL: URL?
    @Published var playbackProgress: Double = 0.0
    
    private var progressTimer: Timer?
    
    // MARK: - Public Methods
    
    func playRecording(at url: URL) {
        // Si on joue déjà ce fichier, arrêter
        if currentPlayingURL == url && isPlaying {
            stopPlayback()
            return
        }
        
        // Arrêter toute lecture en cours
        stopPlayback()
        
        // CRUCIAL: Notifier le système d'écoute AVANT de commencer la lecture
        // pour qu'il arrête le monitoring vocal et libère les ressources audio
        NotificationCenter.default.post(
            name: Notification.Name("AudioPlaybackWillStartNotification"),
            object: nil
        )
        
        // Attendre un peu que le monitoring s'arrête proprement
        Thread.sleep(forTimeInterval: 0.3)
        
        do {
            // Configurer la session audio pour la lecture avec une configuration plus explicite
            let audioSession = AVAudioSession.sharedInstance()
            
            // D'abord désactiver toute session existante
            try? audioSession.setActive(false)
            
            // Attendre que la session soit complètement désactivée
            Thread.sleep(forTimeInterval: 0.2)
            
            // Puis configurer notre session de lecture avec des options spécifiques
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            
            // Activer la session en notifiant les autres pour une meilleure interopérabilité
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            
            // Créer et configurer le lecteur audio
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // Démarrer la lecture
            if audioPlayer?.play() == true {
                isPlaying = true
                currentPlayingURL = url
                startProgressTimer()
            }
            
        } catch {
            isPlaying = false
            currentPlayingURL = nil
        }
    }
    
    func stopPlayback() {
        if audioPlayer != nil {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlaying = false
            currentPlayingURL = nil
            playbackProgress = 0.0
            stopProgressTimer()
        }
        
        // Restaurer la session audio d'une façon qui permet au service d'enregistrement de reprendre
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignorer les erreurs de désactivation
        }
        
        // Attendre un peu pour que le hardware audio se stabilise complètement
        Thread.sleep(forTimeInterval: 0.3)
        
        // TOUJOURS poster la notification, même en cas d'erreur
        // pour s'assurer que le service d'enregistrement est notifié
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("AudioPlaybackDidFinishNotification"),
                object: nil
            )
        }
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
    }
    
    func resumePlayback() {
        if audioPlayer?.play() == true {
            isPlaying = true
            startProgressTimer()
        }
    }
    
    // MARK: - Private Methods
    
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        
        if player.duration > 0 {
            playbackProgress = player.currentTime / player.duration
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopPlayback()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.currentPlayingURL = nil
            self?.playbackProgress = 0.0
            self?.stopProgressTimer()
            
            // Restaurer la session audio et notifier les autres composants
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                // Ignorer les erreurs
            }
            
            // TOUJOURS envoyer la notification, même en cas d'erreur
            // Cette séparation évite que les erreurs de session audio empêchent l'envoi de la notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationCenter.default.post(
                    name: Notification.Name("AudioPlaybackDidFinishNotification"),
                    object: nil
                )
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.stopPlayback()
        }
    }
}

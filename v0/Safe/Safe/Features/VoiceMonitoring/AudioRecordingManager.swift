//
//  AudioRecordingManager.swift
//  Safe
//
//  Created by Imane on 04/08/2025.
//

import Foundation
import AVFoundation

class AudioRecordingManager: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastRecordingURL: URL?
    
    private let maxRecordingDuration: TimeInterval = 10.0 // Changé à 10 secondes
    
    func startRecording() {
        guard !isRecording else {
            return
        }
        
        // Configuration de la session audio optimisée pour éviter les conflits
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configuration plus conservative pour éviter les conflits avec la reconnaissance vocale
            // Utiliser .mixWithOthers pour permettre la coexistence avec la reconnaissance vocale
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetoothHFP, .defaultToSpeaker])
            
            // Activer la session uniquement si elle n'est pas déjà active
            // Cela réduit les conflits avec d'autres composants audio
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            }
            
        } catch let error as NSError {
            // Gestion intelligente des erreurs audio
            if error.domain == "NSOSStatusErrorDomain" && error.code == 560557684 {
            } else {
                // Ne pas bloquer l'enregistrement pour cette erreur non-critique
            }
        }
        
        // Créer l'URL du fichier
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("emergency_\(Date().timeIntervalSince1970).m4a")
        
        // Configuration de l'enregistrement compatible AAC
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 96000
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            
            let success = audioRecorder?.record() ?? false
            
            if success {
                isRecording = true
                lastRecordingURL = audioFilename
                
                
                // Timer pour arrêter automatiquement
                recordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
                    self?.stopRecording()
                }
                
                // Timer pour mettre à jour la durée
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                    guard let self = self, self.isRecording else {
                        timer.invalidate()
                        return
                    }
                    
                    if let recorder = self.audioRecorder {
                        self.recordingDuration = recorder.currentTime
                    }
                    
                    if self.recordingDuration >= self.maxRecordingDuration {
                        timer.invalidate()
                    }
                }
            } else {
            }
            
        } catch {
            
            // Essayer avec une configuration encore plus simple en cas d'échec
            do {
                let fallbackSettings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 22050.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
                ]
                
                audioRecorder = try AVAudioRecorder(url: audioFilename, settings: fallbackSettings)
                audioRecorder?.delegate = self
                audioRecorder?.prepareToRecord()
                
                if audioRecorder?.record() == true {
                    isRecording = true
                    lastRecordingURL = audioFilename
                    
                    recordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
                        self?.stopRecording()
                    }
                } else {
                    
                    // Troisième tentative avec le format le plus basique possible
                    let ultraBasicSettings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatLinearPCM),
                        AVSampleRateKey: 16000.0,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false,
                        AVLinearPCMIsBigEndianKey: false
                    ]
                    
                    // Changer l'extension pour le format PCM
                    let pcmFilename = documentsPath.appendingPathComponent("emergency_\(Date().timeIntervalSince1970).wav")
                    
                    do {
                        audioRecorder = try AVAudioRecorder(url: pcmFilename, settings: ultraBasicSettings)
                        audioRecorder?.delegate = self
                        audioRecorder?.prepareToRecord()
                        
                        if audioRecorder?.record() == true {
                            isRecording = true
                            lastRecordingURL = pcmFilename
                            
                            recordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
                                self?.stopRecording()
                            }
                        }
                    } catch {
                    }
                }
            } catch {
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        isRecording = false
        recordingDuration = 0
        
        if let url = lastRecordingURL {
            
            // Vérifier que le fichier existe bien
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    // Vérifier que le fichier a une taille raisonnable (au moins 1KB)
                    if fileSize < 1024 {
                    }
                } catch {
                }
            } else {
            }
        } else {
        }
        
        // Ne pas désactiver la session audio pour permettre la coexistence
        // avec la reconnaissance vocale en cours
    }
    
    // MARK: - Audio Player
    private var audioPlayer: AVAudioPlayer?
    
    func playLastRecording() {
        guard let url = lastRecordingURL else {
            return
        }
        playRecording(at: url)
    }
    
    func playRecording(at url: URL) {
        // Vérifier que le fichier existe
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        
        
        // Arrêter la lecture en cours si elle existe
        audioPlayer?.stop()
        
        do {
            // Configurer la session audio pour la lecture
            let audioSession = AVAudioSession.sharedInstance()
            
            do {
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
            } catch let error as NSError {
                // Ignorer l'erreur 560557684
                if error.domain == "NSOSStatusErrorDomain" && error.code == 560557684 {
                } else {
                }
            }
            
            // Créer et configurer le lecteur audio
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            
            let success = audioPlayer?.play() ?? false
            
            if success {
                
                // Poster une notification après la fin de lecture pour réactiver la reconnaissance
                DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0) + 0.5) {
                    NotificationCenter.default.post(name: Notification.Name("AudioPlaybackDidFinishNotification"), object: nil)
                }
            } else {
            }
        } catch {
            
            // Vérifier les attributs du fichier
            do {
                let _ = try FileManager.default.attributesOfItem(atPath: url.path)
            } catch {
            }
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
        }
    }
    
    func getAllRecordings() -> [URL] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            // Supporter à la fois les fichiers m4a et wav pour les enregistrements d'urgence
            return files.filter { 
                (($0.pathExtension == "m4a" || $0.pathExtension == "wav") && 
                 $0.lastPathComponent.contains("emergency"))
            }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            return []
        }
    }
}

extension AudioRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            
            // Notifier que l'enregistrement est terminé pour rafraîchir l'interface
            NotificationCenter.default.post(name: .emergencyRecordingComplete, object: lastRecordingURL)
        } else {
        }
        
        // S'assurer que l'état est correctement mis à jour
        isRecording = false
        recordingDuration = 0
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        
        // Arrêter l'enregistrement en cas d'erreur
        stopRecording()
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let emergencyRecordingComplete = Notification.Name("emergencyRecordingComplete")
}

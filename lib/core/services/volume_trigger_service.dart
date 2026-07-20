import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:volume_watcher/volume_watcher.dart';

import 'emergency_audio_service.dart';

/// Callback appelé quand une triple pression est détectée
typedef OnTriplePressCallback = void Function();

/// Service qui détecte les triples pressions sur le bouton volume
/// et déclenche un enregistrement audio d'urgence
class VolumeTriggerService {
  static const int _detectionWindowMs = 1500; // 1.5 secondes pour les 3 pressions
  static const int _recordingDurationSec = 15; // Durée de l'enregistrement en secondes
  static const double _minVolumeChange = 0.05; // Changement minimum pour détecter une pression

  final EmergencyAudioService _audioService;
  
  bool _isListening = false;
  bool _isRecording = false;
  
  final List<DateTime> _volumePressTimes = [];
  int? _volumeListenerId;
  double? _lastVolume;
  
  OnTriplePressCallback? onTriplePress;

  VolumeTriggerService({EmergencyAudioService? audioService})
      : _audioService = audioService ?? EmergencyAudioService();

  /// Active la détection des triples pressions volume
  Future<void> startListening({OnTriplePressCallback? callback}) async {
    if (_isListening) return;

    _isListening = true;
    onTriplePress = callback;
    _volumePressTimes.clear();
    
    if (kDebugMode) {
      debugPrint('🎧 VolumeTrigger: Démarrage de l\'écoute...');
    }
    
    _lastVolume = await VolumeWatcher.getCurrentVolume;
    
    if (kDebugMode) {
      debugPrint('🎧 VolumeTrigger: Volume initial = $_lastVolume');
    }

    // Écoute les changements de volume
    _volumeListenerId = VolumeWatcher.addListener((double volume) {
      if (kDebugMode) {
        debugPrint('📊 VolumeTrigger: Volume changé = $volume');
      }
      _onVolumeChange(volume);
    });
    
    if (kDebugMode) {
      debugPrint('🎧 VolumeTrigger: Listener ID = $_volumeListenerId');
    }
  }

  /// Désactive la détection
  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    if (_volumeListenerId != null) {
      VolumeWatcher.removeListener(_volumeListenerId);
      _volumeListenerId = null;
    }
    _volumePressTimes.clear();
    _lastVolume = null;
  }

  /// Retourne true si le service est en écoute
  bool get isListening => _isListening;

  /// Retourne true si un enregistrement est en cours
  bool get isRecording => _isRecording;

  /// Callback appelé à chaque changement de volume
  void _onVolumeChange(double newVolume) {
    if (kDebugMode) {
      debugPrint('📊 Volume event: $newVolume');
    }
    
    // Sur iOS, les boutons peuvent déclencher des événements même sans changer le volume
    // On compte simplement les événements reçus rapidement
    _registerVolumePress();
    
    _lastVolume = newVolume;
  }

  /// Enregistre une pression volume et vérifie si on a 3 pressions
  void _registerVolumePress() {
    final now = DateTime.now();
    
    // Nettoyer les pressions trop anciennes
    _volumePressTimes.removeWhere((time) {
      return now.difference(time).inMilliseconds > _detectionWindowMs;
    });

    // Ajouter la nouvelle pression
    _volumePressTimes.add(now);
    
    if (kDebugMode) {
      debugPrint('👆 Pression ${_volumePressTimes.length}/3');
    }

    // Vérifier si on a 3 pressions dans la fenêtre de détection
    if (_volumePressTimes.length >= 3) {
      if (kDebugMode) {
        debugPrint('🎉 TRIPLE PRESSION DÉTECTÉE!');
      }
      _onTriplePress();
      _volumePressTimes.clear();
    }
  }

  /// Appelé quand une triple pression est détectée
  void _onTriplePress() {
    if (_isRecording) return;

    if (kDebugMode) {
      debugPrint('🎙️ Triple pression détectée ! Démarrage de l\'enregistrement...');
    }
    
    // Notifier le callback si défini
    onTriplePress?.call();
    
    _startRecording();
  }

  /// Démarre l'enregistrement audio
  Future<void> _startRecording() async {
    if (_isRecording) return;

    _isRecording = true;

    try {
      final filePath = await _audioService.recordClip(
        durationSec: _recordingDurationSec,
      );
      
      if (kDebugMode) {
        debugPrint('✅ Enregistrement terminé : $filePath');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors de l\'enregistrement : $error');
      }
    } finally {
      _isRecording = false;
    }
  }

  /// Nettoie les ressources
  Future<void> dispose() async {
    await stopListening();
    await _audioService.dispose();
  }
}

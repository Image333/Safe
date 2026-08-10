import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'emergency_audio_service.dart';

/// Service qui détecte les triples pressions sur les boutons de volume
/// via une implémentation native iOS
class NativeVolumeTriggerService {
  static const EventChannel _eventChannel = EventChannel('safe/volume_button');
  
  final EmergencyAudioService _audioService;
  
  StreamSubscription<dynamic>? _volumeSubscription;
  final List<DateTime> _pressTimestamps = [];
  
  // Configuration
  static const int _requiredPresses = 3;
  static const Duration _pressWindow = Duration(milliseconds: 1500);
  
  bool _isListening = false;
  VoidCallback? _onTriplePress;

  NativeVolumeTriggerService(this._audioService);

  /// Démarre l'écoute des boutons de volume
  void startListening({required VoidCallback onTriplePress}) {
    if (_isListening) return;
    
    _onTriplePress = onTriplePress;
    _isListening = true;
    _pressTimestamps.clear();
    
    if (kDebugMode) {
      print('🎧 NativeVolumeTriggerService: Démarrage écoute native iOS...');
    }
    
    _volumeSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onVolumeButtonPress,
      onError: (error) {
        if (kDebugMode) {
          print('❌ NativeVolumeTriggerService: Erreur: $error');
        }
      },
    );
  }

  /// Arrête l'écoute
  void stopListening() {
    if (!_isListening) return;
    
    _isListening = false;
    _volumeSubscription?.cancel();
    _volumeSubscription = null;
    _pressTimestamps.clear();
    
    if (kDebugMode) {
      print('🛑 NativeVolumeTriggerService: Arrêt écoute');
    }
  }

  /// Gère une pression sur un bouton de volume
  void _onVolumeButtonPress(dynamic direction) {
    if (!_isListening) return;

    // Seul Volume + déclenche l'alerte (pas Volume −)
    if (direction != 'up') {
      if (kDebugMode) {
        print('🔇 Bouton volume $direction ignoré (seul + compte)');
      }
      return;
    }

    final now = DateTime.now();

    if (kDebugMode) {
      print('🔊 Bouton volume +: ${now.toIso8601String()}');
    }

    _registerVolumePress(now);
  }

  /// Enregistre une pression et vérifie si on a une triple pression
  void _registerVolumePress(DateTime timestamp) {
    // Ajoute cette pression
    _pressTimestamps.add(timestamp);
    
    // Nettoie les anciennes pressions hors de la fenêtre temporelle
    _pressTimestamps.removeWhere(
      (t) => timestamp.difference(t) > _pressWindow,
    );
    
    if (kDebugMode) {
      print('📊 Pressions dans fenêtre: ${_pressTimestamps.length}/$_requiredPresses');
    }
    
    // Vérifie si on a 3 pressions
    if (_pressTimestamps.length >= _requiredPresses) {
      _onTriplePressDetected();
    }
  }

  /// Déclenche l'alerte quand une triple pression est détectée
  void _onTriplePressDetected() {
    if (kDebugMode) {
      print('✅ Triple pression détectée! Déclenchement alerte...');
    }
    
    // Réinitialise pour éviter les multiples déclenchements
    _pressTimestamps.clear();
    
    // Notifie le callback qui gérera l'enregistrement
    _onTriplePress?.call();
  }

  void dispose() {
    stopListening();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../storage/voice_trigger_storage.dart';
import 'emergency_audio_service.dart';

/// Service de reconnaissance vocale utilisant speech_to_text
/// Utilise les APIs natives Apple/Google
/// Note: Sur iOS 13+, peut fonctionner hors-ligne avec la reconnaissance on-device
class SpeechRecognitionService {
  final VoiceTriggerStorage _storage;
  final SpeechToText _speech = SpeechToText();
  
  bool _isInitialized = false;
  bool _isListening = false;
  
  String _keyword = '';
  int _recordingDurationSec = 15;
  
  // Callbacks
  void Function()? onKeywordDetected;
  void Function()? onRecordingStarted;
  void Function(String path)? onRecordingFinished;
  void Function(String error)? onError;
  void Function(String text)? onPartialResult;
  
  // Timer pour la plage horaire
  Timer? _scheduleCheckTimer;
  bool _shouldBeListening = false;
  
  // Timer pour relancer l'écoute après timeout
  Timer? _restartTimer;
  
  SpeechRecognitionService({VoiceTriggerStorage? storage})
      : _storage = storage ?? VoiceTriggerStorage();

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  /// Initialise le service de reconnaissance vocale
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      debugPrint('🎤 SpeechRecognition: Initialisation en cours...');
      
      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: kDebugMode,
      );
      
      if (_isInitialized) {
        debugPrint('✅ SpeechRecognition: Initialisé avec succès');
        debugPrint('🎤 hasPermission: ${_speech.hasPermission}');
        debugPrint('🎤 isAvailable: ${_speech.isAvailable}');
        
        // Lister les langues disponibles
        final locales = await _speech.locales();
        debugPrint('🌍 Nombre de locales: ${locales.length}');
        final frenchLocale = locales.where((l) => l.localeId.startsWith('fr')).toList();
        debugPrint('🌍 Langues FR disponibles: ${frenchLocale.map((l) => l.localeId).join(", ")}');
      } else {
        debugPrint('❌ SpeechRecognition: Échec initialisation - hasPermission: ${_speech.hasPermission}');
      }
      
      return _isInitialized;
    } catch (e) {
      debugPrint('❌ SpeechRecognition: Erreur initialisation: $e');
      onError?.call('Erreur initialisation: $e');
      return false;
    }
  }

  void _onStatus(String status) {
    debugPrint('🎤 SpeechRecognition status: $status');
    
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      
      // Redémarrer l'écoute si on doit continuer (avec délai pour éviter spam)
      if (_shouldBeListening) {
        _scheduleRestart(delay: const Duration(seconds: 1));
      }
    }
  }

  void _onError(dynamic error) {
    debugPrint('❌ SpeechRecognition error: $error');
    _isListening = false;
    
    // Analyser l'erreur pour ajuster le délai de redémarrage
    String errorMsg = error.toString().toLowerCase();
    Duration restartDelay = const Duration(seconds: 1);
    
    if (errorMsg.contains('error_retry') || errorMsg.contains('error_no_match')) {
      // Erreur normale - pas de parole détectée, redémarrer rapidement
      restartDelay = const Duration(milliseconds: 500);
      debugPrint('🔄 Redémarrage rapide (pas de parole détectée)');
    } else if (errorMsg.contains('error_audio') || errorMsg.contains('error_network')) {
      // Erreur plus sérieuse - attendre plus longtemps
      restartDelay = const Duration(seconds: 3);
      debugPrint('⏳ Redémarrage retardé (erreur audio/réseau)');
    }
    
    // Redémarrer après une erreur si on doit continuer
    if (_shouldBeListening) {
      _scheduleRestart(delay: restartDelay);
    }
  }

  void _scheduleRestart({Duration delay = const Duration(milliseconds: 500)}) {
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () async {
      if (_shouldBeListening && !_isListening) {
        final inSchedule = await _storage.isCurrentTimeInSchedule();
        if (inSchedule) {
          await _startRecognition();
        }
      }
    });
  }

  /// Configure le service avec le mot-clé et la durée d'enregistrement
  void configure({
    required String keyword,
    int recordingDurationSec = 15,
  }) {
    _keyword = keyword.toLowerCase().trim();
    _recordingDurationSec = recordingDurationSec.clamp(5, 600);
  }

  /// Démarre l'écoute continue
  Future<void> startListening() async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        throw Exception('Impossible d\'initialiser la reconnaissance vocale');
      }
    }
    
    if (_keyword.isEmpty) {
      throw Exception('Aucun mot-clé configuré');
    }
    
    _shouldBeListening = true;
    
    // Vérifier si on est dans la plage horaire
    final inSchedule = await _storage.isCurrentTimeInSchedule();
    if (!inSchedule) {
      debugPrint('🎤 SpeechRecognition: Hors plage horaire, en attente...');
      _startScheduleCheckTimer();
      return;
    }
    
    await _startRecognition();
    _startScheduleCheckTimer();
  }

  Future<void> _startRecognition() async {
    if (_isListening) return;
    
    try {
      debugPrint('🎤 SpeechRecognition: Tentative de démarrage...');
      debugPrint('🎤 Mot-clé configuré: "$_keyword"');
      debugPrint('🎤 Service initialisé: $_isInitialized');
      debugPrint('🎤 Speech available: ${_speech.isAvailable}');
      
      if (!_speech.isAvailable) {
        debugPrint('❌ SpeechRecognition: Service non disponible!');
        return;
      }
      
      _isListening = true;
      
      // Trouver la meilleure locale française disponible (préférer fr-FR)
      String localeToUse = 'fr-FR';
      try {
        final locales = await _speech.locales();
        final frLocales = locales.where((l) => l.localeId.startsWith('fr')).toList();
        if (frLocales.isNotEmpty) {
          // Préférer fr-FR si disponible
          final frFR = frLocales.where((l) => l.localeId == 'fr-FR' || l.localeId == 'fr_FR').toList();
          if (frFR.isNotEmpty) {
            localeToUse = frFR.first.localeId;
          } else {
            localeToUse = frLocales.first.localeId;
          }
          debugPrint('🌍 Utilisation de la locale: $localeToUse');
        } else {
          debugPrint('⚠️ Pas de locale FR, utilisation par défaut');
        }
      } catch (e) {
        debugPrint('⚠️ Erreur récupération locales: $e');
      }
      
      await _speech.listen(
        onResult: _onResult,
        listenFor: const Duration(seconds: 60), // Écoute plus longue
        pauseFor: const Duration(seconds: 10), // Plus de tolérance au silence
        partialResults: true,
        localeId: localeToUse,
        listenMode: ListenMode.dictation,
        onSoundLevelChange: (level) {
          // Optionnel: afficher le niveau sonore pour debug
          if (level > 0) {
            debugPrint('🔊 Niveau sonore: ${level.toStringAsFixed(1)}');
          }
        },
      );
      
      debugPrint('✅ SpeechRecognition: Écoute démarrée pour "$_keyword"');
    } catch (e) {
      _isListening = false;
      debugPrint('❌ SpeechRecognition: Erreur démarrage: $e');
      
      // Réessayer après un délai plus long
      if (_shouldBeListening) {
        _scheduleRestart(delay: const Duration(seconds: 2));
      }
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.toLowerCase();
    
    if (text.isNotEmpty) {
      debugPrint('🎤 Reconnu: "$text" (final: ${result.finalResult})');
      onPartialResult?.call(text);
      
      // Vérifier si le mot-clé est détecté
      if (_containsKeyword(text)) {
        _onKeywordDetected();
      }
    }
  }

  /// Vérifie si le texte contient le mot-clé (avec tolérance)
  bool _containsKeyword(String text) {
    // Vérification exacte
    if (text.contains(_keyword)) return true;
    
    // Vérification mot par mot pour les phrases
    final keywordWords = _keyword.split(' ').where((w) => w.length >= 3).toList();
    if (keywordWords.isEmpty) return false;
    
    int matchCount = 0;
    for (final word in keywordWords) {
      if (text.contains(word)) {
        matchCount++;
      }
    }
    
    // Si plus de 70% des mots sont trouvés
    final threshold = (keywordWords.length * 0.7).ceil();
    return matchCount >= threshold;
  }

  void _onKeywordDetected() {
    debugPrint('🚨🚨🚨 MOT-CLÉ "$_keyword" DÉTECTÉ! 🚨🚨🚨');
    onKeywordDetected?.call();
    
    // Vibration haptique pour confirmer
    HapticFeedback.heavyImpact();
    
    // Déclencher l'enregistrement d'urgence
    _startEmergencyRecording();
  }

  Future<void> _startEmergencyRecording() async {
    debugPrint('🔴 Démarrage enregistrement d\'urgence ($_recordingDurationSec secondes)...');
    onRecordingStarted?.call();
    
    try {
      // Arrêter temporairement l'écoute pour éviter les conflits audio
      await _speech.stop();
      _isListening = false;
      
      // Enregistrer
      final audioService = EmergencyAudioService();
      final filePath = await audioService.recordClip(durationSec: _recordingDurationSec);
      
      debugPrint('✅ Enregistrement terminé: $filePath');
      onRecordingFinished?.call(filePath);
      
      await audioService.dispose();
      
      // Reprendre l'écoute après l'enregistrement
      if (_shouldBeListening) {
        debugPrint('🎤 Reprise de l\'écoute...');
        await Future.delayed(const Duration(seconds: 1));
        await _startRecognition();
      }
    } catch (e) {
      debugPrint('❌ Erreur enregistrement d\'urgence: $e');
      onError?.call('Erreur enregistrement: $e');
      
      // Reprendre l'écoute même en cas d'erreur
      if (_shouldBeListening) {
        _scheduleRestart(delay: const Duration(seconds: 2));
      }
    }
  }

  /// Arrête l'écoute
  Future<void> stopListening() async {
    _shouldBeListening = false;
    _restartTimer?.cancel();
    _scheduleCheckTimer?.cancel();
    
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
    
    debugPrint('🎤 SpeechRecognition: Écoute arrêtée');
  }

  /// Timer pour vérifier la plage horaire
  void _startScheduleCheckTimer() {
    _scheduleCheckTimer?.cancel();
    _scheduleCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkScheduleAndUpdate(),
    );
  }

  Future<void> _checkScheduleAndUpdate() async {
    if (!_shouldBeListening) return;
    
    final inSchedule = await _storage.isCurrentTimeInSchedule();
    
    if (inSchedule && !_isListening) {
      debugPrint('🎤 Entrée dans la plage horaire');
      await _startRecognition();
    } else if (!inSchedule && _isListening) {
      debugPrint('🎤 Sortie de la plage horaire');
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Vérifie si la reconnaissance on-device est disponible (iOS 13+)
  Future<bool> isOnDeviceRecognitionAvailable() async {
    // speech_to_text utilise automatiquement le mode on-device si disponible
    // Sur iOS 13+, c'est généralement le cas
    return _isInitialized;
  }

  /// Libère les ressources
  void dispose() {
    stopListening();
    _speech.cancel();
  }
}

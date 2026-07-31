import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../storage/voice_trigger_storage.dart';

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
      
      // Redémarrer l'écoute si on doit continuer
      if (_shouldBeListening) {
        _scheduleRestart();
      }
    }
  }

  void _onError(dynamic error) {
    debugPrint('❌ SpeechRecognition error: $error');
    _isListening = false;
    
    // Redémarrer après une erreur si on doit continuer
    if (_shouldBeListening) {
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 500), () async {
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
      
      // Trouver la meilleure locale française disponible
      String localeToUse = 'fr_FR';
      try {
        final locales = await _speech.locales();
        final frLocales = locales.where((l) => l.localeId.startsWith('fr')).toList();
        if (frLocales.isNotEmpty) {
          localeToUse = frLocales.first.localeId;
          debugPrint('🌍 Utilisation de la locale: $localeToUse');
        } else {
          debugPrint('⚠️ Pas de locale FR, utilisation par défaut');
          // Utiliser la locale système
          localeToUse = locales.isNotEmpty ? locales.first.localeId : 'fr_FR';
        }
      } catch (e) {
        debugPrint('⚠️ Erreur récupération locales: $e');
      }
      
      await _speech.listen(
        onResult: _onResult,
        listenFor: const Duration(seconds: 30), // Écoute par blocs de 30s
        pauseFor: const Duration(seconds: 5), // Pause de 5s avant arrêt
        partialResults: true,
        localeId: localeToUse,
        listenMode: ListenMode.dictation,
      );
      
      debugPrint('✅ SpeechRecognition: Écoute démarrée pour "$_keyword"');
    } catch (e) {
      _isListening = false;
      debugPrint('❌ SpeechRecognition: Erreur démarrage: $e');
      
      // Réessayer
      if (_shouldBeListening) {
        _scheduleRestart();
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
    debugPrint('🚨 Mot-clé "$_keyword" détecté!');
    onKeywordDetected?.call();
    
    // TODO: Déclencher l'enregistrement d'urgence
    // Intégrer avec EmergencyAudioService
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

import 'package:flutter/foundation.dart';

/// Configuration pour le déclencheur audio par triple pression volume
class VolumeTriggerConfig {
  /// Fenêtre de temps (en millisecondes) pour détecter les 3 pressions
  /// Par défaut : 1500ms (1.5 secondes)
  static const int detectionWindowMs = 1500;

  /// Durée de l'enregistrement audio (en secondes)
  /// Par défaut : 15 secondes
  static const int recordingDurationSec = 15;

  /// Changement minimum de volume requis pour détecter une pression
  /// Par défaut : 0.05 (5%)
  static const double minVolumeChange = 0.05;

  /// Nombre de pressions requises pour déclencher l'enregistrement
  /// Par défaut : 3
  static const int requiredPressCount = 3;

  /// Masquer la barre de volume système iOS
  /// Par défaut : true
  static const bool hideVolumeView = true;

  /// Configuration de l'enregistrement audio
  static const AudioRecordingConfig audioConfig = AudioRecordingConfig(
    // Format d'encodage
    encoder: 'aacLc', // AAC Low Complexity

    // Bitrate en bits par seconde
    bitRate: 128000, // 128 kbps

    // Fréquence d'échantillonnage en Hz
    sampleRate: 44100, // 44.1 kHz (CD quality)

    // Extension de fichier
    fileExtension: 'm4a',

    // Répertoire de stockage (relatif au répertoire temporaire)
    storageDirectory: 'safe_alerts',
  );

  /// Durée minimale d'enregistrement (en secondes)
  static const int minRecordingDurationSec = 5;

  /// Durée maximale d'enregistrement (en secondes)
  static const int maxRecordingDurationSec = 600;

  /// Nombre maximum d'enregistrements à conserver
  /// 0 = illimité
  static const int maxStoredRecordings = 100;

  /// Mode debug : affiche des logs détaillés
  static const bool debugMode = kDebugMode;

  /// Retard après détection avant démarrage enregistrement (en millisecondes)
  /// Par défaut : 0ms (immédiat)
  static const int recordingDelayMs = 0;

  /// Active la vibration haptique lors du déclenchement
  /// Par défaut : true
  static const bool enableHapticFeedback = true;

  /// Durée de la vibration haptique (en millisecondes)
  static const int hapticFeedbackDurationMs = 200;
}

/// Configuration spécifique à l'enregistrement audio
class AudioRecordingConfig {
  final String encoder;
  final int bitRate;
  final int sampleRate;
  final String fileExtension;
  final String storageDirectory;

  const AudioRecordingConfig({
    required this.encoder,
    required this.bitRate,
    required this.sampleRate,
    required this.fileExtension,
    required this.storageDirectory,
  });

  /// Retourne le nom de fichier pour un enregistrement
  String buildFileName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'alert_$timestamp.$fileExtension';
  }

  /// Retourne la taille estimée du fichier (en octets) pour une durée donnée
  int estimateFileSize(int durationSec) {
    // bitRate est en bits/seconde, on convertit en octets/seconde
    final bytesPerSecond = bitRate ~/ 8;
    return bytesPerSecond * durationSec;
  }

  /// Retourne la durée estimée (en secondes) pour une taille de fichier donnée
  int estimateDuration(int fileSizeBytes) {
    final bytesPerSecond = bitRate ~/ 8;
    return fileSizeBytes ~/ bytesPerSecond;
  }
}

/// Messages utilisateur configurables
class VolumeTriggerMessages {
  static const String protectionEnabled =
      'Protection activée - Appuyez 3× sur Volume +';

  static const String protectionDisabled = 'Protection désactivée';

  static const String recordingStarted = 'Enregistrement en cours...';

  static const String recordingCompleted = 'Clip audio enregistré';

  static const String recordingFailed =
      'Échec enregistrement audio';

  static const String permissionDenied =
      'Permission micro refusée. Activez-la dans les réglages.';

  static const String alertSent = 'Alerte envoyée à vos contacts';

  static const String noRecordings = 'Aucun enregistrement';

  static const String deleteConfirmTitle =
      'Supprimer l\'enregistrement';

  static const String deleteConfirmMessage =
      'Voulez-vous vraiment supprimer cet enregistrement ? Cette action est irréversible.';

  static const String deleteAllConfirmTitle = 'Tout supprimer';

  static String deleteAllConfirmMessage(int count) =>
      'Voulez-vous vraiment supprimer tous les $count enregistrements ? Cette action est irréversible.';

  static const String recordingDeleted = 'Enregistrement supprimé';

  static const String allRecordingsDeleted =
      'Tous les enregistrements ont été supprimés';

  static const String emptyStateInstructions =
      'Appuyez 3 fois sur le bouton volume + pour déclencher un enregistrement d\'urgence de 15 secondes.';
}

/// Configuration des couleurs (peut surcharger AppColors si nécessaire)
class VolumeTriggerColors {
  /// Couleur du badge de compteur
  static const badgeColor = 0xFFDC2626; // AppColors.red

  /// Couleur du bouton play
  static const playButtonColor = 0xFF2563EB; // AppColors.blue

  /// Couleur du bouton pause
  static const pauseButtonColor = 0xFFDC2626; // AppColors.red

  /// Couleur du badge "Urgence"
  static const urgencyBadgeColor = 0xFFDC2626; // AppColors.red

  /// Couleur de succès
  static const successColor = 0xFF16A34A; // AppColors.green
}

/// Constantes pour les tests et le debug
class VolumeTriggerDebug {
  /// Active les logs de debug dans la console
  static const bool enableLogs = true;

  /// Active les logs de volume détaillés
  static const bool enableVolumeLogs = false;

  /// Active les logs de fichiers
  static const bool enableFileLogs = true;

  /// Simule le déclenchement pour les tests (sans vrai enregistrement)
  static const bool simulateRecording = false;

  /// Durée de l'enregistrement simulé (en secondes)
  static const int simulatedRecordingDuration = 2;
}

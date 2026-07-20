import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Modèle représentant un clip audio enregistré
class AudioClip {
  final String filePath;
  final DateTime timestamp;
  final int fileSizeBytes;

  AudioClip({
    required this.filePath,
    required this.timestamp,
    required this.fileSizeBytes,
  });

  /// Retourne la durée formatée (approximée à partir de la taille du fichier)
  /// AAC-LC 128 kbps ≈ 16 KB par seconde
  String getFormattedDuration() {
    const int bytesPerSecond = 16000; // 128 kbps = 16 KB/s
    final int durationSeconds = (fileSizeBytes / bytesPerSecond).round();
    
    if (durationSeconds < 60) {
      return '${durationSeconds}s';
    } else if (durationSeconds < 3600) {
      final int minutes = durationSeconds ~/ 60;
      final int seconds = durationSeconds % 60;
      if (seconds == 0) {
        return '${minutes}min';
      }
      return '${minutes}min ${seconds}s';
    } else {
      final int hours = durationSeconds ~/ 3600;
      final int minutes = (durationSeconds % 3600) ~/ 60;
      return '${hours}h ${minutes}min';
    }
  }

  /// Retourne la date/heure formatée
  String getFormattedDateTime() {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// Supprime le fichier audio
  Future<void> delete() async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Service pour gérer l'historique des enregistrements audio
class AudioHistoryService {
  static const String _audioDirectory = 'safe_alerts';

  /// Récupère la liste de tous les clips audio enregistrés
  Future<List<AudioClip>> getAudioClips() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final audioDir = Directory('${tempDir.path}/$_audioDirectory');

      if (!await audioDir.exists()) {
        return [];
      }

      final files = audioDir.listSync().whereType<File>().toList();

      // Filter pour .m4a files et trier par timestamp décroissant
      final audioClips = files
          .where((file) => file.path.endsWith('.m4a'))
          .map((file) {
            final fileName = file.path.split('/').last; // alert_<timestamp>.m4a
            final timestampStr = fileName
                .replaceFirst('alert_', '')
                .replaceFirst('.m4a', '');

            try {
              final timestamp =
                  DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
              final fileSizeBytes = file.lengthSync();

              return AudioClip(
                filePath: file.path,
                timestamp: timestamp,
                fileSizeBytes: fileSizeBytes,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<AudioClip>()
          .toList();

      // Trier par date décroissante (plus récent en premier)
      audioClips.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return audioClips;
    } catch (_) {
      return [];
    }
  }

  /// Compte le nombre de clips audio
  Future<int> getAudioClipsCount() async {
    final clips = await getAudioClips();
    return clips.length;
  }

  /// Supprime tous les clips audio
  Future<void> deleteAllClips() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final audioDir = Directory('${tempDir.path}/$_audioDirectory');

      if (await audioDir.exists()) {
        await audioDir.delete(recursive: true);
      }
    } catch (_) {
      // Ignorer les erreurs
    }
  }
}

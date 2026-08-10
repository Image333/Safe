import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../storage/auth_storage.dart';
import 'api_service.dart';

/// Modèle représentant un clip audio (local ou remote)
class AudioClip {
  final String? filePath;
  final String? blobUrl;
  final DateTime timestamp;
  final int fileSizeBytes;
  final int? durationSec;
  final int? audioId;
  final bool isRemote;

  AudioClip({
    this.filePath,
    this.blobUrl,
    required this.timestamp,
    required this.fileSizeBytes,
    this.durationSec,
    this.audioId,
    this.isRemote = false,
  });

  factory AudioClip.local({
    required String filePath,
    required DateTime timestamp,
    required int fileSizeBytes,
  }) {
    return AudioClip(
      filePath: filePath,
      timestamp: timestamp,
      fileSizeBytes: fileSizeBytes,
      isRemote: false,
    );
  }

  factory AudioClip.fromRemote(RemoteAudioRecord record) {
    DateTime ts = DateTime.now();
    if (record.alertTimestamp != null && record.alertTimestamp!.isNotEmpty) {
      ts = DateTime.tryParse(record.alertTimestamp!.replaceFirst(' ', 'T')) ?? ts;
    }
    return AudioClip(
      blobUrl: record.blobUrl,
      timestamp: ts,
      fileSizeBytes: 0,
      durationSec: record.duration,
      audioId: record.audioId,
      isRemote: true,
    );
  }

  /// Source de lecture (URL remote ou chemin local)
  String get playSource {
    if (isRemote) return blobUrl ?? '';
    return filePath ?? '';
  }

  /// Identifiant unique pour l'UI (play/pause)
  String get id {
    if (audioId != null) return 'remote_$audioId';
    return filePath ?? blobUrl ?? timestamp.toIso8601String();
  }

  /// Retourne la durée formatée
  String getFormattedDuration() {
    final int durationSeconds = durationSec ??
        (fileSizeBytes > 0 ? (fileSizeBytes / 16000).round() : 0);

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

  /// Supprime le fichier audio local (no-op pour remote — pas de DELETE API)
  Future<void> delete() async {
    if (isRemote || filePath == null) return;
    final file = File(filePath!);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Service pour gérer l'historique des enregistrements audio
class AudioHistoryService {
  static const String _audioDirectory = 'safe_alerts';

  final ApiService _apiService;
  final AuthStorage _authStorage;

  AudioHistoryService({
    ApiService? apiService,
    AuthStorage? authStorage,
  })  : _apiService = apiService ?? ApiService(),
        _authStorage = authStorage ?? AuthStorage();

  /// Liste locale + remote si connecté (remote prioritaire si dispo)
  Future<List<AudioClip>> getAudioClips() async {
    final token = await _authStorage.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final remote = await _apiService.getMyAudio(token: token);
        if (remote.isNotEmpty) {
          return remote.map(AudioClip.fromRemote).toList();
        }
      } catch (_) {
        // Fallback local si l'API échoue
      }
    }
    return _getLocalAudioClips();
  }

  Future<List<AudioClip>> _getLocalAudioClips() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final audioDir = Directory('${tempDir.path}/$_audioDirectory');

      if (!await audioDir.exists()) {
        return [];
      }

      final files = audioDir.listSync().whereType<File>().toList();

      final audioClips = files
          .where((file) => file.path.endsWith('.m4a'))
          .map((file) {
            final fileName = file.path.split('/').last;
            final timestampStr = fileName
                .replaceFirst('alert_', '')
                .replaceFirst('.m4a', '');

            try {
              final timestamp =
                  DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
              final fileSizeBytes = file.lengthSync();

              return AudioClip.local(
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

  /// Supprime tous les clips audio locaux (remote non supporté)
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

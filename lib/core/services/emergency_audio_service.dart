import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class EmergencyAudioService {
  final AudioRecorder _recorder;

  EmergencyAudioService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  Future<String> recordClip({required int durationSec}) async {
    final safeDuration = durationSec.clamp(5, 600).toInt();

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw StateError(
        'Permission micro refusée. Activez-la dans les réglages.',
      );
    }

    if (!await _recorder.hasPermission()) {
      throw StateError('Le microphone est indisponible.');
    }

    final path = await _buildOutputPath();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    await Future.delayed(Duration(seconds: safeDuration));

    final resultPath = await _recorder.stop();
    if (resultPath == null || resultPath.trim().isEmpty) {
      throw StateError('Impossible de finaliser l\'enregistrement audio.');
    }

    return resultPath;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }

  Future<String> _buildOutputPath() async {
    final tempDir = await getTemporaryDirectory();
    final alertsDir = Directory('${tempDir.path}/safe_alerts');
    if (!alertsDir.existsSync()) {
      alertsDir.createSync(recursive: true);
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${alertsDir.path}/alert_$ts.m4a';
  }
}

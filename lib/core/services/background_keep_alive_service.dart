import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Service qui maintient l'app active en arrière-plan
/// en jouant un son silencieux en boucle.
/// 
/// Cela permet à la reconnaissance vocale de continuer
/// même quand l'écran est verrouillé.
class BackgroundKeepAliveService {
  static final BackgroundKeepAliveService _instance = BackgroundKeepAliveService._();
  static BackgroundKeepAliveService get instance => _instance;
  
  BackgroundKeepAliveService._();
  
  AudioPlayer? _silentPlayer;
  bool _isRunning = false;
  
  bool get isRunning => _isRunning;

  /// Démarre le son silencieux en boucle pour maintenir l'app active
  Future<void> start() async {
    if (_isRunning) return;
    
    try {
      _silentPlayer = AudioPlayer();
      
      // Créer une source audio silencieuse
      // On utilise un générateur de silence
      final silenceSource = SilenceAudioSource(
        duration: const Duration(seconds: 10),
      );
      
      // Configurer pour boucler indéfiniment
      await _silentPlayer!.setLoopMode(LoopMode.one);
      await _silentPlayer!.setVolume(0.01); // Volume quasi-inaudible
      await _silentPlayer!.setAudioSource(silenceSource);
      
      // Démarrer la lecture
      await _silentPlayer!.play();
      
      _isRunning = true;
      debugPrint('🔇 BackgroundKeepAlive: Son silencieux démarré');
    } catch (e) {
      debugPrint('❌ BackgroundKeepAlive: Erreur démarrage: $e');
      _isRunning = false;
    }
  }

  /// Arrête le son silencieux
  Future<void> stop() async {
    if (!_isRunning) return;
    
    try {
      await _silentPlayer?.stop();
      await _silentPlayer?.dispose();
      _silentPlayer = null;
      _isRunning = false;
      debugPrint('🔇 BackgroundKeepAlive: Arrêté');
    } catch (e) {
      debugPrint('❌ BackgroundKeepAlive: Erreur arrêt: $e');
    }
  }

  /// Libère les ressources
  Future<void> dispose() async {
    await stop();
  }
}

/// Source audio qui génère du silence
class SilenceAudioSource extends StreamAudioSource {
  final Duration duration;
  
  SilenceAudioSource({required this.duration});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // Générer des données audio silencieuses (WAV)
    final sampleRate = 44100;
    final channels = 1;
    final bitsPerSample = 16;
    final totalSamples = (sampleRate * duration.inSeconds).toInt();
    final dataSize = totalSamples * channels * (bitsPerSample ~/ 8);
    
    // En-tête WAV
    final header = _createWavHeader(
      dataSize: dataSize,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );
    
    // Données silencieuses (zéros)
    final silenceData = Uint8List(dataSize);
    
    // Combiner header + données
    final wavData = Uint8List(header.length + silenceData.length);
    wavData.setAll(0, header);
    wavData.setAll(header.length, silenceData);
    
    start ??= 0;
    end ??= wavData.length;
    
    return StreamAudioResponse(
      sourceLength: wavData.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(wavData.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
  
  Uint8List _createWavHeader({
    required int dataSize,
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    
    final header = ByteData(44);
    
    // "RIFF"
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    
    // File size - 8
    header.setUint32(4, 36 + dataSize, Endian.little);
    
    // "WAVE"
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    
    // "fmt "
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    
    // Subchunk1 size (16 for PCM)
    header.setUint32(16, 16, Endian.little);
    
    // Audio format (1 = PCM)
    header.setUint16(20, 1, Endian.little);
    
    // Number of channels
    header.setUint16(22, channels, Endian.little);
    
    // Sample rate
    header.setUint32(24, sampleRate, Endian.little);
    
    // Byte rate
    header.setUint32(28, byteRate, Endian.little);
    
    // Block align
    header.setUint16(32, blockAlign, Endian.little);
    
    // Bits per sample
    header.setUint16(34, bitsPerSample, Endian.little);
    
    // "data"
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    
    // Data size
    header.setUint32(40, dataSize, Endian.little);
    
    return header.buffer.asUint8List();
  }
}

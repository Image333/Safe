import 'dart:io';

import 'package:minio/io.dart';
import 'package:minio/minio.dart';

import '../config/api_config.dart';

/// Upload d'objets audio vers MinIO (S3-compatible).
class MinioUploadService {
  Minio? _client;

  Minio get _minio {
    return _client ??= Minio(
      endPoint: ApiConfig.minioHost,
      port: ApiConfig.minioPort,
      accessKey: ApiConfig.minioAccessKey,
      secretKey: ApiConfig.minioSecretKey,
      useSSL: false,
    );
  }

  /// Upload un fichier local et retourne l'URL publique `blob_url`.
  Future<String> uploadAudioFile({
    required String localFilePath,
    required String objectKey,
  }) async {
    final file = File(localFilePath);
    if (!await file.exists()) {
      throw Exception('Fichier audio introuvable: $localFilePath');
    }

    const bucket = ApiConfig.minioBucket;
    if (!await _minio.bucketExists(bucket)) {
      await _minio.makeBucket(bucket);
    }

    await _minio.fPutObject(
      bucket,
      objectKey,
      localFilePath,
      metadata: {
        'Content-Type': 'audio/mp4',
      },
    );

    return '${ApiConfig.minioPublicBaseUrl}/$objectKey';
  }
}

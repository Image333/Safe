import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Modèle pour la réponse de login
class LoginResponse {
  final String message;
  final String token;

  LoginResponse({required this.message, required this.token});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: _asString(json['message']) ?? 'Connexion réussie',
      token: _asString(json['token']) ?? '',
    );
  }
}

/// Modèle pour la réponse de création d'utilisateur
class CreateUserResponse {
  final String message;
  final int userId;

  CreateUserResponse({required this.message, required this.userId});

  factory CreateUserResponse.fromJson(Map<String, dynamic> json) {
    return CreateUserResponse(
      message: _asString(json['message']) ?? 'Utilisateur créé',
      userId: _asInt(json['user_id']) ?? 0,
    );
  }
}

/// Métadonnées audio renvoyées par l'API
class RemoteAudioRecord {
  final int audioId;
  final String blobUrl;
  final int duration;
  final String format;
  final int alertId;
  final String? alertTimestamp;
  final String? alertStatus;

  RemoteAudioRecord({
    required this.audioId,
    required this.blobUrl,
    required this.duration,
    required this.format,
    required this.alertId,
    this.alertTimestamp,
    this.alertStatus,
  });

  factory RemoteAudioRecord.fromJson(Map<String, dynamic> json) {
    return RemoteAudioRecord(
      audioId: _asInt(json['audio_id']) ?? 0,
      blobUrl: ApiConfig.toPublicBlobUrl(_asString(json['blob_url']) ?? ''),
      duration: _asInt(json['duration']) ?? 0,
      format: _asString(json['format']) ?? 'm4a',
      alertId: _asInt(json['alert_id']) ?? 0,
      alertTimestamp: _asString(json['alert_timestamp']),
      alertStatus: _asString(json['alert_status']),
    );
  }
}

/// Réponse de création d'enregistrement audio
class CreateAudioResponse {
  final String message;
  final int audioId;

  CreateAudioResponse({required this.message, required this.audioId});

  factory CreateAudioResponse.fromJson(Map<String, dynamic> json) {
    return CreateAudioResponse(
      message: _asString(json['message']) ?? 'Enregistrement audio créé',
      audioId: _asInt(json['audio_id']) ?? 0,
    );
  }
}

/// Exception personnalisée pour les erreurs API
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

String? _asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Map) {
    return _asString(value['message']) ??
        _asString(value['error']) ??
        value.toString();
  }
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _extractErrorMessage(Map<String, dynamic> json, [String fallback = 'Requête invalide']) {
  return _asString(json['error']) ??
      _asString(json['message']) ??
      fallback;
}

/// Service de communication avec l'API backend
class ApiService {
  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Headers par défaut pour les requêtes
  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        'X-API-Key': ApiConfig.apiKeyApp,
      };

  /// Headers avec authentification JWT
  Map<String, String> _headersWithAuth(String token) => {
        ..._headers,
        'Authorization': 'Bearer $token',
      };

  /// Login - Authentification d'un utilisateur
  ///
  /// Endpoint: POST /login
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/login'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final json = _tryDecodeMap(response.body);

      if (response.statusCode == 200) {
        final result = LoginResponse.fromJson(json ?? {});
        if (result.token.isEmpty) {
          throw ApiException('Token manquant dans la réponse', response.statusCode);
        }
        return result;
      }

      throw ApiException(
        _extractErrorMessage(json ?? {}, _defaultErrorForStatus(response.statusCode)),
        response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Création d'un nouveau compte utilisateur
  ///
  /// Endpoint: POST /users
  Future<CreateUserResponse> createUser({
    required String email,
    required String password,
    required String firstname,
    required String name,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/users'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
          'firstname': firstname,
          'name': name,
        }),
      );

      final json = _tryDecodeMap(response.body);

      if (response.statusCode == 201) {
        final result = CreateUserResponse.fromJson(json ?? {});
        if (result.userId == 0) {
          throw ApiException('ID utilisateur manquant dans la réponse', response.statusCode);
        }
        return result;
      }

      throw ApiException(
        _extractErrorMessage(json ?? {}, _defaultErrorForStatus(response.statusCode)),
        response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Attache un enregistrement audio à une alerte
  ///
  /// Endpoint: POST /alerts/:alertId/audio
  Future<CreateAudioResponse> createAudio({
    required String token,
    required int alertId,
    required String blobUrl,
    required int duration,
    required String format,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/alerts/$alertId/audio'),
        headers: _headersWithAuth(token),
        body: jsonEncode({
          'blob_url': blobUrl,
          'duration': duration,
          'format': format,
        }),
      );

      final json = _tryDecodeMap(response.body);

      if (response.statusCode == 201) {
        return CreateAudioResponse.fromJson(json ?? {});
      }

      throw ApiException(
        _extractErrorMessage(json ?? {}, _defaultErrorForStatus(response.statusCode)),
        response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Liste les enregistrements audio de l'utilisateur connecté
  ///
  /// Endpoint: GET /me/audio
  Future<List<RemoteAudioRecord>> getMyAudio({required String token}) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/me/audio'),
        headers: _headersWithAuth(token),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) return [];
        return decoded
            .whereType<Map>()
            .map((e) => RemoteAudioRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      final json = _tryDecodeMap(response.body);
      throw ApiException(
        _extractErrorMessage(json ?? {}, _defaultErrorForStatus(response.statusCode)),
        response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur de connexion: ${e.toString()}');
    }
  }

  Map<String, dynamic>? _tryDecodeMap(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  String _defaultErrorForStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Requête invalide';
      case 401:
        return 'Non autorisé';
      case 403:
        return 'Accès refusé';
      case 404:
        return 'Ressource introuvable';
      case 409:
        return 'Conflit (email déjà utilisé ?)';
      default:
        return 'Erreur serveur ($statusCode)';
    }
  }

  /// Ferme le client HTTP
  void dispose() {
    _client.close();
  }
}

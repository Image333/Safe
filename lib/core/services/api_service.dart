import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../storage/trusted_contacts_storage.dart';

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

/// Résultat de notification d'un contact lors d'une alerte
class AlertNotifyResult {
  final int contactId;
  final String contactName;
  final String status; // sent | not_linked | error
  final String? channel;
  final String? error;

  AlertNotifyResult({
    required this.contactId,
    required this.contactName,
    required this.status,
    this.channel,
    this.error,
  });

  factory AlertNotifyResult.fromJson(Map<String, dynamic> json) {
    return AlertNotifyResult(
      contactId: _asInt(json['contact_id']) ?? 0,
      contactName: _asString(json['contact_name']) ?? '',
      status: _asString(json['status']) ?? 'error',
      channel: _asString(json['channel']),
      error: _asString(json['error']),
    );
  }
}

/// Réponse de création d'alerte
class CreateAlertResponse {
  final String message;
  final int alertId;
  final List<AlertNotifyResult> notifications;

  CreateAlertResponse({
    required this.message,
    required this.alertId,
    required this.notifications,
  });

  factory CreateAlertResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['notifications'];
    final list = <AlertNotifyResult>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add(AlertNotifyResult.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return CreateAlertResponse(
      message: _asString(json['message']) ?? 'Alerte créée',
      alertId: _asInt(json['alert_id']) ?? 0,
      notifications: list,
    );
  }

  int get sentCount =>
      notifications.where((n) => n.status == 'sent').length;

  int get notLinkedCount =>
      notifications.where((n) => n.status == 'not_linked').length;
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

  /// Crée une alerte et notifie les contacts Telegram liés
  ///
  /// Endpoint: POST /alerts
  Future<CreateAlertResponse> createAlert({
    required String token,
    int? configId,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (configId != null && configId > 0) {
        body['config_id'] = configId;
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/alerts'),
        headers: _headersWithAuth(token),
        body: jsonEncode(body),
      );

      final json = _tryDecodeMap(response.body);

      if (response.statusCode == 201) {
        return CreateAlertResponse.fromJson(json ?? {});
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

  /// Liste les contacts de confiance
  ///
  /// Endpoint: GET /contacts
  Future<List<TrustedContact>> listContacts({required String token}) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/contacts'),
        headers: _headersWithAuth(token),
      );

      final json = _tryDecodeMap(response.body);
      if (response.statusCode == 200) {
        final data = json?['data'];
        if (data is! List) return [];
        return data
            .whereType<Map>()
            .map((e) => TrustedContact.fromApi(Map<String, dynamic>.from(e)))
            .toList();
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

  /// Crée un contact de confiance
  ///
  /// Endpoint: POST /contacts
  Future<TrustedContact> createContact({
    required String token,
    required String contactName,
    required String phoneNumber,
    String? email,
  }) async {
    try {
      final body = <String, dynamic>{
        'contact_name': contactName,
        'phone_number': phoneNumber,
      };
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/contacts'),
        headers: _headersWithAuth(token),
        body: jsonEncode(body),
      );

      final json = _tryDecodeMap(response.body);
      if (response.statusCode == 201) {
        final data = json?['data'];
        if (data is Map) {
          return TrustedContact.fromApi(Map<String, dynamic>.from(data));
        }
        throw ApiException('Réponse contact invalide', response.statusCode);
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

  /// Récupère un contact
  ///
  /// Endpoint: GET /contacts/:id
  Future<TrustedContact> getContact({
    required String token,
    required int contactId,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/contacts/$contactId'),
        headers: _headersWithAuth(token),
      );

      final json = _tryDecodeMap(response.body);
      if (response.statusCode == 200 && json != null) {
        return TrustedContact.fromApi(json);
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

  /// Supprime un contact
  ///
  /// Endpoint: DELETE /contacts/:id
  Future<void> deleteContact({
    required String token,
    required int contactId,
  }) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/contacts/$contactId'),
        headers: _headersWithAuth(token),
      );

      if (response.statusCode == 200) return;

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

  /// Stub : envoi d'invitation par email (501 pour l'instant)
  ///
  /// Endpoint: POST /contacts/:id/invite/email
  Future<void> inviteContactByEmail({
    required String token,
    required int contactId,
    String? email,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/contacts/$contactId/invite/email'),
        headers: _headersWithAuth(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) return;

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
      case 501:
        return 'Fonctionnalité non encore disponible';
      default:
        return 'Erreur serveur ($statusCode)';
    }
  }

  /// Ferme le client HTTP
  void dispose() {
    _client.close();
  }
}

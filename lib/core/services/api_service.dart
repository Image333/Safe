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

  /// Headers avec authentification
  // ignore: unused_element
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

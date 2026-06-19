import 'dart:convert';
import 'package:http/http.dart' as http;

/// Modèle pour la réponse de login
class LoginResponse {
  final String message;
  final String token;

  LoginResponse({required this.message, required this.token});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: json['message'] as String,
      token: json['token'] as String,
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
      message: json['message'] as String,
      userId: json['user_id'] as int,
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

/// Service de communication avec l'API backend
class ApiService {
  // URL de base de l'API - À adapter selon votre environnement
  // En développement local : http://localhost:8080
  // En production : https://votre-api.com
  static const String _baseUrl = 'http://localhost:8080/api/v1';
  
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Headers par défaut pour les requêtes
  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
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
  /// 
  /// Paramètres:
  /// - [email]: Adresse email de l'utilisateur
  /// - [password]: Mot de passe de l'utilisateur
  /// 
  /// Retourne un [LoginResponse] contenant le token JWT
  /// 
  /// Lève une [ApiException] en cas d'erreur
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

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return LoginResponse.fromJson(json);
      } else if (response.statusCode == 401) {
        throw ApiException('Identifiants invalides', response.statusCode);
      } else if (response.statusCode == 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(
          json['error'] as String? ?? 'Requête invalide',
          response.statusCode,
        );
      } else {
        throw ApiException(
          'Erreur serveur (${response.statusCode})',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Création d'un nouveau compte utilisateur
  /// 
  /// Endpoint: POST /users
  /// 
  /// Paramètres:
  /// - [email]: Adresse email de l'utilisateur
  /// - [password]: Mot de passe de l'utilisateur
  /// - [firstname]: Prénom de l'utilisateur
  /// - [name]: Nom de l'utilisateur
  /// 
  /// Retourne un [CreateUserResponse] contenant l'ID du nouvel utilisateur
  /// 
  /// Lève une [ApiException] en cas d'erreur
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

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return CreateUserResponse.fromJson(json);
      } else if (response.statusCode == 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(
          json['error'] as String? ?? 'Requête invalide',
          response.statusCode,
        );
      } else {
        throw ApiException(
          'Erreur serveur (${response.statusCode})',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Ferme le client HTTP
  void dispose() {
    _client.close();
  }
}

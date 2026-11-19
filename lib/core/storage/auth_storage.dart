import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service de stockage sécurisé pour les données d'authentification
class AuthStorage {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'user_email';

  final FlutterSecureStorage _storage;

  AuthStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Sauvegarde le token JWT
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Récupère le token JWT
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Sauvegarde l'ID utilisateur
  Future<void> saveUserId(int userId) async {
    await _storage.write(key: _userIdKey, value: userId.toString());
  }

  /// Récupère l'ID utilisateur
  Future<int?> getUserId() async {
    final value = await _storage.read(key: _userIdKey);
    return value != null ? int.tryParse(value) : null;
  }

  /// Sauvegarde l'email utilisateur
  Future<void> saveEmail(String email) async {
    await _storage.write(key: _emailKey, value: email);
  }

  /// Récupère l'email utilisateur
  Future<String?> getEmail() async {
    return await _storage.read(key: _emailKey);
  }

  /// Vérifie si l'utilisateur est authentifié
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Supprime toutes les données d'authentification
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _emailKey),
    ]);
  }

  /// Supprime tout le storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

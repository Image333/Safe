import 'api_service.dart';
import '../storage/auth_storage.dart';

/// Service d'authentification gérant le login, la création de compte et la session
class AuthService {
  final ApiService _apiService;
  final AuthStorage _authStorage;

  AuthService({
    ApiService? apiService,
    AuthStorage? authStorage,
  })  : _apiService = apiService ?? ApiService(),
        _authStorage = authStorage ?? AuthStorage();

  /// Vérifie si l'utilisateur est connecté
  Future<bool> isAuthenticated() async {
    return await _authStorage.hasToken();
  }

  /// Récupère le token d'authentification actuel
  Future<String?> getToken() async {
    return await _authStorage.getToken();
  }

  /// Récupère l'email de l'utilisateur connecté
  Future<String?> getCurrentUserEmail() async {
    return await _authStorage.getEmail();
  }

  /// Récupère l'ID de l'utilisateur connecté
  Future<int?> getCurrentUserId() async {
    return await _authStorage.getUserId();
  }

  /// Connexion d'un utilisateur existant
  /// 
  /// Paramètres:
  /// - [email]: Email de l'utilisateur
  /// - [password]: Mot de passe de l'utilisateur
  /// 
  /// Retourne true si la connexion est réussie
  /// 
  /// Lève une [ApiException] en cas d'erreur
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    // Appel à l'API
    final response = await _apiService.login(
      email: email,
      password: password,
    );

    // Sauvegarde du token et de l'email
    await Future.wait([
      _authStorage.saveToken(response.token),
      _authStorage.saveEmail(email),
    ]);

    return true;
  }

  /// Création d'un nouveau compte utilisateur et connexion automatique
  /// 
  /// Paramètres:
  /// - [email]: Email du nouvel utilisateur
  /// - [password]: Mot de passe du nouvel utilisateur
  /// - [firstname]: Prénom du nouvel utilisateur
  /// - [name]: Nom du nouvel utilisateur
  /// 
  /// Retourne true si la création et la connexion sont réussies
  /// 
  /// Lève une [ApiException] en cas d'erreur
  Future<bool> register({
    required String email,
    required String password,
    required String firstname,
    required String name,
  }) async {
    // 1. Créer le compte
    final createResponse = await _apiService.createUser(
      email: email,
      password: password,
      firstname: firstname,
      name: name,
    );

    // 2. Sauvegarder l'ID utilisateur
    await _authStorage.saveUserId(createResponse.userId);

    // 3. Se connecter automatiquement après la création
    final loginResponse = await _apiService.login(
      email: email,
      password: password,
    );

    // 4. Sauvegarder le token et l'email
    await Future.wait([
      _authStorage.saveToken(loginResponse.token),
      _authStorage.saveEmail(email),
    ]);

    return true;
  }

  /// Déconnexion de l'utilisateur
  /// 
  /// Supprime toutes les données d'authentification du stockage local
  Future<void> logout() async {
    await _authStorage.clear();
  }

  /// Nettoie toutes les ressources
  void dispose() {
    _apiService.dispose();
  }
}

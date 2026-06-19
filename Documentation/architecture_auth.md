# Architecture d'authentification

## Vue d'ensemble

L'application Flutter Safe est connectée au backend API Go pour gérer l'authentification des utilisateurs (login et création de compte). Cette documentation décrit l'architecture mise en place.

## Structure des composants

### Backend (Go)

**Endpoint Base**: `http://localhost:8080/api/v1`

**Routes disponibles**:
- `POST /login` - Authentification utilisateur
- `POST /users` - Création de compte utilisateur

**Fichier**: `backend/api/routes/users.go`

Le backend utilise:
- Bcrypt pour le hashage des mots de passe
- JWT (HS256) pour les tokens d'authentification avec expiration 24h
- MariaDB pour le stockage des utilisateurs

### Frontend (Flutter)

#### Couche Service

**1. ApiService** (`lib/core/services/api_service.dart`)

Client HTTP responsable de la communication avec le backend.

Méthodes principales:
```dart
Future<LoginResponse> login({required String email, required String password})
Future<CreateUserResponse> createUser({required String email, required String password, required String firstname, required String name})
```

Gestion des erreurs via `ApiException` qui encapsule les codes HTTP et messages d'erreur.

**2. AuthService** (`lib/core/services/auth_service.dart`)

Service de haut niveau orchestrant l'authentification.

Méthodes principales:
```dart
Future<bool> login({required String email, required String password})
Future<bool> register({required String email, required String password, required String firstname, required String name})
Future<void> logout()
Future<bool> isAuthenticated()
Future<String?> getCurrentUserEmail()
Future<int?> getCurrentUserId()
```

Ce service coordonne les appels API et la persistance des données d'authentification.

#### Couche Stockage

**AuthStorage** (`lib/core/storage/auth_storage.dart`)

Gère le stockage sécurisé des données d'authentification via `flutter_secure_storage`.

Données stockées:
- Token JWT
- User ID
- Email utilisateur

Méthodes principales:
```dart
Future<void> saveToken(String token)
Future<String?> getToken()
Future<void> saveUserId(int userId)
Future<int?> getUserId()
Future<void> saveEmail(String email)
Future<String?> getEmail()
Future<bool> hasToken()
Future<void> clear()
```

#### Couche UI

**AuthBottomSheet** (`lib/features/settings/auth_bottom_sheet.dart`)

Interface utilisateur pour l'authentification avec deux modes:

**Mode Login**:
- Email
- Mot de passe

**Mode Register**:
- Nom
- Prénom
- Email
- Mot de passe
- Confirmation mot de passe

Le formulaire valide les champs et affiche les erreurs de manière contextuelle.

## Flux de données

### Création de compte

```
1. User input → AuthBottomSheet
2. Validation formulaire
3. AuthService.register(email, password, firstname, name)
4. ApiService.createUser() → POST /api/v1/users
5. Backend: Hash password + Insert DB → Response {user_id}
6. AuthService.login() (connexion automatique)
7. ApiService.login() → POST /api/v1/login
8. Backend: Verify + Generate JWT → Response {token}
9. AuthStorage.saveToken() + saveEmail()
10. Utilisateur connecté
```

### Connexion

```
1. User input → AuthBottomSheet
2. Validation formulaire
3. AuthService.login(email, password)
4. ApiService.login() → POST /api/v1/login
5. Backend: Verify password + Generate JWT → Response {token}
6. AuthStorage.saveToken() + saveEmail()
7. Utilisateur connecté
```

### Déconnexion

```
1. AuthService.logout()
2. AuthStorage.clear()
3. Suppression du token local
```

## Modèles de données

### LoginRequest
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

### LoginResponse
```json
{
  "message": "Connexion réussie",
  "token": "eyJhbGc..."
}
```

### CreateUserRequest
```json
{
  "name": "Doe",
  "firstname": "John",
  "email": "user@example.com",
  "password": "password123"
}
```

### CreateUserResponse
```json
{
  "message": "Utilisateur créé avec succès",
  "user_id": 42
}
```

## Gestion des erreurs

### Côté API

L'`ApiService` capture les réponses HTTP et les convertit en `ApiException`:

- **400 Bad Request**: Format invalide ou champs manquants
- **401 Unauthorized**: Identifiants invalides
- **500 Internal Server Error**: Erreur serveur

### Côté UI

L'`AuthBottomSheet` capture les exceptions et affiche des messages d'erreur contextuels à l'utilisateur.

## Sécurité

### Backend
- Mots de passe hashés avec bcrypt (DefaultCost)
- Tokens JWT signés avec HS256
- Expiration des tokens après 24h

### Frontend
- Stockage chiffré via `flutter_secure_storage`
- Pas de stockage en clair des credentials
- Communication HTTPS recommandée en production

## Configuration

### URL de l'API

Dans `lib/core/services/api_service.dart`:

```dart
static const String _baseUrl = 'http://localhost:8080/api/v1';
```

Ajuster selon l'environnement:
- **Développement local**: `http://localhost:8080/api/v1`
- **Émulateur Android**: `http://10.0.2.2:8080/api/v1`
- **Production**: `https://api.votre-domaine.com/api/v1`

### Secret JWT

Dans `backend/api/routes/users.go`:

```go
var jwtSecret = []byte("mon_super_secret_gpe_2026")
```

À modifier en production avec une variable d'environnement.

## Tests

### Démarrage du backend

```bash
cd backend/api
go run main.go
```

### Port-forward base de données (Kubernetes)

```bash
kubectl port-forward svc/my-mariadb -n gpe 3306:3306
```

### Lancement de l'application

```bash
flutter pub get
flutter run
```

### Scénarios de test

1. Créer un compte avec nom, prénom, email, mot de passe valide
2. Vérifier que l'utilisateur est automatiquement connecté après création
3. Se déconnecter puis se reconnecter avec les mêmes identifiants
4. Tester avec des identifiants invalides pour vérifier les messages d'erreur
5. Tester la validation des champs (email invalide, mot de passe trop court, etc.)

## Dépendances

### Frontend

- `http: ^1.2.0` - Client HTTP
- `flutter_secure_storage: ^9.0.0` - Stockage sécurisé
- `flutter_riverpod: ^2.5.1` - State management (existant)

### Backend

- `github.com/gofiber/fiber/v2` - Framework web
- `github.com/golang-jwt/jwt/v5` - JWT
- `golang.org/x/crypto/bcrypt` - Hash passwords
- `github.com/go-sql-driver/mysql` - Driver MySQL

## Évolutions futures

- Implémentation du reset de mot de passe
- Refresh token pour prolonger les sessions
- Middleware d'authentification pour les routes protégées
- Synchronisation des données utilisateur (contacts, configuration)
- Tests unitaires et d'intégration
- Déconnexion automatique à l'expiration du token

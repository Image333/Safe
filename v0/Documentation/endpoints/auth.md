
## Endpoints du module Auth

| Méthode | Endpoint          | Description                                   |
|---------|-------------------|-----------------------------------------------|
| POST    | `/api/auth/signup`| Inscrit un nouvel utilisateur et retourne un token |
| POST    | `/api/auth/login` | Authentifie un utilisateur et retourne un token|
| GET     | `/api/auth/me`    | Récupère les informations de l'utilisateur connecté (protégé) |

Le module `auth` gère la création de compte, l'authentification et la récupération du profil via JWT. Les requêtes acceptent du JSON ; les réponses renvoient un `token` et/ou un objet `user`.

Schema `User` (extrait)

```json
{
	"id": 8,
	"name": "Doe",
	"firstname": "John",
	"email": "john@example.com",
	"registration_date": "2025-11-12 11:09:03"
}
```

POST /api/auth/signup

- Description: crée un utilisateur et retourne un JWT
- Request body (JSON):

```json
{
	"name": "Doe",
	"firstname": "John",
	"email": "john@example.com",
	"password": "Azerty123!"
}
```

- Exemple curl:

```bash
curl -X POST http://localhost:3002/api/auth/signup \
	-H 'Content-Type: application/json' \
	-d '{"name":"Doe","firstname":"John","email":"john@example.com","password":"Azerty123!"}'
```

- Réponse (201):

```json
{
	"token": "<jwt>",
	"user": { 
        "UserID": "int",
	    "Name": "string",
	    "Firstname" : "string",
	    "Email" : "string",
	    "RegistrationDate" : "string"
    }
}
```

- Erreurs possibles:

| Code | Cause possible | Message clé |
|------|----------------|-------------|
| 400  | Body invalide / champs manquants | `invalid_json` / `missing_fields` |
| 409  | Email déjà utilisé | `email_already_exists` |
| 500  | Erreur interne | `db_insert_error` / `jwt_error` |

POST /api/auth/login

- Description: vérifie les identifiants et retourne un JWT
- Request body (JSON):

```json
{ "email": "john@example.com", "password": "Azerty123!" }
```

- Exemple curl:

```bash
curl -X POST http://localhost:3002/api/auth/login \
	-H 'Content-Type: application/json' \
	-d '{"email":"john@example.com","password":"Azerty123!"}'
```

- Réponse (200):

```json
{
	"token": "<jwt>",
	"user": { 
        "UserID": "int",
	    "Name": "string",
	    "Firstname" : "string",
	    "Email" : "string",
	    "RegistrationDate" : "string"
    }
}
```

- Erreurs possibles:

| Code | Cause possible | Message clé |
|------|----------------|-------------|
| 400  | Body invalide | `invalid_json` / `missing_fields` |
| 401  | Identifiants incorrects | `invalid_credentials` |
| 500  | Erreur interne | `db_query_error` / `jwt_error` |

GET /api/auth/me

- Description: retourne l'utilisateur authentifié
- Header: `Authorization: Bearer <token>`
- Exemple curl:

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:3002/api/auth/me
```

- Réponse (200): `User` (sans mot de passe)
- Erreurs possibles: `401` (missing/invalid token), `404` (user not found), `500`.

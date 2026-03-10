
## Endpoints du module Users

| Méthode | Endpoint            | Description                               |
|---------|---------------------|-------------------------------------------|
| GET     | `/api/users/`       | Liste les utilisateurs                    |
| GET     | `/api/users/:id`    | Récupère un utilisateur par ID            |
| POST    | `/api/users/`       | Crée un utilisateur                       |
| PUT     | `/api/users/:id`    | Met à jour un utilisateur                 |
| DELETE  | `/api/users/:id`    | Supprime un utilisateur                   |

Payload (création / update):

```json
{
  "name": "Doe",
  "firstname": "John",
  "email": "john@example.com",
  "password": "Azerty123!"  
}
```

GET /api/users/

- Description: retourne la liste des utilisateurs
- Exemple curl:

```bash
curl http://localhost:3002/api/users/
```

- Réponse (200):

```json
{ "count": 2, "data": [ { /* User */ }, { /* User */ } ] }
```

GET /api/users/:id

- Exemple curl:

```bash
curl http://localhost:3002/api/users/8
```

- Réponse (200): `User` ou `404` si non trouvé.

POST /api/users/

- Crée un utilisateur (similar to signup but without token)
- Exemple curl:

```bash
curl -X POST http://localhost:3002/api/users/ \
  -H 'Content-Type: application/json' \
  -d '{"name":"Doe","firstname":"John","email":"john@example.com","password":"Azerty123!"}'
```

- Réponse (201): `User` (sans champ `password`).

PUT /api/users/:id

- Met à jour un utilisateur. Si `password` fourni, il sera hashé.
- Exemple curl:

```bash
curl -X PUT http://localhost:3002/api/users/8 \
  -H 'Content-Type: application/json' \
  -d '{"name":"Doe","firstname":"John","email":"john2@example.com"}'
```

- Réponse (200): `User` mis à jour.

DELETE /api/users/:id

- Exemple curl:

```bash
curl -X DELETE http://localhost:3002/api/users/8
```

- Réponse: `204` si supprimé, `404` si non trouvé.

Erreurs communes:

| Code | Cause | Clé d'erreur |
|------|-------|--------------|
| 400  | Body invalide / id invalide | `invalid_json` / `invalid_id` |
| 409  | Email déjà utilisé | `email_already_exists` |
| 404  | Ressource non trouvée | `user_not_found` |
| 500  | Erreur serveur | `db_*` |


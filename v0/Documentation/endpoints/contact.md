## Endpoints du module Contact

| Méthode | Endpoint             | Description                             |
|---------|----------------------|-----------------------------------------|
| GET     | `/api/contact/`      | Liste les contacts                      |
| POST    | `/api/contact/`      | Crée un contact (protégé)               |
| DELETE  | `/api/contact/:id`   | Supprime un contact (protégé)           |
---


Création d'un contact (POST `/api/contact/`)

- Protégé: header `Authorization: Bearer <token>` requis.
- Body (JSON) typique:

```json
{
  "email": "contact@example.com",
  "contact_name": "Alice",
  "phone_number": "+33123456789",
  "contact_type": "friend",
  "priority_order": 1
}
```

- Exemple curl:

```bash
curl -X POST http://localhost:3002/api/contact/ \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"email":"contact@example.com","contact_name":"Alice","phone_number":"+33123456789","contact_type":"friend","priority_order":1}'
```

- Le serveur utilise l'email extrait du token pour remplir `user_ref`.
- Réponse (200): objet `Contact` créé (exemple):

```json
{
  "id": 12,
  "email": "contact@example.com",
  "user_ref": "john@example.com",
  "contact_name": "Alice",
  "phone_number": "+33123456789",
  "contact_type": "friend",
  "priority_order": 1
}
```

- Erreurs possibles:

| Code | Cause | Clé d'erreur |
|------|-------|--------------|
| 400  | Champs manquants / JSON invalide | `missing_fields` / `invalid_json` |
| 401  | Token absent / invalide | `unauthorized` / `invalid_token` |
| 500  | Erreur DB | `db_insert_error` |

DELETE /api/contact/:id

- Exemple curl:

```bash
curl -X DELETE http://localhost:3002/api/contact/12 \
  -H "Authorization: Bearer $TOKEN"
```

- Réponse: `204` si supprimé, `404` si non trouvé.


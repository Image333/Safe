
## Endpoint Hello

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET     | `/`      | Route de test renvoyant `Hello, World!` |

Utilisée pour vérifier que le serveur est correctement démarré et que le routeur est chargé.

Exemple curl:

```bash
curl http://localhost:3002/
```

Réponse: `200` et corps texte `Hello, World!`.


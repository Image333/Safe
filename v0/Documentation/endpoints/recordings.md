## Endpoints du module Recordings (audio)

| Méthode | Endpoint                | Description                               |
|---------|-------------------------|-------------------------------------------|
| POST    | `/api/recordings/`      | Upload d'un fichier audio (protégé)
---


POST `/api/recordings/`

- Protégé: header `Authorization: Bearer <token>` requis.
- Multipart form field: `file` (fichier audio). Le champ attendu est `file`.
- Limites & règles:
  - Taille maximale : 50 MB
  - Extensions acceptées : `.wav`, `.mp3`, `.m4a`, `.aac`, `.3gp`, `.caf`
  - Fichiers stockés sous `./data/app/Enregistrement/` avec nom robuste `<userId>_<timestamp>_<safeBase>.<ext>`.

- Exemple curl (multipart):

```bash
curl -X POST http://localhost:3002/api/recordings/ \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/recording.wav"
```

- Réponse (201):

```json
{
  "filename": "8_2025-12-15T123456Z_audio.wav",
  "path": "./data/app/Enregistrement/8_2025-12-15T123456Z_audio.wav",
  "size": 12345
}
```

- Erreurs possibles:

| Code | Cause | Clé d'erreur |
|------|-------|--------------|
| 400  | Fichier absent / extension non supportée | `file_required` / `unsupported_extension` |
| 401  | Token manquant/invalide | `unauthorized` |
| 413  | Fichier trop volumineux | `file_too_large` |
| 500  | Erreur d'écriture / filesystem | `write_error` / `create_error` |

Sécurité & exploitation:

- Vérifier quotas et espace disque avant upload en production.
- Considérer chiffrer ou déplacer les enregistrements vers un stockage objet (S3) si volumétrie élevée ou données sensibles.


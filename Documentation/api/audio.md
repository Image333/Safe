# Audio documentation section

> **Base path:** `/api/v1` — see [API Base Path](./api.md).

Key points :

- [Attach audio to alert](#attach-audio-to-alert)
- [List my audio](#list-my-audio)

> **Note:** All audio endpoints are **protected** (JWT). L’alerte cible doit appartenir à l’utilisateur du JWT (`403` sinon).

> See: **[JWT Authentication](./users.md#authentication---user-login)** · **[Architecture Telegram](../architecture_telegram_alerts.md)**

Le fichier binaire n’est **pas** uploadé via cette API. L’app envoie d’abord le clip sur **MinIO** (S3), puis enregistre l’URL (`blob_url`) ici. Le backend télécharge cette URL et envoie le média aux contacts Telegram liés (`sendAudio`).

---

# Attach audio to alert

## Endpoint

```http
POST /alerts/:id/audio
```

Crée un enregistrement dans `audio_records` lié à l’alerte `:id`, puis fan-out Telegram asynchrone (`SendAudio`).

### Path params

| Param | Type    | Description   |
| ----- | ------- | ------------- |
| id    | integer | `alert_id`    |

### Request Body

| Field    | Type    | Required | Description                                      |
| -------- | ------- | -------- | ------------------------------------------------ |
| blob_url | string  | Yes      | URL publique MinIO du fichier (ex. `.m4a`)       |
| duration | integer | No       | Durée en secondes (défaut `1` si ≤ 0)            |
| format   | string  | No       | Extension / format (défaut `m4a`)                |

### Example

```json
{
  "blob_url": "http://82.65.130.61:30900/audio-bucket/1/alert_1710000000.m4a",
  "duration": 15,
  "format": "m4a"
}
```

### Successful Response — `201 Created`

```json
{
  "message": "Enregistrement audio créé",
  "audio_id": 12
}
```

### Errors

| Status | Cause |
| ------ | ----- |
| `400`  | JSON invalide, `blob_url` vide, `alert_id` invalide |
| `401`  | JWT manquant / invalide |
| `403`  | Alerte d’un autre utilisateur |
| `404`  | Alerte introuvable |
| `409`  | Un audio est déjà lié à cette alerte |

### Telegram

Après insert, le backend appelle `notifyTrustedContactsAudio` : pour chaque contact avec `telegram_chat_id`, `telegram.Service.SendAudio` télécharge `blob_url` puis `POST` multipart vers Bot API `sendAudio`.

Si MinIO (port S3, ex. `:30900`) est injoignable depuis le téléphone **ou** depuis le serveur API, cet endpoint n’est jamais appelé / `SendAudio` échoue — le message texte d’alerte peut quand même avoir été envoyé.

### Flutter

1. `createAlert` → `POST /alerts` (texte Telegram + promesse d’audio).
2. Enregistrement local du clip.
3. `MinioUploadService.uploadAudioFile` → URL publique.
4. `ApiService.createAudio` → `POST /alerts/:id/audio`.

Même enchaînement depuis `HomeScreen._triggerAlert` et `VoiceTriggerService` (création d’alerte avant sync).

---

# List my audio

## Endpoint

```http
GET /me/audio
```

Liste les clips de l’utilisateur authentifié (jointure `audio_records` ↔ `alerts`).

### Successful Response — `200 OK`

```json
[
  {
    "audio_id": 12,
    "blob_url": "http://82.65.130.61:30900/audio-bucket/1/alert_1710000000.m4a",
    "duration": 15,
    "format": "m4a",
    "alert_id": 7,
    "alert_status": "TRIGGERED",
    "alert_timestamp": "2026-10-07 12:00:00"
  }
]
```

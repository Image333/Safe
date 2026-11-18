# Architecture — Alertes Telegram aux proches

## Objectif

Quand l’utilisateur déclenche une alerte (SOS, Volume +, mot-clé vocal), les **contacts de confiance déjà liés** reçoivent un message texte via un **bot Telegram**, côté serveur — puis, dès que le clip est uploadé sur MinIO, le **fichier audio** via `sendAudio`.

## Contrainte Bot API

La [Bot API Telegram](https://core.telegram.org/bots/api) **ne permet pas** de retrouver un utilisateur à partir d’un téléphone ou d’un email.

Un bot ne peut écrire qu’après un opt-in : le proche doit ouvrir un lien deep-link et faire `/start` (éventuellement avec un token d’invitation).

## Flux

```text
App SAFE                         Backend Go                      Telegram
   |                                  |                              |
   | POST /contacts (phone requis)    |                              |
   |--------------------------------->| génère invite_token          |
   |<---------------------------------| invite_link                  |
   | Copier le lien → partage manuel  |                              |
   |                                  |                              |
   |                                  |   proche ouvre t.me/Bot?start=token
   |                                  |<-----------------------------|
   |                                  | webhook /start → chat_id     |
   |                                  |                              |
   | POST /alerts                     |                              |
   |--------------------------------->| sendMessage(chat_id) ------->|
   |                                  |  (texte + « audio à suivre ») |
   |                                  |                              |
   | upload clip → MinIO (S3 :30900)  |                              |
   | POST /alerts/:id/audio           |                              |
   |--------------------------------->| SendAudio(blob_url) -------->|
```

### Invitation (MVP)

1. Création / sync du contact → l’API renvoie `invite_link`.
2. L’app propose **Copier le lien** (sheet d’invitation).
3. L’envoi par email est **préparé** (`POST /contacts/:id/invite/email` → `501`) mais pas encore branché SMTP.

### Indicateur dans l’app

Sur l’écran Contacts :

- badge **À inviter** si `telegram_linked = false`
- badge **Telegram lié** si le webhook a enregistré un `telegram_chat_id`
- pull-to-refresh pour recharger le statut depuis l’API

### Alerte runtime

1. `_triggerAlert` / voice trigger → `POST /api/v1/alerts` (JWT) avec optionnellement `latitude`, `longitude`, `trigger` (`sos` | `volume` | `voice`).
2. INSERT de l’alerte (statut `PENDING`) et, si coords valides, de `geolocations` (1:1, pas de route dédiée) dans une même transaction.
3. Le backend fan-out `sendMessage` (texte enrichi : urgence, heure Paris, type de déclenchement, lien Maps si GPS) puis `sendLocation` (pin natif) si coords présentes.
4. Réponse : `notifications[]` avec `status` = `sent` | `not_linked` | `error`.
5. L’UI affiche un feedback réel (plus de faux « contacts alertés »).
6. Enregistrement local → upload MinIO → `POST /api/v1/alerts/:id/audio`.
7. Le backend lit les contacts liés, répond, puis un pool de workers borné télécharge `blob_url` une seule fois (`FetchAudio`) et l’envoie à chaque contact (`SendAudioFile`, 3 tentatives).

### Dépendance MinIO

| Port / service | Rôle | Requis pour |
|----------------|------|-------------|
| API SAFE (`:30001` cluster / `:8080` local) | JWT, alertes, contacts | Texte Telegram |
| MariaDB (interne cluster) | Users, contacts, `audio_records` | Persistance |
| MinIO S3 (`:30900` NodePort) | Stockage objets audio | Upload + `FetchAudio` |
| MinIO Console (`:30901`) | UI admin | **Pas** utilisé par l’app |

Si l’API S3 MinIO est down / timeout, le texte Telegram part quand même ; l’audio ne sera jamais attaché ni renvoyé (pas de `POST .../audio`, table `audio_records` vide).

L’URL `blob_url` doit être joignable **depuis le serveur API** (c’est lui qui télécharge avant `sendAudio`, pas les serveurs Telegram directement) et commencer par un des préfixes de `TELEGRAM_AUDIO_ALLOWED_URLS` (protection SSRF : toute autre URL n’est jamais téléchargée).

## Composants

| Couche | Fichiers / rôle |
|--------|------------------|
| Backend | `backend/api/telegram` (`SendMessage`, `SendLocation`, `FetchAudio`, `SendAudioFile`), `routes/contacts.go`, `routes/telegram_webhook.go`, `routes/alert.go`, `routes/audio.go`, `routes/audio_notifier.go` |
| Flutter | `LocationService`, `TrustedContactsService`, `TelegramInviteSheet`, `_triggerAlert` / `AudioSyncService` / `MinioUploadService`, `VoiceTriggerService` |
| Config | `TELEGRAM_*` en variables d’environnement de l’API ; MinIO via `ApiConfig` / `--dart-define=MINIO_*` |

## Webhook

- Endpoint public : `POST /api/v1/telegram/webhook` (**sans JWT / X-API-Key**).
- Protégé par `TELEGRAM_WEBHOOK_SECRET` (header `X-Telegram-Bot-Api-Secret-Token`) — **obligatoire**.
- Doit être enregistré **avant** `ApiKeyMiddleware` / `ProtectedRoute` sur `/api/v1` (sinon Telegram reçoit `401`).
- En local : exposer l’API (ngrok) puis `setWebhook` avec `secret_token` vers `https://<host>/api/v1/telegram/webhook`.

### Liaison

1. `/start <invite_token>` → update `contacts.telegram_chat_id` **seulement si** encore `NULL`.
2. Sinon : clavier « Partager mon numéro » (`request_contact`) → accepter uniquement le propre numéro du sender, match parmi les contacts non liés.

## Hors scope MVP

- Envoi SMTP réel de l’invitation / de l’alerte
- Reverse geocoding / adresse textuelle
- Boutons inline Telegram / mise à jour live de position
- Lookup Telegram par téléphone/email (impossible via Bot API)
- Appel Bot API depuis Flutter (token serveur uniquement)

## Voir aussi

- [API Contacts](./api/endpoints/contacts.md)
- [API Alerts](./api/endpoints/alerts.md)
- [API Audio](./api/endpoints/audio.md)
- [API Telegram webhook](./api/endpoints/telegram.md)
- [Choix techno](./ChoixTechno.md)

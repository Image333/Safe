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

1. `_triggerAlert` / voice trigger → `POST /api/v1/alerts` (JWT).
2. Le backend fan-out `sendMessage` aux contacts liés (texte + mention qu’un enregistrement suivra).
3. Réponse : `notifications[]` avec `status` = `sent` | `not_linked` | `error`.
4. L’UI affiche un feedback réel (plus de faux « contacts alertés »).
5. Enregistrement local → upload MinIO → `POST /api/v1/alerts/:id/audio`.
6. Le backend fan-out `SendAudio` (télécharge `blob_url`, multipart Bot API) aux mêmes contacts liés.

### Dépendance MinIO

| Port / service | Rôle | Requis pour |
|----------------|------|-------------|
| API SAFE (`:30001` cluster / `:8080` local) | JWT, alertes, contacts | Texte Telegram |
| MariaDB (interne cluster) | Users, contacts, `audio_records` | Persistance |
| MinIO S3 (`:30900` NodePort) | Stockage objets audio | Upload + `SendAudio` |
| MinIO Console (`:30901`) | UI admin | **Pas** utilisé par l’app |

Si l’API S3 MinIO est down / timeout, le texte Telegram part quand même ; l’audio ne sera jamais attaché ni renvoyé (pas de `POST .../audio`, table `audio_records` vide).

L’URL `blob_url` doit être joignable **depuis le serveur API** (c’est lui qui télécharge avant `sendAudio`, pas les serveurs Telegram directement).

## Composants

| Couche | Fichiers / rôle |
|--------|------------------|
| Backend | `backend/api/telegram` (`SendMessage`, `SendAudio`), `routes/contacts.go`, `routes/telegram_webhook.go`, `routes/alert.go`, `routes/audio.go` |
| Flutter | `TrustedContactsService`, `TelegramInviteSheet`, `_triggerAlert` / `AudioSyncService` / `MinioUploadService`, `VoiceTriggerService` |
| Config | `TELEGRAM_*` via `.env` API ; MinIO via `ApiConfig` / `--dart-define=MINIO_*` |

## Webhook

- Endpoint public : `POST /api/v1/telegram/webhook` (**sans JWT**).
- Doit être enregistré **avant** le middleware `ProtectedRoute` du groupe `/api/v1` (sinon Telegram reçoit `401`).
- En local : exposer l’API (ngrok) puis `setWebhook` vers `https://<host>/api/v1/telegram/webhook`.

### Liaison

1. `/start <invite_token>` → update `contacts.telegram_chat_id`.
2. Sinon : clavier « Partager mon numéro » (`request_contact`) → match téléphone normalisé.

## Hors scope MVP

- Envoi SMTP réel de l’invitation / de l’alerte
- GPS dans le message
- Lookup Telegram par téléphone/email (impossible via Bot API)
- Appel Bot API depuis Flutter (token serveur uniquement)

## Voir aussi

- [API Contacts](./api/contacts.md)
- [API Alerts](./api/alerts.md)
- [API Audio](./api/audio.md)
- [API Telegram webhook](./api/telegram.md)
- [Choix techno](./ChoixTechno.md)

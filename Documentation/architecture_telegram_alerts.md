# Architecture — Alertes Telegram aux proches

## Objectif

Quand l’utilisateur déclenche une alerte (SOS, Volume +, mot-clé vocal), les **contacts de confiance déjà liés** reçoivent un message via un **bot Telegram**, côté serveur.

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

1. `_triggerAlert` → `POST /api/v1/alerts` (JWT).
2. Le backend fan-out `sendMessage` aux contacts liés.
3. Réponse : `notifications[]` avec `status` = `sent` | `not_linked` | `error`.
4. L’UI affiche un feedback réel (plus de faux « contacts alertés »).

## Composants

| Couche | Fichiers / rôle |
|--------|------------------|
| Backend | `backend/api/telegram`, `routes/contacts.go`, `routes/telegram_webhook.go`, `routes/alert.go` |
| Flutter | `TrustedContactsService`, `TelegramInviteSheet`, `_triggerAlert` dans `home_screen.dart` |
| Config | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_BOT_USERNAME`, `TELEGRAM_WEBHOOK_SECRET` (optionnel) via `.env` |

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
- [API Telegram webhook](./api/telegram.md)
- [Choix techno](./ChoixTechno.md)

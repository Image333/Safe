# Telegram webhook documentation

> **Base path:** `/api/v1` — see [API Base Path](./api.md).

Key points :

- [Webhook](#webhook)
- [setWebhook (ops)](#setwebhook-ops)
- [Environment](#environment)

> **Important:** cet endpoint est **public** (pas de JWT). Il doit rester enregistré **avant** le middleware `ProtectedRoute` du groupe `/api/v1`, sinon Telegram reçoit `401 Unauthorized` et aucun contact n’est lié.

Architecture : [architecture_telegram_alerts.md](../architecture_telegram_alerts.md).

---

# Webhook

## Endpoint

```http
POST /telegram/webhook
```

Reçoit les updates Bot API (`message`, `/start`, contact partagé).

### Optional secret

Si `TELEGRAM_WEBHOOK_SECRET` est défini, le header suivant est exigé :

```http
X-Telegram-Bot-Api-Secret-Token: <TELEGRAM_WEBHOOK_SECRET>
```

Sinon le secret n’est pas vérifié.

### Comportement

| Event | Action |
|-------|--------|
| `/start <invite_token>` | Associe `telegram_chat_id` au contact ayant ce `invite_token` ; message de confirmation |
| `/start` sans token valide | Propose le clavier « Partager mon numéro » |
| Message avec `contact` (request_contact) | Match le téléphone normalisé (digits / 9 derniers) puis lie le `chat_id` |

Réponse HTTP : toujours `200` vers Telegram après traitement (pour éviter les retries inutiles), même si le token est inconnu.

---

# setWebhook (ops)

Après démarrage de l’API (et tunnel public en local, ex. ngrok) :

```bash
curl "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/setWebhook" \
  -d "url=https://<PUBLIC_HOST>/api/v1/telegram/webhook"
```

Vérifier :

```bash
curl "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/getWebhookInfo"
```

Champs utiles de `getWebhookInfo` :

- `url` — doit pointer vers votre webhook
- `last_error_message` — ex. `401 Unauthorized` = middleware JWT encore devant le webhook
- `pending_update_count` — updates en attente

---

# Environment

| Variable | Required | Description |
|----------|----------|-------------|
| `TELEGRAM_BOT_TOKEN` | Yes (pour envoi) | Token @BotFather |
| `TELEGRAM_BOT_USERNAME` | Recommended | Username sans `@` (deep-links) |
| `TELEGRAM_WEBHOOK_SECRET` | No | Secret header Telegram |

Voir aussi `backend/api/.env.example`.

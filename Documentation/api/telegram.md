# Telegram webhook documentation

> **Base path:** `/api/v1` — see [API Base Path](./api.md).

Key points :

- [Webhook](#webhook)
- [setWebhook (ops)](#setwebhook-ops)
- [Environment](#environment)

> **Important:** this endpoint has **no JWT** and **no X-API-Key**. It must stay registered **before** `ApiKeyMiddleware` / `ProtectedRoute` on `/api/v1`, otherwise Telegram receives `401 Unauthorized` and no contact is linked. Protection is the mandatory `TELEGRAM_WEBHOOK_SECRET`.

Architecture : [architecture_telegram_alerts.md](../architecture_telegram_alerts.md).

---

# Webhook

## Endpoint

```http
POST /telegram/webhook
```

Receives Bot API updates (`message`, `/start`, shared contact).

### Required secret

`TELEGRAM_WEBHOOK_SECRET` **must** be set. Requests without a matching header are rejected with `401`:

```http
X-Telegram-Bot-Api-Secret-Token: <TELEGRAM_WEBHOOK_SECRET>
```

If the secret env var is empty, every webhook call is rejected.

### Behaviour

| Event | Action |
|-------|--------|
| `/start <invite_token>` | Links `telegram_chat_id` to the contact with that `invite_token` **only if** not already linked |
| `/start` without a valid token | Shows the “Share my phone number” keyboard |
| Message with `contact` (request_contact) | Accepts only when the shared contact is the sender’s own number (`Contact.UserID == From.ID`), then matches phone among unlinked contacts |

HTTP response: always `200` to Telegram after processing (to avoid useless retries), even if the token is unknown — except auth failures on the secret (`401`).

---

# setWebhook (ops)

After the API is up (and a public tunnel locally, e.g. ngrok):

```bash
curl "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/setWebhook" \
  -d "url=https://<PUBLIC_HOST>/api/v1/telegram/webhook" \
  -d "secret_token=<TELEGRAM_WEBHOOK_SECRET>"
```

Check:

```bash
curl "https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/getWebhookInfo"
```

Useful `getWebhookInfo` fields:

- `url` — must point at your webhook
- `last_error_message` — e.g. `401 Unauthorized` = JWT/API-key middleware still in front of the webhook, or secret mismatch
- `pending_update_count` — pending updates

---

# Environment

| Variable | Required | Description |
|----------|----------|-------------|
| `TELEGRAM_BOT_TOKEN` | Yes (for sending) | @BotFather token |
| `TELEGRAM_BOT_USERNAME` | Recommended | Username without `@` (deep-links) |
| `TELEGRAM_WEBHOOK_SECRET` | **Yes** | Secret header Telegram sends on each update |

See also `backend/api/.env.example`.

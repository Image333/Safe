# Alert documentation section

> **Base path:** `/api/v1` — see [API Base Path](./api.md).

Key points :

- [Create Alert](#create-alert)
- [List Alerts](#list-alerts)
- [Get Alert by ID](#get-alert-by-id)
- [Update Alert Status](#update-alert-status)
- [Delete Alert](#delete-alert)

> **Note:** All alert endpoints are **protected** (JWT). Every alert is owned by the user in the JWT ; accès à une alerte d’un autre user → `403`.

> See: **[JWT Authentication](./users.md#authentication---user-login)**

Après création, le backend notifie les contacts Telegram **liés** (`sendMessage`). Voir [Architecture Telegram](../architecture_telegram_alerts.md).

---

# Create Alert

## Endpoint

```http
POST /alerts
```

Crée une alerte pour l’utilisateur authentifié (statut initial `TRIGGERED`), résout / crée une `config_id` si besoin, puis fan-out Telegram.

### Request Body

| Field     | Type    | Required | Description                                                                 |
| --------- | ------- | -------- | --------------------------------------------------------------------------- |
| config_id | integer | No       | Configuration existante. Si absent / invalide, config user ou création auto |

### Example

```json
{}
```

ou

```json
{
  "config_id": 2
}
```

### Successful Response — `201 Created`

```json
{
  "message": "Alerte créée avec succès",
  "alert_id": 7,
  "notifications": [
    {
      "contact_id": 5,
      "contact_name": "Alice",
      "status": "sent",
      "channel": "telegram"
    },
    {
      "contact_id": 8,
      "contact_name": "Bob",
      "status": "not_linked"
    }
  ]
}
```

### Notification status

| status      | Meaning                                              |
| ----------- | ---------------------------------------------------- |
| `sent`      | `sendMessage` OK                                     |
| `not_linked`| Pas de `telegram_chat_id` (proche pas encore /start) |
| `error`     | Échec d’envoi (bot non configuré, API Telegram, …)   |

### Flutter

`HomeScreen._triggerAlert` appelle cet endpoint puis attache l’audio via `POST /alerts/:alertId/audio` lorsque l’upload MinIO réussit.

---

# List Alerts

## Endpoint

```http
GET /alerts
```

### Successful Response — `200 OK`

```json
{
  "count": 1,
  "data": [
    {
      "alert_id": 7,
      "timestamp": "2026-10-07 12:00:00",
      "status": "TRIGGERED",
      "user_id": 1,
      "config_id": 2
    }
  ]
}
```

---

# Get Alert by ID

## Endpoint

```http
GET /alerts/:id
```

### Successful Response — `200 OK`

Objet alerte unique. `404` / `403` selon existence et ownership.

---

# Update Alert Status

## Endpoint

```http
PUT /alerts/:id
```

### Request Body

```json
{
  "status": "RESOLVED"
}
```

Statuts acceptés : `PENDING`, `TRIGGERED`, `RESOLVED`, `CANCELLED`.

---

# Delete Alert

## Endpoint

```http
DELETE /alerts/:id
```

### Successful Response — `200 OK`

```json
{
  "message": "Alerte supprimée avec succès"
}
```

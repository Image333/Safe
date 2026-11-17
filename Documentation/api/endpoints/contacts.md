# Contacts documentation section

> **Base path:** `/api/v1` — see [API Base Path](./api.md).

Key points :

- [Create Contact](#create-contact)
- [List Contacts](#list-contacts)
- [Get Contact by ID](#get-contact-by-id)
- [Update Contact](#update-contact)
- [Delete Contact](#delete-contact)
- [Invite by Email (stub)](#invite-by-email-stub)

> **Note:** All contact endpoints below (sauf mention contraire) require a valid JWT in `Authorization: Bearer <token>`.

> See: **[JWT Authentication](./users.md#authentication---user-login)**

---

# Create Contact

## Endpoint

```http
POST /contacts
```

Creates a trusted contact for the authenticated user, generates an `invite_token`, and returns a Telegram deep-link `invite_link`.

### Request Body

| Field           | Type    | Required | Description                          |
| --------------- | ------- | -------- | ------------------------------------ |
| contact_name    | string  | Yes      | Display name                         |
| phone_number    | string  | Yes      | Phone (business identifier)          |
| email           | string  | No       | Optional email (future invite mail)  |
| contact_type    | string  | No       | Default `trusted`                    |
| priority_order  | integer | No       | Default `1`                          |

### Example

```json
{
  "contact_name": "Alice",
  "phone_number": "0612345678",
  "email": "alice@example.com"
}
```

### Successful Response — `201 Created`

```json
{
  "message": "Contact créé avec succès",
  "data": {
    "contact_id": 5,
    "contact_name": "Alice",
    "phone_number": "0612345678",
    "email": "alice@example.com",
    "contact_type": "trusted",
    "priority_order": 1,
    "telegram_linked": false,
    "invite_token": "f7c5d1126b80ae3141a4d328d48bf635",
    "invite_link": "https://t.me/safemobileapp_bot?start=f7c5d1126b80ae3141a4d328d48bf635"
  }
}
```

### Error — user JWT unknown on this DB — `401`

Si le token vient d’une autre instance (ex. cluster distant) alors que la DB locale n’a pas cet utilisateur :

```json
{
  "error": "Session invalide pour cette API. Déconnectez-vous puis créez un compte / reconnectez-vous.",
  "code": "user_not_found_on_this_api"
}
```

---

# List Contacts

## Endpoint

```http
GET /contacts
```

### Successful Response — `200 OK`

```json
{
  "count": 1,
  "data": [ /* ContactResponse[] */ ]
}
```

`telegram_linked` est `true` lorsque `telegram_chat_id` est renseigné (après `/start` sur le bot).

---

# Get Contact by ID

## Endpoint

```http
GET /contacts/:id
```

### Successful Response — `200 OK`

Body = un objet `ContactResponse` (mêmes champs que `data` à la création).

### Errors

- `404` — contact inconnu ou n’appartenant pas à l’utilisateur

---

# Update Contact

## Endpoint

```http
PUT /contacts/:id
```

### Request Body (tous optionnels)

| Field          | Type    |
| -------------- | ------- |
| contact_name   | string  |
| phone_number   | string  |
| email          | string  |
| contact_type   | string  |
| priority_order | integer |

### Successful Response — `200 OK`

```json
{
  "message": "Contact mis à jour",
  "data": { /* ContactResponse */ }
}
```

---

# Delete Contact

## Endpoint

```http
DELETE /contacts/:id
```

### Successful Response — `200 OK`

```json
{
  "message": "Contact supprimé"
}
```

---

# Invite by Email (stub)

## Endpoint

```http
POST /contacts/:id/invite/email
```

### Request Body

```json
{
  "email": "proche@example.com"
}
```

`email` est optionnel si déjà stocké sur le contact. Comportement cible (phase suivante) : upsert email + envoi SMTP du `invite_link`.

### Current Response — `501 Not Implemented`

```json
{
  "error": "Envoi d'email d'invitation non encore disponible",
  "code": "invite_email_not_implemented",
  "message": "Utilisez invite_link et copiez-le pour l'instant."
}
```

---

## ContactResponse fields

| Field               | Type    | Description                                      |
| ------------------- | ------- | ------------------------------------------------ |
| contact_id          | integer | ID                                               |
| contact_name        | string  | Name                                             |
| phone_number        | string  | Phone                                             |
| email               | string? | Optional                                         |
| telegram_linked     | boolean | `true` if bot can message this contact           |
| telegram_linked_at  | string? | ISO timestamp when linked                        |
| invite_token        | string  | Opaque token for deep-link                       |
| invite_link         | string  | `https://t.me/<BOT_USERNAME>?start=<token>`      |

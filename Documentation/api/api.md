# API Base Path

All endpoints documented in this file are relative to the API base path:

```text
/api/v1
```

This prefix must be included before every endpoint path.

### Examples

| Documented Endpoint              | Actual URL                           |
| -------------------------------- | ------------------------------------ |
| `POST /login`                    | `/api/v1/login`                      |
| `POST /users`                    | `/api/v1/users`                      |
| `GET /users/{email}`             | `/api/v1/users/{email}`              |
| `DELETE /users/{email}`          | `/api/v1/users/{email}`              |
| `POST /contacts`                 | `/api/v1/contacts`                   |
| `GET /contacts`                  | `/api/v1/contacts`                   |
| `POST /alerts`                   | `/api/v1/alerts`                     |
| `POST /alerts/{id}/audio`        | `/api/v1/alerts/{id}/audio`          |
| `GET /me/audio`                  | `/api/v1/me/audio`                   |
| `POST /telegram/webhook`         | `/api/v1/telegram/webhook`           |
| `...`                            | `...`                                |

### Example Request

```http
POST /api/v1/login
Content-Type: application/json

{
  "email": "john.doe@example.com",
  "password": "MySecurePassword123!"
}
```

> **Note:** Unless otherwise specified, all endpoint paths shown throughout this documentation are relative to the `/api/v1` base path.

# Documented endpoints

- [Users](./users.md)
- [Contacts](./contacts.md)
- [Alerts](./alerts.md)
- [Audio](./audio.md)
- [Telegram webhook](./telegram.md)
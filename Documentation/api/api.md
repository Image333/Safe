# API Base Path

All endpoints documented in this file are relative to the API base path:

```text
/api/v1
```

This prefix must be included before every endpoint path.

---

# Authentication

All endpoints under `/api/v1` require an **API key** passed in the `X-API-Key` header.

Two keys exist with the same access level:

| Key     | Audience                        |
| ------- | ------------------------------- |
| App key | Flutter mobile application      |
| Dev key | Developers (testing, debugging) |

### Example Request with API Key

```http
POST /api/v1/login
Content-Type: application/json
X-API-Key: <your-api-key>

{
  "email": "john.doe@example.com",
  "password": "MySecurePassword123!"
}
```

### Error Responses

**Missing API key**

```http
401 Unauthorized
```

```json
{
  "error": "API key requise"
}
```

**Invalid API key**

```http
403 Forbidden
```

```json
{
  "error": "API key invalide"
}
```

Some endpoints also require **JWT authentication** (user login). These are marked as *protected* in their documentation. When both are required, include both headers:

```http
GET /api/v1/me/audio
X-API-Key: <your-api-key>
Authorization: Bearer <your-jwt-token>
```

---

### Examples

| Documented Endpoint       | Actual URL                  |
| ------------------------- | --------------------------- |
| `POST /login`             | `/api/v1/login`             |
| `POST /users`             | `/api/v1/users`             |
| `GET /users/{email}`      | `/api/v1/users/{email}`     |
| `DELETE /users/{email}`   | `/api/v1/users/{email}`     |
| `POST /alerts/{id}/audio` | `/api/v1/alerts/{id}/audio` |
| `GET /audio/{id}`         | `/api/v1/audio/{id}`        |
| `GET /alerts/{id}/audio`  | `/api/v1/alerts/{id}/audio` |
| `GET /me/audio`           | `/api/v1/me/audio`          |
| `POST /configurations`    | `/api/v1/configurations`    |
| `GET /configurations`     | `/api/v1/configurations`    |
| `GET /configurations/{id}` | `/api/v1/configurations/{id}` |
| `PUT /configurations/{id}` | `/api/v1/configurations/{id}` |
| `DELETE /configurations/{id}` | `/api/v1/configurations/{id}` |
| `POST /alerts`            | `/api/v1/alerts`            |
| `GET /alerts`             | `/api/v1/alerts`            |
| `GET /alerts/{id}`        | `/api/v1/alerts/{id}`       |
| `PUT /alerts/{id}`        | `/api/v1/alerts/{id}`       |
| `DELETE /alerts/{id}`     | `/api/v1/alerts/{id}`       |

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

# Documented enpoints
- [Users](./endpoints/users.md)
- [Audio](./endpoints/audio.md)
- [Configurations](./endpoints/configurations.md)
- [Alerts](./endpoints/alerts.md)
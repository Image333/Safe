# Alert documentation section

> **API Key required:** All endpoints require a valid `X-API-Key` header. See [Authentication](../api.md#authentication).

Key points :
 - [Create Alert](#create-alert)
 - [List Alerts](#list-alerts)
 - [Get Alert by ID](#get-alert-by-id)
 - [Update Alert Status](#update-alert-status)
 - [Delete Alert](#delete-alert)

> **Note:** All alert endpoints are **protected** and require a valid JWT token in the `Authorization` header.
>
> **Note:** Every alert is owned by the user identified in the JWT. Reading, updating or deleting an alert belonging to another user returns **403 Forbidden**.

> See: **[JWT Authentication](../users.md#authentication---user-login)**

---

# Create Alert

## Endpoint

```http
POST /alerts
```

Creates an alert owned by the authenticated user. The alert is linked to an existing configuration referenced by `config_id`. The new alert is created with the default status `PENDING`.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## Request Body

**Content-Type:** `application/json`

### Parameters

| Field     | Type    | Required | Description                                             |
| --------- | ------- | -------- | ------------------------------------------------------- |
| config_id | integer | Yes      | ID of an existing configuration to attach to the alert  |

> **Note:** `user_id` is **not** part of the body — it is taken from the JWT.

### Example

```json
{
  "config_id": 2
}
```

---

## Successful Response

### HTTP Status Code

```http
201 Created
```

### Response Body

```json
{
  "message": "Alerte créée avec succès",
  "alert_id": 7
}
```

### Response Fields

| Field    | Type    | Description                     |
| -------- | ------- | ------------------------------- |
| message  | string  | Success message                 |
| alert_id | integer | ID of the newly created alert   |

---

## Error Responses

### Invalid Request

#### HTTP Status Code

```http
400 Bad Request
```

#### Responses

Invalid JSON:

```json
{
  "error": "Format JSON invalide"
}
```

Missing or zero config_id:

```json
{
  "error": "config_id requis"
}
```

---

### Configuration Not Found

Returned when `config_id` does not reference an existing configuration.

#### HTTP Status Code

```http
404 Not Found
```

#### Response

```json
{
  "error": "Configuration non trouvée"
}
```

---

### Internal Server Error

#### HTTP Status Code

```http
500 Internal Server Error
```

#### Response

```json
{
  "error": "Impossible de créer l'alerte"
}
```

---

## Notes

* The alert is always attached to the user identified by the JWT.
* `config_id` must reference an existing configuration — otherwise the request is rejected with **404**, rather than failing on the foreign key constraint.
* The alert status defaults to `PENDING` (see [Update Alert Status](#update-alert-status) for the list of statuses).

---

## Example Request

### HTTP

```http
POST /api/v1/alerts
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
Content-Type: application/json

{
  "config_id": 2
}
```

### cURL

```bash
curl -X POST http://<host>:<port>/api/v1/alerts \
  -H "X-API-Key: <api_key>" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "config_id": 2
  }'
```

## Example Response

```json
{
  "message": "Alerte créée avec succès",
  "alert_id": 7
}
```

---

# List Alerts

## Endpoint

```http
GET /alerts
```

Returns every alert owned by the authenticated user, most recent first.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## Successful Response

### HTTP Status Code

```http
200 OK
```

### Response Body

```json
{
  "count": 2,
  "data": [
    {
      "alert_id": 7,
      "timestamp": "2026-07-17 11:41:49",
      "status": "PENDING",
      "user_id": 1,
      "config_id": 2
    },
    {
      "alert_id": 3,
      "timestamp": "2026-07-16 09:02:13",
      "status": "RESOLVED",
      "user_id": 1,
      "config_id": 2
    }
  ]
}
```

### Response Fields

| Field | Type    | Description                    |
| ----- | ------- | ------------------------------ |
| count | integer | Number of alerts returned      |
| data  | array   | List of alert objects          |

Each element of `data` contains:

| Field     | Type    | Description                                          |
| --------- | ------- | ---------------------------------------------------- |
| alert_id  | integer | Unique alert identifier                              |
| timestamp | string  | Alert creation time (`YYYY-MM-DD HH:MM:SS`)          |
| status    | string  | Current status of the alert                          |
| user_id   | integer | ID of the user who owns the alert                    |
| config_id | integer | ID of the configuration attached to the alert        |

---

## Error Responses

### Missing or Invalid JWT

#### HTTP Status Code

```http
401 Unauthorized
```

#### Response

```json
{
  "error": "Accès refusé, token manquant ou format invalide"
}
```

---

### Internal Server Error

#### HTTP Status Code

```http
500 Internal Server Error
```

#### Response

```json
{
  "error": "Erreur serveur"
}
```

---

## Notes

* Only the alerts owned by the authenticated user are returned.
* Alerts are ordered by `alert_id` descending.

---

## Example Request

```http
GET /api/v1/alerts
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

## Example Response

```json
{
  "count": 1,
  "data": [
    {
      "alert_id": 7,
      "timestamp": "2026-07-17 11:41:49",
      "status": "PENDING",
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

Returns a single alert identified by its ID. The alert is only returned if it belongs to the authenticated user.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## URL Parameters

| Parameter | Type    | Required | Description               |
| --------- | ------- | -------- | ------------------------- |
| id        | integer | Yes      | ID of the alert to retrieve |

---

## Successful Response

### HTTP Status Code

```http
200 OK
```

### Response Body

```json
{
  "alert_id": 7,
  "timestamp": "2026-07-17 11:41:49",
  "status": "PENDING",
  "user_id": 1,
  "config_id": 2
}
```

### Response Fields

| Field     | Type    | Description                                   |
| --------- | ------- | --------------------------------------------- |
| alert_id  | integer | Unique alert identifier                       |
| timestamp | string  | Alert creation time (`YYYY-MM-DD HH:MM:SS`)   |
| status    | string  | Current status of the alert                   |
| user_id   | integer | ID of the user who owns the alert             |
| config_id | integer | ID of the configuration attached to the alert |

---

## Error Responses

### Invalid Alert ID

#### HTTP Status Code

```http
400 Bad Request
```

#### Response

```json
{
  "error": "ID alerte invalide"
}
```

---

### Alert Not Found

#### HTTP Status Code

```http
404 Not Found
```

#### Response

```json
{
  "error": "Alerte non trouvée"
}
```

---

### Alert Belongs to Another User

#### HTTP Status Code

```http
403 Forbidden
```

#### Response

```json
{
  "error": "Cette alerte ne vous appartient pas"
}
```

---

### Internal Server Error

#### HTTP Status Code

```http
500 Internal Server Error
```

#### Response

```json
{
  "error": "Erreur serveur"
}
```

---

## Example Request

```http
GET /api/v1/alerts/7
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

## Example Response

```json
{
  "alert_id": 7,
  "timestamp": "2026-07-17 11:41:49",
  "status": "PENDING",
  "user_id": 1,
  "config_id": 2
}
```

---

# Update Alert Status

## Endpoint

```http
PUT /alerts/:id
```

Updates the status of an existing alert. Only the owner of the alert can update it.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## URL Parameters

| Parameter | Type    | Required | Description             |
| --------- | ------- | -------- | ----------------------- |
| id        | integer | Yes      | ID of the alert to update |

---

## Request Body

**Content-Type:** `application/json`

### Parameters

| Field  | Type   | Required | Description                             |
| ------ | ------ | -------- | --------------------------------------- |
| status | string | Yes      | New status of the alert (see table below) |

### Allowed statuses

| Status      | Description                                          |
| ----------- | ---------------------------------------------------- |
| `PENDING`   | Alert created, not yet handled (default at creation)  |
| `TRIGGERED` | Alert triggered by the user                           |
| `RESOLVED`  | Alert handled and closed                              |
| `CANCELLED` | Alert cancelled                                       |

Any other value is rejected with **400 Bad Request**.

### Example

```json
{
  "status": "TRIGGERED"
}
```

---

## Successful Response

### HTTP Status Code

```http
200 OK
```

### Response Body

```json
{
  "message": "Statut de l'alerte mis à jour"
}
```

### Response Fields

| Field   | Type   | Description     |
| ------- | ------ | --------------- |
| message | string | Success message |

---

## Error Responses

### Invalid Alert ID

#### HTTP Status Code

```http
400 Bad Request
```

#### Response

```json
{
  "error": "ID alerte invalide"
}
```

---

### Invalid Request

#### HTTP Status Code

```http
400 Bad Request
```

#### Responses

Invalid JSON:

```json
{
  "error": "Format JSON invalide"
}
```

Status not in the allowed set:

```json
{
  "error": "Statut invalide"
}
```

---

### Alert Not Found

#### HTTP Status Code

```http
404 Not Found
```

#### Response

```json
{
  "error": "Alerte non trouvée"
}
```

---

### Alert Belongs to Another User

#### HTTP Status Code

```http
403 Forbidden
```

#### Response

```json
{
  "error": "Cette alerte ne vous appartient pas"
}
```

---

### Internal Server Error

#### HTTP Status Code

```http
500 Internal Server Error
```

#### Response

```json
{
  "error": "Impossible de mettre à jour l'alerte"
}
```

---

## Notes

* Only the `status` field can be updated — the alert's `config_id` and timestamp are immutable.
* Setting the status to its current value still returns **200**, not 404.

---

## Example Request

### HTTP

```http
PUT /api/v1/alerts/7
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
Content-Type: application/json

{
  "status": "TRIGGERED"
}
```

### cURL

```bash
curl -X PUT http://<host>:<port>/api/v1/alerts/7 \
  -H "X-API-Key: <api_key>" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "TRIGGERED"
  }'
```

## Example Response

```json
{
  "message": "Statut de l'alerte mis à jour"
}
```

---

# Delete Alert

## Endpoint

```http
DELETE /alerts/:id
```

Deletes an alert identified by its ID. Only the owner of the alert can delete it.

> **Warning:** Deleting an alert also deletes its linked records — `geolocations` and `audio_records` both reference `alert_id` with `ON DELETE CASCADE`.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## URL Parameters

| Parameter | Type    | Required | Description             |
| --------- | ------- | -------- | ----------------------- |
| id        | integer | Yes      | ID of the alert to delete |

---

## Successful Response

### HTTP Status Code

```http
200 OK
```

### Response Body

```json
{
  "message": "Alerte supprimée avec succès"
}
```

### Response Fields

| Field   | Type   | Description     |
| ------- | ------ | --------------- |
| message | string | Success message |

---

## Error Responses

### Invalid Alert ID

#### HTTP Status Code

```http
400 Bad Request
```

#### Response

```json
{
  "error": "ID alerte invalide"
}
```

---

### Alert Not Found

#### HTTP Status Code

```http
404 Not Found
```

#### Response

```json
{
  "error": "Alerte non trouvée"
}
```

---

### Alert Belongs to Another User

#### HTTP Status Code

```http
403 Forbidden
```

#### Response

```json
{
  "error": "Cette alerte ne vous appartient pas"
}
```

---

### Internal Server Error

#### HTTP Status Code

```http
500 Internal Server Error
```

#### Response

```json
{
  "error": "Erreur lors de la suppression de l'alerte"
}
```

---

## Notes

* Deleting an alert is irreversible.
* The attached audio record (if any) and geolocation are deleted as well.

---

## Example Request

```http
DELETE /api/v1/alerts/7
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

## Example Response

```json
{
  "message": "Alerte supprimée avec succès"
}
```

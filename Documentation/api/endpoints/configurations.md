# Configuration documentation section

> **API Key required:** All endpoints require a valid `X-API-Key` header. See [Authentication](../api.md#authentication).

Key points :
 - [Create Configuration](#create-configuration)
 - [List Configurations](#list-configurations)
 - [Get Configuration by ID](#get-configuration-by-id)
 - [Update Configuration](#update-configuration)
 - [Delete Configuration](#delete-configuration)

> **Note:** All configuration endpoints are **protected** and require a valid JWT token in the `Authorization` header.
>
> See: **[JWT Authentication](../users.md#authentication---user-login)**

---

# Create Configuration

## Endpoint

```http
POST /configurations
```

Creates a configuration and stores it in the database. A configuration holds the alert word and the app disguise used by an alert.

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

| Field        | Type   | Required | Description                                |
| ------------ | ------ | -------- | ------------------------------------------ |
| alert_word   | string | Yes      | Word that triggers the alert               |
| app_disguise | string | Yes      | Disguised name displayed by the application |

### Example

```json
{
  "alert_word": "help",
  "app_disguise": "Weather"
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
  "message": "Configuration créée avec succès",
  "config_id": 1
}
```

### Response Fields

| Field     | Type    | Description                           |
| --------- | ------- | ------------------------------------- |
| message   | string  | Success message                       |
| config_id | integer | ID of the newly created configuration |

---

## Error Responses

### Invalid JSON Format

#### HTTP Status Code

```http
400 Bad Request
```

#### Response

```json
{
  "error": "Format JSON invalide"
}
```

---

### Missing Required Fields

#### HTTP Status Code

```http
400 Bad Request
```

#### Responses

Missing alert_word:

```json
{
  "error": "alert_word requis"
}
```

Missing app_disguise:

```json
{
  "error": "app_disguise requis"
}
```

---

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
  "error": "Impossible de créer la configuration"
}
```

---

## Notes

* A configuration is referenced by an alert through `config_id` — it must exist before an alert can use it.
* Alert words and app disguises are free-form strings; no uniqueness constraint is enforced.

---

## Example Request

### HTTP

```http
POST /api/v1/configurations
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
Content-Type: application/json

{
  "alert_word": "help",
  "app_disguise": "Weather"
}
```

### cURL

```bash
curl -X POST http://<host>:<port>/api/v1/configurations \
  -H "X-API-Key: <api_key>" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_word": "help",
    "app_disguise": "Weather"
  }'
```

## Example Response

```json
{
  "message": "Configuration créée avec succès",
  "config_id": 1
}
```

---

# List Configurations

## Endpoint

```http
GET /configurations
```

Returns every configuration stored in the database, ordered by `config_id`.

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
      "config_id": 1,
      "alert_word": "help",
      "app_disguise": "Weather"
    },
    {
      "config_id": 2,
      "alert_word": "sos",
      "app_disguise": "Notes"
    }
  ]
}
```

### Response Fields

| Field | Type    | Description                          |
| ----- | ------- | ------------------------------------ |
| count | integer | Number of configurations returned    |
| data  | array   | List of configuration objects        |

Each element of `data` contains:

| Field        | Type    | Description                                 |
| ------------ | ------- | ------------------------------------------- |
| config_id    | integer | Unique configuration identifier             |
| alert_word   | string  | Word that triggers the alert                |
| app_disguise | string  | Disguised name displayed by the application |

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

## Example Request

```http
GET /api/v1/configurations
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

## Example Response

```json
{
  "count": 2,
  "data": [
    {
      "config_id": 1,
      "alert_word": "help",
      "app_disguise": "Weather"
    },
    {
      "config_id": 2,
      "alert_word": "sos",
      "app_disguise": "Notes"
    }
  ]
}
```

---

# Get Configuration by ID

## Endpoint

```http
GET /configurations/:id
```

Returns a single configuration identified by its ID.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## URL Parameters

| Parameter | Type    | Required | Description                        |
| --------- | ------- | -------- | ---------------------------------- |
| id        | integer | Yes      | ID of the configuration to retrieve |

---

## Successful Response

### HTTP Status Code

```http
200 OK
```

### Response Body

```json
{
  "config_id": 1,
  "alert_word": "help",
  "app_disguise": "Weather"
}
```

### Response Fields

| Field        | Type    | Description                                 |
| ------------ | ------- | ------------------------------------------- |
| config_id    | integer | Unique configuration identifier             |
| alert_word   | string  | Word that triggers the alert                |
| app_disguise | string  | Disguised name displayed by the application |

---

## Error Responses

### Invalid Configuration ID

#### HTTP Status Code

```http
400 Bad Request
```

#### Response

```json
{
  "error": "ID configuration invalide"
}
```

---

### Configuration Not Found

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
  "error": "Erreur serveur"
}
```

---

## Example Request

```http
GET /api/v1/configurations/1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

## Example Response

```json
{
  "config_id": 1,
  "alert_word": "help",
  "app_disguise": "Weather"
}
```

---

# Update Configuration

## Endpoint

```http
PUT /configurations/:id
```

Updates an existing configuration. Both `alert_word` and `app_disguise` must be provided — this is a full replacement, not a partial update.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## URL Parameters

| Parameter | Type    | Required | Description                       |
| --------- | ------- | -------- | --------------------------------- |
| id        | integer | Yes      | ID of the configuration to update |

---

## Request Body

**Content-Type:** `application/json`

### Parameters

| Field        | Type   | Required | Description                                 |
| ------------ | ------ | -------- | ------------------------------------------- |
| alert_word   | string | Yes      | New word that triggers the alert            |
| app_disguise | string | Yes      | New disguised name displayed by the application |

### Example

```json
{
  "alert_word": "tonnerre",
  "app_disguise": "Calculette"
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
  "message": "Configuration mise à jour avec succès"
}
```

### Response Fields

| Field   | Type   | Description     |
| ------- | ------ | --------------- |
| message | string | Success message |

---

## Error Responses

### Invalid Configuration ID

#### HTTP Status Code

```http
400 Bad Request
```

#### Response

```json
{
  "error": "ID configuration invalide"
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

Missing alert_word:

```json
{
  "error": "alert_word requis"
}
```

Missing app_disguise:

```json
{
  "error": "app_disguise requis"
}
```

---

### Configuration Not Found

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
  "error": "Impossible de mettre à jour la configuration"
}
```

---

## Example Request

### HTTP

```http
PUT /api/v1/configurations/1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
Content-Type: application/json

{
  "alert_word": "tonnerre",
  "app_disguise": "Calculette"
}
```

### cURL

```bash
curl -X PUT http://<host>:<port>/api/v1/configurations/1 \
  -H "X-API-Key: <api_key>" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_word": "tonnerre",
    "app_disguise": "Calculette"
  }'
```

## Example Response

```json
{
  "message": "Configuration mise à jour avec succès"
}
```

---

# Delete Configuration

## Endpoint

```http
DELETE /configurations/:id
```

Deletes a configuration identified by its ID.

> **Warning:** Alerts reference a configuration through `config_id` with `ON DELETE CASCADE`. Deleting a configuration also deletes every alert linked to it.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## URL Parameters

| Parameter | Type    | Required | Description                       |
| --------- | ------- | -------- | --------------------------------- |
| id        | integer | Yes      | ID of the configuration to delete |

---

## Successful Response

### HTTP Status Code

```http
200 OK
```

### Response Body

```json
{
  "message": "Configuration supprimée avec succès"
}
```

### Response Fields

| Field   | Type   | Description     |
| ------- | ------ | --------------- |
| message | string | Success message |

---

## Error Responses

### Invalid Configuration ID

#### HTTP Status Code

```http
400 Bad Request
```

#### Response

```json
{
  "error": "ID configuration invalide"
}
```

---

### Configuration Not Found

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
  "error": "Erreur lors de la suppression de la configuration"
}
```

---

## Notes

* Deleting a configuration is irreversible.
* Alerts linked to the configuration are deleted as well (`ON DELETE CASCADE` on `alerts.config_id`).

---

## Example Request

```http
DELETE /api/v1/configurations/1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

## Example Response

```json
{
  "message": "Configuration supprimée avec succès"
}
```

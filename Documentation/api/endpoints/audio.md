# Audio documentation section

> **API Key required:** All endpoints require a valid `X-API-Key` header. See [Authentication](../api.md#authentication).

Key points :
 - [Create Audio Record](#create-audio-record)
 - [Get Audio by ID](#get-audio-by-id)
 - [Get Audio by Alert](#get-audio-by-alert)
 - [Get All Audio for Current User](#get-all-audio-for-current-user)

> **Note:** All audio endpoints are **protected** and require a valid JWT token in the `Authorization` header.
>
> See: **[JWT Authentication](../users.md#authentication---user-login)**

---

# Create Audio Record

## Endpoint

```http
POST /alerts/:alertId/audio
```

Adds an audio record to an existing alert. The audio file itself must be uploaded to a MinIO/S3 bucket beforehand — this endpoint stores only the metadata and the object URL.

The alert must belong to the authenticated user and must not already have an audio record attached (1:1 relationship).

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## URL Parameters

| Parameter | Type    | Required | Description                     |
| --------- | ------- | -------- | ------------------------------- |
| alertId   | integer | Yes      | ID of the alert to attach audio |

---

## Request Body

**Content-Type:** `application/json`

### Parameters

| Field    | Type    | Required | Description                                                |
| -------- | ------- | -------- | ---------------------------------------------------------- |
| blob_url | string  | Yes      | URL of the audio file hosted on MinIO / S3-compatible storage |
| duration | integer | Yes      | Duration of the audio recording in seconds (must be > 0)   |
| format   | string  | Yes      | Audio format (e.g. `mp3`, `wav`, `ogg`)                     |

### Example

```json
{
  "blob_url": "http://minio-service:9000/audio-bucket/recording-001.mp3",
  "duration": 45,
  "format": "mp3"
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
  "message": "Enregistrement audio créé avec succès",
  "audio_id": 1
}
```

### Response Fields

| Field    | Type    | Description                    |
| -------- | ------- | ------------------------------ |
| message  | string  | Success message                |
| audio_id | integer | ID of the newly created record |

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

Missing blob_url:

```json
{
  "error": "blob_url requis"
}
```

Invalid duration:

```json
{
  "error": "duration doit être positif"
}
```

Missing format:

```json
{
  "error": "format requis"
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

### Audio Already Exists

Returned when the alert already has an audio record attached (1:1 constraint).

#### HTTP Status Code

```http
409 Conflict
```

#### Response

```json
{
  "error": "Un enregistrement audio existe déjà pour cette alerte"
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

Or:

```json
{
  "error": "Impossible de créer l'enregistrement audio"
}
```

---

## Notes

* The `blob_url` must point to a valid MinIO/S3 object URL accessible within the cluster.
* Each alert can have at most **one** audio record (UNIQUE constraint on `alert_id`).
* The authenticated user must be the owner of the alert.
* Audio binary files are **not** sent through this endpoint — use MinIO directly for uploads.

---

## Example Request

### HTTP

```http
POST /api/v1/alerts/3/audio
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
Content-Type: application/json

{
  "blob_url": "http://minio-service:9000/audio-bucket/test-recording.mp3",
  "duration": 45,
  "format": "mp3"
}
```

> **Note:** `alertId` (`3` in the example above) is a **URL parameter**, not a body field. It identifies the alert to attach the audio record to.

### cURL

```bash
curl -X POST http://<host>:<port>/api/v1/alerts/3/audio \
  -H "X-API-Key: <api_key>" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "blob_url": "http://minio-service:9000/audio-bucket/test-recording.mp3",
    "duration": 45,
    "format": "mp3"
  }'
```

## Example Response

```json
{
  "message": "Enregistrement audio créé avec succès",
  "audio_id": 1
}
```

---

# Get Audio by ID

## Endpoint

```http
GET /audio/:id
```

Returns a single audio record identified by its ID. Includes associated alert information (timestamp and status). The record is only returned if it belongs to an alert owned by the authenticated user.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## URL Parameters

| Parameter | Type    | Required | Description                |
| --------- | ------- | -------- | -------------------------- |
| id        | integer | Yes      | ID of the audio record     |

---

## Successful Response

### HTTP Status Code

```http
200 OK
```

### Response Body

```json
{
  "audio_id": 1,
  "blob_url": "http://minio-service:9000/audio-bucket/test-recording.mp3",
  "duration": 45,
  "format": "mp3",
  "alert_id": 3,
  "alert_timestamp": "2026-07-17 11:41:49",
  "alert_status": "PENDING"
}
```

### Response Fields

| Field           | Type              | Description                                |
| --------------- | ----------------- | ------------------------------------------ |
| audio_id        | integer           | Unique audio record identifier             |
| blob_url        | string            | URL to the audio file on MinIO/S3          |
| duration        | integer           | Duration in seconds                        |
| format          | string            | Audio format (e.g. `mp3`, `wav`)           |
| alert_id        | integer           | ID of the associated alert                 |
| alert_timestamp | string            | Timestamp of the alert (`YYYY-MM-DD HH:MM:SS`) |
| alert_status    | string            | Current status of the alert                |

---

## Error Responses

### Invalid Audio ID

#### HTTP Status Code

```http
400 Bad Request
```

#### Response

```json
{
  "error": "ID audio invalide"
}
```

---

### Audio Not Found

Returned when the audio record does not exist or belongs to a different user.

#### HTTP Status Code

```http
404 Not Found
```

#### Response

```json
{
  "error": "Enregistrement audio non trouvé"
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

## Security Notes

* This endpoint is protected by **JWT authentication**.
* Users can only retrieve audio records linked to their own alerts.
* Ownership is verified via a SQL JOIN between `audio_records`, `alerts`, and the JWT `user_id`.

---

## Example Request

```http
GET /api/v1/audio/1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

## Example Response

```json
{
  "audio_id": 1,
  "blob_url": "http://minio-service:9000/audio-bucket/test-recording.mp3",
  "duration": 45,
  "format": "mp3",
  "alert_id": 3,
  "alert_timestamp": "2026-07-17 11:41:49",
  "alert_status": "PENDING"
}
```

---

# Get Audio by Alert

## Endpoint

```http
GET /alerts/:alertId/audio
```

Returns the audio record attached to a specific alert. The alert must belong to the authenticated user.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication](../users.md#authentication---user-login)**

```http
Authorization: Bearer <token>
```

---

## URL Parameters

| Parameter | Type    | Required | Description                           |
| --------- | ------- | -------- | ------------------------------------- |
| alertId   | integer | Yes      | ID of the alert whose audio to fetch  |

---

## Successful Response

### HTTP Status Code

```http
200 OK
```

### Response Body

```json
{
  "audio_id": 1,
  "blob_url": "http://minio-service:9000/audio-bucket/test-recording.mp3",
  "duration": 45,
  "format": "mp3",
  "alert_id": 3,
  "alert_timestamp": "2026-07-17 11:41:49",
  "alert_status": "PENDING"
}
```

### Response Fields

Same structure as [Get Audio by ID](#get-audio-by-id).

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

### Audio Not Found

Returned when no audio record exists for this alert, or the alert belongs to a different user.

#### HTTP Status Code

```http
404 Not Found
```

#### Response

```json
{
  "error": "Aucun enregistrement audio pour cette alerte"
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

## Security Notes

* Protected by **JWT authentication**.
* Only the alert owner can access its audio record.

---

## Example Request

```http
GET /api/v1/alerts/3/audio
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

## Example Response

```json
{
  "audio_id": 1,
  "blob_url": "http://minio-service:9000/audio-bucket/test-recording.mp3",
  "duration": 45,
  "format": "mp3",
  "alert_id": 3,
  "alert_timestamp": "2026-07-17 11:41:49",
  "alert_status": "PENDING"
}
```

---

# Get All Audio for Current User

## Endpoint

```http
GET /me/audio
```

Returns all audio records belonging to the currently authenticated user, sorted by alert timestamp (most recent first).

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
[
  {
    "audio_id": 1,
    "blob_url": "http://minio-service:9000/audio-bucket/test-recording.mp3",
    "duration": 45,
    "format": "mp3",
    "alert_id": 3,
    "alert_timestamp": "2026-07-17 11:41:49",
    "alert_status": "PENDING"
  }
]
```

### Response Fields

An array of audio objects, each with the same structure as [Get Audio by ID](#get-audio-by-id). Returns an empty array `[]` if the user has no audio records.

---

## Error Responses

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

## Security Notes

* Protected by **JWT authentication**.
* Only returns records owned by the authenticated user.

---

## Example Request

```http
GET /api/v1/me/audio
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

## Example Response

```json
[
  {
    "audio_id": 1,
    "blob_url": "http://minio-service:9000/audio-bucket/test-recording.mp3",
    "duration": 45,
    "format": "mp3",
    "alert_id": 3,
    "alert_timestamp": "2026-07-17 11:41:49",
    "alert_status": "PENDING"
  }
]
```

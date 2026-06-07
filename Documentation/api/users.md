Welcome to api documentation section

key points :
 - [Create Users](#create-user)
 - [Get Users](#get-user-by-email)
 - [User Login](#authentication---user-login)

# Create User

## Endpoint

```http
POST /users
```

Creates a new user account and stores it in the database. The user's password is securely hashed using bcrypt before being saved.

---

## Request Body

**Content-Type:** `application/json`

### Parameters

| Field     | Type   | Required | Description          |
| --------- | ------ | -------- | -------------------- |
| name      | string | Yes      | User's last name     |
| firstname | string | Yes      | User's first name    |
| email     | string | Yes      | User's email address |
| password  | string | Yes      | User's password      |

### Example

```json
{
  "name": "Doe",
  "firstname": "John",
  "email": "john.doe@example.com",
  "password": "MySecurePassword123!"
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
  "message": "User created successfully",
  "user_id": 42
}
```

### Response Fields

| Field   | Type    | Description                  |
| ------- | ------- | ---------------------------- |
| message | string  | Success message              |
| user_id | integer | ID of the newly created user |

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
  "error": "Invalid JSON format"
}
```

---

### Missing Required Fields

#### HTTP Status Code

```http
400 Bad Request
```

#### Responses

Missing name:

```json
{
  "error": "Name is required"
}
```

Missing firstname:

```json
{
  "error": "Firstname is required"
}
```

Missing email:

```json
{
  "error": "Email is required"
}
```

Missing password:

```json
{
  "error": "Password is required"
}
```

---

### User Creation Failed

#### HTTP Status Code

```http
500 Internal Server Error
```

#### Response

```json
{
  "error": "Unable to create user (email already in use?)"
}
```

This error may occur if the email address already exists in the database or if another database error occurs.

---

### Internal Server Error

#### HTTP Status Code

```http
500 Internal Server Error
```

#### Response

```json
{
  "error": "Internal server error"
}
```

This error is returned if password hashing fails or another unexpected server-side issue occurs.

---

## Notes

* Passwords are hashed using **bcrypt** before being stored.
* The API does not return the user's password or password hash.
* The newly created user's unique identifier is returned in the response.
* Email uniqueness should be enforced at the database level to prevent duplicate accounts.


# Authentication - User Login

## Endpoint

```http
POST /login
```

Authenticates a user using their email address and password. If authentication succeeds, a JWT token is generated and returned to the client.

---

## Request Body

**Content-Type:** `application/json`

### Parameters

| Field    | Type   | Required | Description          |
| -------- | ------ | -------- | -------------------- |
| email    | string | Yes      | User's email address |
| password | string | Yes      | User's password      |

### Example

```json
{
  "email": "john.doe@example.com",
  "password": "MySecurePassword123!"
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
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI..."
}
```

### Response Fields

| Field   | Type   | Description                                  |
| ------- | ------ | -------------------------------------------- |
| message | string | Success message                              |
| token   | string | JWT token used to access protected endpoints |

---

## Error Responses

### Invalid Request

#### HTTP Status Code

```http
400 Bad Request
```

#### Response

```json
{
  "error": "Invalid JSON format"
}
```

Or:

```json
{
  "error": "Email and password are required"
}
```

---

### Invalid Credentials

#### HTTP Status Code

```http
401 Unauthorized
```

#### Response

```json
{
  "error": "Invalid credentials"
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
  "error": "Server error"
}
```

Or:

```json
{
  "error": "Unable to generate token"
}
```

---

## JWT Claims

The generated JWT token contains the following claims:

| Claim   | Type    | Description                                 |
| ------- | ------- | ------------------------------------------- |
| user_id | integer | Unique user identifier                      |
| email   | string  | User's email address                        |
| exp     | integer | Token expiration timestamp (Unix timestamp) |

### Token Lifetime

The JWT token is valid for **24 hours** from the time it is issued.

---

## Using the Token

To access protected endpoints, include the JWT token in the `Authorization` header:

```http
Authorization: Bearer <token>
```

### Example

```http
GET /api/protected-resource
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...
```

---

## Authentication Flow

1. The client sends an email address and password.
2. The API validates the request payload.
3. The user's email is searched in the database.
4. The provided password is verified against the stored bcrypt hash.
5. If authentication succeeds, a JWT token is generated and signed.
6. The token is returned to the client.
7. The client uses the token to access protected resources.

# Get User by Email

## Endpoint

```http id="q8v2kp"
GET /users/:email
```

Returns detailed information about a user identified by their email address.

This endpoint is **protected** and requires authentication using a JWT token.

---

## Authentication

This endpoint requires a valid JWT token in the `Authorization` header.

See: **[JWT Authentication section](#authentication---user-login)**

```http id="jwt_auth_example"
Authorization: Bearer <token>
```

---

## URL Parameters

| Parameter | Type   | Required | Description                           |
| --------- | ------ | -------- | ------------------------------------- |
| email     | string | Yes      | Email address of the user to retrieve |

---

## Successful Response

### HTTP Status Code

```http id="ok200"
200 OK
```

### Response Body

```json id="resp_user"
{
  "user_id": 1,
  "name": "Doe",
  "firstname": "John",
  "email": "john.doe@example.com",
  "registration_date": "2025-01-01T12:00:00Z",
  "role_id": 2,
  "config_id": 5
}
```

### Response Fields

| Field             | Type              | Description                   |
| ----------------- | ----------------- | ----------------------------- |
| user_id           | integer           | Unique user identifier        |
| name              | string            | Last name                     |
| firstname         | string            | First name                    |
| email             | string            | Email address                 |
| registration_date | string (ISO 8601) | Account creation date         |
| role_id           | integer           | User role identifier          |
| config_id         | integer           | User configuration identifier |

---

## Error Responses

### Missing Email Parameter

#### HTTP Status Code

```http id="badreq1"
400 Bad Request
```

```json id="err_email"
{
  "error": "Email required in URL"
}
```

---

### User Not Found

#### HTTP Status Code

```http id="notfound1"
404 Not Found
```

```json id="err404"
{
  "error": "User not found"
}
```

---

### Internal Server Error

#### HTTP Status Code

```http id="servererr1"
500 Internal Server Error
```

```json id="err500"
{
  "error": "Error while retrieving user"
}
```

---

## Security Notes

* This endpoint is protected by **JWT authentication**
* A valid token must be provided in the `Authorization` header
* Requests without a valid token will be rejected by the authentication middleware

See: **[JWT Authentication section](#authentication---user-login)**

# API Contract — source of truth

Both backends (FastAPI on `fastapi.localhost`, Django REST Framework on `django.localhost`) implement
this contract **identically**: same routes, request/response JSON shapes, status codes, and pagination.
The frontend is written once against this contract and works against either backend unchanged.

- Base path: `/api`
- Auth: JWT in `Authorization: Bearer <access_token>`
- Content type: `application/json`
- Timestamps: ISO 8601 UTC (e.g. `2026-06-13T18:30:00Z`)
- IDs: integers

---

## Conventions

### Pagination
List endpoints accept `?page=<int>` (default 1) and `?page_size=<int>` (default 20, max 100) and return:
```json
{
  "results": [ ... ],
  "page": 1,
  "page_size": 20,
  "total": 137,
  "total_pages": 7
}
```

### Errors
```json
{ "error": { "code": "string_code", "message": "Human readable", "fields": { "field": "msg" } } }
```
`fields` is present only for validation errors (HTTP 422). Common codes: `invalid_credentials`,
`code_invalid`, `code_expired`, `code_max_attempts`, `not_verified`, `already_exists`, `not_found`,
`forbidden`, `unauthenticated`, `rate_limited`, `validation_error`.

---

## Auth

### POST `/api/auth/register`
Create an inactive user and send a verification code to **every** provided contact. At least one of
`email` / `phone` is required.
```json
// request
{ "username": "ada", "email": "ada@example.com", "phone": "+15555550123", "password": "hunter2x!" }
// 201
{ "user_id": 1,
  "challenges": [
    { "challenge_id": 10, "channel": "EMAIL", "destination": "a***@example.com" },
    { "challenge_id": 11, "channel": "SMS",   "destination": "***0123" }
  ] }
```

### POST `/api/auth/verify`
Verify one channel's code. Returns tokens **only once all registered contacts are verified**;
otherwise reports what remains.
```json
// request
{ "challenge_id": 10, "code": "123456" }
// 200 — more contacts still unverified
{ "status": "pending", "remaining": [ { "challenge_id": 11, "channel": "SMS" } ] }
// 200 — all verified (also used for 2FA / passwordless completion)
{ "status": "complete",
  "access": "<jwt>", "refresh": "<jwt>",
  "user": { "id": 1, "username": "ada", "email_verified": true, "phone_verified": true } }
```
Errors: `code_invalid` (400), `code_expired` (400), `code_max_attempts` (429).

### POST `/api/auth/login`
Password step. Validates credentials but issues **no tokens** — returns the user's verified channels
to pick from for the mandatory 2FA code.
```json
// request
{ "identifier": "ada", "password": "hunter2x!" }   // identifier = username | email | phone
// 200
{ "user_id": 1, "channels": [ { "channel": "EMAIL" }, { "channel": "SMS" } ] }
```
Errors: `invalid_credentials` (401), `not_verified` (403, account never finished signup verification).

### POST `/api/auth/login/code`
Passwordless. Identifier must be a **verified** email/phone. Returns channels to pick from.
```json
// request
{ "identifier": "ada@example.com" }
// 200
{ "user_id": 1, "channels": [ { "channel": "EMAIL" }, { "channel": "SMS" } ] }
```

### POST `/api/auth/challenge`
Send a code to the chosen verified channel (used after `login` or `login/code`).
```json
// request
{ "user_id": 1, "channel": "EMAIL", "purpose": "LOGIN_2FA" }  // or "LOGIN_PASSWORDLESS"
// 201
{ "challenge_id": 12, "channel": "EMAIL", "destination": "a***@example.com" }
```
Then complete via `POST /api/auth/verify`.

### POST `/api/auth/resend`
```json
{ "challenge_id": 12 }   // 201 -> { "challenge_id": 13, "channel": "EMAIL", "destination": "a***@example.com" }
```

### POST `/api/auth/refresh`
```json
{ "refresh": "<jwt>" }   // 200 -> { "access": "<jwt>" }
```

### GET `/api/dev/last-code?challenge_id=<id>`  (dev only)
Enabled only when `ENV=dev` / `DEBUG`. Returns the most recent plaintext code for a challenge so the
frontend can auto-fill. **404 in any non-dev environment.**
```json
{ "challenge_id": 12, "code": "123456" }
```

---

## Users

### GET `/api/users/me`
```json
{ "id": 1, "username": "ada", "email": "ada@example.com", "phone": "+15555550123",
  "bio": "Mathematician.", "email_verified": true, "phone_verified": true,
  "followers_count": 12, "following_count": 7, "created_at": "2026-06-01T00:00:00Z" }
```

### GET `/api/users/{username}`
Public profile.
```json
{ "id": 2, "username": "alan", "bio": "Computers.",
  "followers_count": 99, "following_count": 4, "is_following": true,
  "created_at": "2026-06-01T00:00:00Z" }
```

### POST `/api/users/{username}/follow`  → 201 `{ "is_following": true, "followers_count": 100 }`
### DELETE `/api/users/{username}/follow` → 200 `{ "is_following": false, "followers_count": 99 }`

---

## Posts

### GET `/api/posts?scope=all|following&page=&page_size=`
Paginated feed. `scope` default `all`; `following` = posts by users the caller follows.
Each result:
```json
{ "id": 5, "body": "hello world",
  "author": { "id": 2, "username": "alan" },
  "like_count": 3, "comment_count": 1, "liked_by_me": false,
  "created_at": "2026-06-13T18:30:00Z" }
```

### POST `/api/posts`  → 201 (single post object as above)
```json
{ "body": "my first post" }
```

### GET `/api/posts/{id}`  → 200 (single post object)
### DELETE `/api/posts/{id}`  → 204 (author only; else 403)

### POST `/api/posts/{id}/like`   → 201 `{ "liked_by_me": true,  "like_count": 4 }`
### DELETE `/api/posts/{id}/like` → 200 `{ "liked_by_me": false, "like_count": 3 }`

---

## Comments

### GET `/api/posts/{id}/comments?page=&page_size=`  (paginated)
```json
{ "id": 8, "body": "nice", "author": { "id": 1, "username": "ada" },
  "created_at": "2026-06-13T18:35:00Z" }
```
### POST `/api/posts/{id}/comments`  → 201 (single comment object)
```json
{ "body": "great post" }
```

---

## Health

### GET `/api/health`  (unauthenticated) → 200 `{ "status": "ok", "backend": "fastapi" | "django" }`

`backend` lets the frontend display which implementation is serving the current host.

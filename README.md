# social-media-deploy

Orchestrator for the **Social Media Demo** — one Next.js frontend, two interchangeable backends
(FastAPI + Django REST Framework) behind nginx, sharing one Postgres. This repo owns the full-stack
wiring (`docker-compose.yml`, nginx, env templates, scripts) and the cross-cutting docs
([`API_CONTRACT.md`](./API_CONTRACT.md), [`COMPARISON.md`](./COMPARISON.md)).

> **Why two backends?** To build the *same app* twice and learn FastAPI and DRF side by side. Both
> implement [`API_CONTRACT.md`](./API_CONTRACT.md) identically, so the one frontend works against
> either unchanged.

## Architecture

```
                        ┌──────────── nginx (:80) ────────────┐
  browser ─────────────▶│ routes by Host header               │
                        └──────────────────────────────────────┘
   fastapi.localhost  │                                │  django.localhost
        ┌─────────────┘                                └─────────────┐
   /  ▶ frontend-fastapi (Next)        /  ▶ frontend-django (Next)
 /api ▶ backend-fastapi  (FastAPI)   /api ▶ backend-django  (DRF)
        └──────────────┐                                ┌─────────────┘
                       ▼                                ▼
                 ┌──────── db (postgres) ────────┐
                 │ social_fastapi │ social_django │
                 └────────────────────────────────┘
```

`*.localhost` resolves to loopback automatically in modern browsers — no `/etc/hosts` edits needed.

## Prerequisites
- Docker + Docker Compose v2
- git
- The four repos cloned **side by side** in one workspace folder (this repo references its siblings
  via relative paths):
  ```
  social_media_app/
  ├── social-media-deploy/          ← you are here
  ├── social-media-frontend/
  ├── social-media-backend-fastapi/
  └── social-media-backend-django/
  ```

## Repositories
| Repo | GitHub |
|---|---|
| `social-media-deploy` (this one) | https://github.com/nightelf/social-media-deploy |
| `social-media-frontend` | https://github.com/nightelf/social-media-frontend |
| `social-media-backend-fastapi` | https://github.com/nightelf/social-media-backend-fastapi |
| `social-media-backend-django` | https://github.com/nightelf/social-media-backend-django |

## Quick start
```bash
# clone all four side by side into one workspace folder
mkdir social_media_app && cd social_media_app
git clone git@github.com:nightelf/social-media-deploy.git
git clone git@github.com:nightelf/social-media-frontend.git
git clone git@github.com:nightelf/social-media-backend-fastapi.git
git clone git@github.com:nightelf/social-media-backend-django.git

cd social-media-deploy
./scripts/up.sh                 # copies env/*.example -> env/*.env, then docker compose up --build
```
Then seed identical demo data into both backends:
```bash
./scripts/seed-both.sh
```

Open:
- http://fastapi.localhost — Next.js → **FastAPI**
- http://django.localhost — same Next.js → **Django REST Framework**
- API docs: http://fastapi.localhost/docs · http://django.localhost/docs

Demo login: **ada / hunter2x!**

## Where do the 2FA / login codes appear?
The default notifier prints codes to the backend logs:
```bash
docker compose logs -f backend-fastapi   # or backend-django
```
In dev the frontend also auto-fills via `GET /api/dev/last-code` (disabled outside dev).

## Configuration
Compose-time config lives in `env/` (real `*.env` are gitignored; only `*.example` are committed).
Edit a value, then `docker compose up` again. See each `*.example` for the full list. To use real
email/SMS instead of console output, set `NOTIFIER=smtp` or `twilio` and fill the provider vars.

## Ports
nginx (`:80`) is the real entrypoint. These are published only for direct debugging:

| Service | URL |
|---|---|
| FastAPI backend | http://localhost:8001 |
| Django backend  | http://localhost:8002 |
| Next (FastAPI)  | http://localhost:3001 |
| Next (Django)   | http://localhost:3002 |
| Postgres        | localhost:5432 |

## Common commands
```bash
docker compose logs -f <service>     # tail logs
docker compose restart <service>     # restart one service
./scripts/reset.sh                   # stop everything + wipe the DB volume
```

## Troubleshooting
- **`*.localhost` won't resolve** — use a Chromium/Firefox/Safari current version, or add
  `127.0.0.1 fastapi.localhost django.localhost` to `/etc/hosts`.
- **Port already in use** — something else holds `:80`/`:5432`; stop it or change the mapping in
  `docker-compose.yml`.
- **Frontend not hot-reloading** — `WATCHPACK_POLLING=true` is set in the frontend env files; ensure
  the repo is mounted (it is via compose volumes).

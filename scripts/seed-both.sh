#!/bin/bash
# Seed identical demo data into both backends.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "seeding Django..."
docker compose exec backend-django python manage.py seed

echo "seeding FastAPI..."
docker compose exec backend-fastapi python -m app.seed

echo "done. demo login: ada / hunter2x!  (codes appear in the backend logs)"

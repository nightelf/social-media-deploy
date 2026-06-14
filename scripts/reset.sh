#!/bin/bash
# Tear everything down and delete the database volume (full reset).
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose down -v
echo "stack stopped and pgdata volume removed."

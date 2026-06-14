#!/bin/bash
# Bring up the whole stack. Copies any missing env files from their .example templates first.
set -euo pipefail
cd "$(dirname "$0")/.."

for ex in env/*.example; do
  target="${ex%.example}"
  if [ ! -f "$target" ]; then
    echo "creating $target from template (review secrets before production use)"
    cp "$ex" "$target"
  fi
done

docker compose up --build "$@"

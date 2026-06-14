#!/bin/bash
# Runs once on first Postgres boot (mounted into /docker-entrypoint-initdb.d/).
# Creates the extra databases listed in EXTRA_DATABASES (comma-separated), each owned by POSTGRES_USER.
set -euo pipefail

create_db() {
  local db="$1"
  echo "  creating database: $db"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-SQL
    SELECT 'CREATE DATABASE "$db"'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db')\gexec
SQL
}

if [ -n "${EXTRA_DATABASES:-}" ]; then
  echo "db-init: creating extra databases: $EXTRA_DATABASES"
  IFS=',' read -ra DBS <<< "$EXTRA_DATABASES"
  for db in "${DBS[@]}"; do
    create_db "$(echo "$db" | xargs)"   # xargs trims whitespace
  done
fi

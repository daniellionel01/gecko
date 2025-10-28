#!/bin/sh
set -eu

if [ -n "${DATABASE_URL:-}" ]; then
  goose -dir /app/db/migrations sqlite3 "${DATABASE_URL}" up
fi

exec /app/entrypoint.sh "$@"

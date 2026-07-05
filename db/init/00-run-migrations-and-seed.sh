#!/bin/bash
# Runs automatically once, on first container start, before Postgres
# accepts external connections (standard docker-entrypoint-initdb.d hook).
# Applies migrations first, then seed data, both in filename order.
set -euo pipefail

echo ">> Applying migrations from /migrations"
for f in /migrations/*.sql; do
  echo "   -> $f"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
done

echo ">> Applying seed data from /seed"
for f in /seed/*.sql; do
  echo "   -> $f"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
done

echo ">> Migrations and seed data applied successfully"

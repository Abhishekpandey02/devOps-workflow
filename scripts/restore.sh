#!/bin/bash
# scripts/restore.sh
#
# Restores a backup created by scripts/backup.sh into a FRESH database
# (dropped and recreated) inside the running "db" Docker Compose service,
# then runs a quick verification query.
#
# Usage:
#   ./scripts/restore.sh                        # restores the most recent backup
#   ./scripts/restore.sh backups/bookings_20260101_120000.dump

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/backups"

COMPOSE_SERVICE="db"
DB_USER="${DB_USER:-app_user}"
# Restore into a separate database name so this can be run safely without
# clobbering the primary "bookings" database, and so it clearly proves the
# dump can rebuild a database from scratch.
RESTORE_DB_NAME="${RESTORE_DB_NAME:-bookings_restore_test}"

BACKUP_FILE="${1:-}"
if [ -z "$BACKUP_FILE" ]; then
  BACKUP_FILE="$(ls -t "$BACKUP_DIR"/bookings_*.dump 2>/dev/null | head -n 1 || true)"
  if [ -z "$BACKUP_FILE" ]; then
    echo "!! No backup file found in $BACKUP_DIR. Run ./scripts/backup.sh first, or pass a path explicitly."
    exit 1
  fi
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "!! Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo ">> Checking that the database container is running..."
if ! docker compose ps --status running "$COMPOSE_SERVICE" | grep -q "$COMPOSE_SERVICE"; then
  echo "!! The '$COMPOSE_SERVICE' service is not running. Start it with: docker compose up -d"
  exit 1
fi

echo ">> Restoring $BACKUP_FILE into a fresh database: $RESTORE_DB_NAME"

echo "   -> Dropping database if it already exists"
docker compose exec -T "$COMPOSE_SERVICE" \
  psql --username "$DB_USER" --dbname postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS ${RESTORE_DB_NAME};"

echo "   -> Creating fresh database"
docker compose exec -T "$COMPOSE_SERVICE" \
  psql --username "$DB_USER" --dbname postgres -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE ${RESTORE_DB_NAME};"

echo "   -> Copying backup file into the container"
docker compose cp "$BACKUP_FILE" "$COMPOSE_SERVICE":/tmp/restore.dump

echo "   -> Running pg_restore"
docker compose exec -T "$COMPOSE_SERVICE" \
  pg_restore --username "$DB_USER" --dbname "$RESTORE_DB_NAME" --no-owner --clean --if-exists /tmp/restore.dump

docker compose exec -T "$COMPOSE_SERVICE" rm -f /tmp/restore.dump

echo ">> Restore complete. Verifying..."

BOOKING_COUNT=$(docker compose exec -T "$COMPOSE_SERVICE" \
  psql --username "$DB_USER" --dbname "$RESTORE_DB_NAME" -t -A \
  -c "SELECT COUNT(*) FROM hotel_bookings;")

EVENT_COUNT=$(docker compose exec -T "$COMPOSE_SERVICE" \
  psql --username "$DB_USER" --dbname "$RESTORE_DB_NAME" -t -A \
  -c "SELECT COUNT(*) FROM booking_events;")

echo "   -> hotel_bookings rows restored: $BOOKING_COUNT"
echo "   -> booking_events rows restored: $EVENT_COUNT"

if [ "$BOOKING_COUNT" -gt 0 ]; then
  echo ">> SUCCESS: restore verified, ${RESTORE_DB_NAME} contains $BOOKING_COUNT booking rows."
else
  echo "!! WARNING: restore ran but hotel_bookings is empty. Check the backup file."
  exit 1
fi

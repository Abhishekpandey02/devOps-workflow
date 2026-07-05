#!/bin/bash
# scripts/backup.sh
#
# Creates a timestamped custom-format dump of the local hotel_bookings
# database running in the "db" Docker Compose service.
#
# Usage:
#   ./scripts/backup.sh
#
# Output:
#   backups/bookings_YYYYMMDD_HHMMSS.dump

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/backups"

COMPOSE_SERVICE="db"
DB_USER="${DB_USER:-app_user}"
DB_NAME="${DB_NAME:-bookings}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/bookings_${TIMESTAMP}.dump"

mkdir -p "$BACKUP_DIR"

echo ">> Checking that the database container is running..."
if ! docker compose ps --status running "$COMPOSE_SERVICE" | grep -q "$COMPOSE_SERVICE"; then
  echo "!! The '$COMPOSE_SERVICE' service is not running. Start it with: docker compose up -d"
  exit 1
fi

echo ">> Creating backup: $BACKUP_FILE"
docker compose exec -T "$COMPOSE_SERVICE" \
  pg_dump --username "$DB_USER" --dbname "$DB_NAME" --format=custom --file=/tmp/backup.dump

docker compose cp "$COMPOSE_SERVICE":/tmp/backup.dump "$BACKUP_FILE"
docker compose exec -T "$COMPOSE_SERVICE" rm -f /tmp/backup.dump

echo ">> Backup complete: $BACKUP_FILE"
echo ">> Size: $(du -h "$BACKUP_FILE" | cut -f1)"

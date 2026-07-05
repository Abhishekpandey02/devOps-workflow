#!/bin/bash

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: ./scripts/restore.sh <backup_file>"
  exit 1
fi

echo "Dropping database..."
docker exec -i hotel-postgres psql -U postgres -c "DROP DATABASE IF EXISTS hotel_db;"

echo "Creating database..."
docker exec -i hotel-postgres psql -U postgres -c "CREATE DATABASE hotel_db;"

echo "Restoring database..."
cat $BACKUP_FILE | docker exec -i hotel-postgres psql -U postgres hotel_db

echo "Restore completed."
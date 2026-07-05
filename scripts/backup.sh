#!/bin/bash

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=./backups
BACKUP_FILE=$BACKUP_DIR/hotel_db_$TIMESTAMP.sql

mkdir -p $BACKUP_DIR

echo "Starting backup..."

docker exec -t hotel-postgres pg_dump -U postgres hotel_db > $BACKUP_FILE

echo "Backup completed: $BACKUP_FILE"
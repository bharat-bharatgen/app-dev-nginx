#!/bin/bash
# Backup PostgreSQL database from medsum-postgres container
# 2026-02-05 - Bharat Patil - For medsum image 1.8+ (PostgreSQL)

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
POSTGRES_CONTAINER="medsum-postgres"
COMPOSE_DIR="/home/ubuntu/apps-dev/medsum-production"
BACKUP_DIR="$COMPOSE_DIR/db_backup"
REMOTE_BACKUP_DIR="/projects2/data2/app-dev/team-app/amrita_db_backup"

# PostgreSQL credentials (from docker-compose.yml)
POSTGRES_DB="medsum_db"
POSTGRES_USER="medsum_user"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Medsum PostgreSQL Database Backup${NC}"
echo -e "${YELLOW}========================================${NC}"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
    echo -e "${RED}Error: Container '$POSTGRES_CONTAINER' is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL container is running${NC}"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
BACKUP_FILENAME="medsum_db_${TIMESTAMP}.sql.gz"
BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILENAME"

# Perform backup using pg_dump
echo -e "\n${BLUE}Backing up database...${NC}"
if docker exec $POSTGRES_CONTAINER pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > "$BACKUP_FILE"; then
    BACKUP_SIZE=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
    if [ "$BACKUP_SIZE" -gt 0 ]; then
        echo -e "${GREEN}✓ Local backup: $BACKUP_FILE ($(numfmt --to=iec $BACKUP_SIZE))${NC}"

        # Copy to remote backup location via container (has /backup mounted)
        if docker exec $POSTGRES_CONTAINER test -d /backup 2>/dev/null; then
            # Container has /backup mount - use pg_dump directly to container
            if docker exec $POSTGRES_CONTAINER sh -c "pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > /backup/$BACKUP_FILENAME"; then
                echo -e "${GREEN}✓ Remote backup: $REMOTE_BACKUP_DIR/$BACKUP_FILENAME${NC}"
            else
                echo -e "${YELLOW}⚠ Could not write to remote location via container${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ Remote backup skipped: /backup not mounted in container${NC}"
            echo -e "${YELLOW}  Restart postgres container to enable remote backups${NC}"
        fi

        echo -e "\n${GREEN}========================================${NC}"
        echo -e "${GREEN}Backup completed successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        echo -e "${RED}✗ Backup file is empty${NC}"
        rm -f "$BACKUP_FILE"
        exit 1
    fi
else
    echo -e "${RED}✗ Failed to backup database${NC}"
    exit 1
fi

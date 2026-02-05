#!/bin/bash
# Backup SQLite database from running medsum-server container
# 2026-02-05 - Bharat Patil - This is legacy script and needed only for medsum image 1.7 and down 

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SERVICE_NAME="medsum-server"
COMPOSE_DIR="/home/ubuntu/apps-dev/medsum-production"
BACKUP_DIR="$COMPOSE_DIR/db_backup"
REMOTE_BACKUP_DIR="/projects2/data2/app-dev/team-app/amrita_db_backup"
CONTAINER_REMOTE_DIR="/app/db_backup_remote"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Medsum SQLite Database Backup${NC}"
echo -e "${YELLOW}========================================${NC}"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${SERVICE_NAME}$"; then
    echo -e "${RED}Error: Container '$SERVICE_NAME' is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Container is running${NC}"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Get container image version
VERSION=$(docker inspect $SERVICE_NAME --format '{{.Config.Image}}' 2>/dev/null | sed 's/.*://')
if [ -z "$VERSION" ]; then
    VERSION="unknown"
fi

TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
BACKUP_FILENAME="db.sqlite3_${VERSION}_${TIMESTAMP}"
BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILENAME"

# Perform backup
echo -e "\n${BLUE}Backing up database...${NC}"
if docker cp $SERVICE_NAME:/app/db.sqlite3 "$BACKUP_FILE" 2>/dev/null; then
    BACKUP_SIZE=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
    if [ "$BACKUP_SIZE" -gt 0 ]; then
        echo -e "${GREEN}✓ Local backup: $BACKUP_FILE ($(numfmt --to=iec $BACKUP_SIZE))${NC}"

        # Copy to remote backup location via container
        if docker exec $SERVICE_NAME mkdir -p "$CONTAINER_REMOTE_DIR" 2>/dev/null; then
            if docker exec $SERVICE_NAME cp /app/db.sqlite3 "$CONTAINER_REMOTE_DIR/$BACKUP_FILENAME" 2>/dev/null; then
                echo -e "${GREEN}✓ Remote backup: $REMOTE_BACKUP_DIR/$BACKUP_FILENAME${NC}"
            else
                echo -e "${YELLOW}⚠ Could not copy to remote location${NC}"
            fi
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

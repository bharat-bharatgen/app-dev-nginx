#!/bin/bash
# Deploy medsum-server Docker container using docker-compose
# 2026-02-05 - Bharat Patil - For medsum image 1.8+ (PostgreSQL)
# This script pulls the latest image, backs up PostgreSQL, stops the old container, and starts the new one

set -e  # Exit on any error

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_DIR="/home/ubuntu/apps-dev/medsum-production"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
SERVICE_NAME="medsum-server"
POSTGRES_CONTAINER="medsum-postgres"
POSTGRES_DB="medsum_db"
POSTGRES_USER="medsum_user"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Medsum Docker Deployment Script (v1.8+)${NC}"
echo -e "${YELLOW}========================================${NC}"

# Step 1: Verify docker-compose file exists
echo -e "\n${YELLOW}[1/7] Checking docker-compose file...${NC}"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}Error: docker-compose.yml not found at $COMPOSE_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker-compose file found${NC}"

# Step 2: Navigate to compose directory
echo -e "\n${YELLOW}[2/7] Navigating to project directory...${NC}"
cd "$COMPOSE_DIR"
echo -e "${GREEN}✓ Working directory: $(pwd)${NC}"

# Step 3: Pull latest image
echo -e "\n${YELLOW}[3/7] Pulling latest Docker image...${NC}"
docker compose pull
echo -e "${GREEN}✓ Latest image pulled${NC}"

# Step 4: Sync media files from image to mounted volume (via container)
echo -e "\n${YELLOW}[4/7] Syncing media files from image to mounted volume...${NC}"
IMAGE_NAME=$(docker compose config 2>/dev/null | grep 'image:' | awk '{print $2}' | grep medsum | head -1)

if [ -n "$IMAGE_NAME" ]; then
    echo -e "${BLUE}Extracting media from: $IMAGE_NAME${NC}"

    # Create temporary container to extract files
    if docker create --name temp-media-sync "$IMAGE_NAME" >/dev/null 2>&1; then

        # Extract media files to temp directory
        if docker cp temp-media-sync:/app/media/. /tmp/medsum-new-media/ 2>/dev/null; then
            echo -e "${BLUE}Media files extracted to temporary location${NC}"

            # Count files extracted
            EXTRACTED_FILES=$(find /tmp/medsum-new-media -type f 2>/dev/null | wc -l)
            echo -e "${BLUE}Files in new image: $EXTRACTED_FILES${NC}"

            echo -e "${BLUE}Files ready for sync after container starts${NC}"
        else
            echo -e "${YELLOW}⚠ Could not extract media files from image${NC}"
            EXTRACTED_FILES=0
        fi

        # Cleanup temporary container
        docker rm temp-media-sync >/dev/null 2>&1 || true
    else
        echo -e "${YELLOW}⚠ Could not create temporary container${NC}"
        EXTRACTED_FILES=0
    fi
else
    echo -e "${YELLOW}⚠ Could not determine image name${NC}"
    EXTRACTED_FILES=0
fi

# Step 5: Backup PostgreSQL database before upgrade
echo -e "\n${YELLOW}[5/7] Backing up PostgreSQL database...${NC}"
BACKUP_DIR="$COMPOSE_DIR/db_backup"
REMOTE_BACKUP_DIR="/projects2/data2/app-dev/team-app/amrita_db_backup"

# Ensure backup directories exist
mkdir -p "$BACKUP_DIR"

# Check if PostgreSQL container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
    echo -e "${YELLOW}⚠ PostgreSQL container not running, skipping backup${NC}"
else
    TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
    BACKUP_FILENAME="medsum_db_pre_deploy_${TIMESTAMP}.sql.gz"
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILENAME"

    # Perform backup using pg_dump
    if docker exec $POSTGRES_CONTAINER pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > "$BACKUP_FILE"; then
        BACKUP_SIZE=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
        if [ "$BACKUP_SIZE" -gt 0 ]; then
            echo -e "${GREEN}✓ Database backed up: $BACKUP_FILENAME ($(numfmt --to=iec $BACKUP_SIZE))${NC}"

            # Copy to remote backup location
            if [ -d "$REMOTE_BACKUP_DIR" ] || mkdir -p "$REMOTE_BACKUP_DIR" 2>/dev/null; then
                if cp "$BACKUP_FILE" "$REMOTE_BACKUP_DIR/$BACKUP_FILENAME" 2>/dev/null; then
                    echo -e "${GREEN}✓ Backup copied to remote: $REMOTE_BACKUP_DIR${NC}"
                else
                    echo -e "${YELLOW}⚠ Could not copy backup to remote location${NC}"
                fi
            fi
        else
            echo -e "${RED}✗ Backup file is empty, removing${NC}"
            rm -f "$BACKUP_FILE"
        fi
    else
        echo -e "${YELLOW}⚠ Could not backup database${NC}"
    fi
fi

# Step 6: Stop and remove old container, start new one
echo -e "\n${YELLOW}[6/7] Restarting containers with new image...${NC}"
docker compose down
docker compose up -d
echo -e "${GREEN}✓ Containers restarted${NC}"

# Step 6.5: Reload nginx to update DNS cache
echo -e "\n${BLUE}Reloading nginx to update DNS cache...${NC}"
if docker exec nginx nginx -s reload 2>/dev/null; then
    echo -e "${GREEN}✓ Nginx reloaded${NC}"
else
    echo -e "${YELLOW}⚠ Could not reload nginx (may not be running)${NC}"
fi

# Step 6.6: Sync media files inside container
if [ "$EXTRACTED_FILES" -gt 0 ] && [ -d "/tmp/medsum-new-media" ]; then
    echo -e "\n${BLUE}Syncing $EXTRACTED_FILES files to container volume...${NC}"

    # Wait for container to be ready
    sleep 5

    # Get the volume mount path from the running container
    VOLUME_PATH=$(docker inspect $SERVICE_NAME --format '{{range .Mounts}}{{if eq .Destination "/app/media"}}{{.Source}}{{end}}{{end}}')

    if [ -n "$VOLUME_PATH" ]; then
        # Use instrumentisto/rsync image to sync files
        docker run --rm \
            -v /tmp/medsum-new-media:/source:ro \
            -v "$VOLUME_PATH":/destination \
            instrumentisto/rsync \
            rsync -av --ignore-existing /source/ /destination/ 2>&1 | tail -1

        # Count total files
        TOTAL_FILES=$(docker exec $SERVICE_NAME sh -c 'find /app/media -type f | wc -l' 2>/dev/null)
        echo -e "${GREEN}✓ Media sync complete. Total files: $TOTAL_FILES${NC}"
    else
        echo -e "${YELLOW}⚠ Could not determine volume path, skipping media sync${NC}"
    fi

    # Cleanup host temp directory
    rm -rf /tmp/medsum-new-media
fi

# Step 7: Verify containers are running
echo -e "\n${YELLOW}[7/7] Verifying container status...${NC}"
sleep 5  # Give container time to start

# Check medsum-server
if docker ps | grep -q "$SERVICE_NAME"; then
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$SERVICE_NAME")
    echo -e "${GREEN}✓ medsum-server is running (Status: $CONTAINER_STATUS)${NC}"
else
    echo -e "${RED}✗ medsum-server is not running!${NC}"
    docker logs "$SERVICE_NAME" 2>&1 | tail -20
    exit 1
fi

# Check medsum-postgres
if docker ps | grep -q "$POSTGRES_CONTAINER"; then
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$POSTGRES_CONTAINER")
    echo -e "${GREEN}✓ medsum-postgres is running (Status: $CONTAINER_STATUS)${NC}"
else
    echo -e "${RED}✗ medsum-postgres is not running!${NC}"
    exit 1
fi

# Show container info
echo -e "\n${BLUE}Container Information:${NC}"
docker ps --filter "name=medsum" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Show recent logs
echo -e "\n${BLUE}Recent medsum-server logs:${NC}"
docker logs --tail 15 "$SERVICE_NAME"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

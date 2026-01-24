#!/bin/bash
# Deploy medsum-server Docker container using docker-compose
# This script pulls the latest image, stops the old container, and starts the new one

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

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Medsum Docker Deployment Script${NC}"
echo -e "${YELLOW}========================================${NC}"

# Step 1: Verify docker-compose file exists
echo -e "\n${YELLOW}[1/6] Checking docker-compose file...${NC}"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}Error: docker-compose.yml not found at $COMPOSE_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker-compose file found${NC}"

# Step 2: Navigate to compose directory
echo -e "\n${YELLOW}[2/6] Navigating to project directory...${NC}"
cd "$COMPOSE_DIR"
echo -e "${GREEN}✓ Working directory: $(pwd)${NC}"

# Step 3: Pull latest image
echo -e "\n${YELLOW}[3/6] Pulling latest Docker image...${NC}"
docker compose pull
echo -e "${GREEN}✓ Latest image pulled${NC}"

# Step 4: Sync media files from image to mounted volume (via container)
echo -e "\n${YELLOW}[4/6] Syncing media files from image to mounted volume...${NC}"
IMAGE_NAME=$(docker compose config 2>/dev/null | grep 'image:' | awk '{print $2}' | head -1)

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

            # Note: We'll sync after container starts (see step 5.5)
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

# Step 5: Stop and remove old container, start new one
echo -e "\n${YELLOW}[5/6] Restarting container with new image...${NC}"
docker compose down
docker compose up -d
echo -e "${GREEN}✓ Container restarted${NC}"

# Step 5.5: Sync media files inside container (no sudo needed!)
if [ "$EXTRACTED_FILES" -gt 0 ] && [ -d "/tmp/medsum-new-media" ]; then
    echo -e "\n${BLUE}Syncing $EXTRACTED_FILES files to container volume...${NC}"

    # Wait for container to be ready
    sleep 5

    # Use dedicated rsync container to sync files directly to the volume
    # This avoids installing rsync in the application container
    echo -e "${BLUE}Using rsync container to merge files...${NC}"

    # Get the volume mount path from the running container
    VOLUME_PATH=$(docker inspect $SERVICE_NAME --format '{{range .Mounts}}{{if eq .Destination "/app/media"}}{{.Source}}{{end}}{{end}}')

    if [ -n "$VOLUME_PATH" ]; then
        # Use instrumentisto/rsync image to sync files
        # Runs as root, has full write access to the bind mount
        docker run --rm \
            -v /tmp/medsum-new-media:/source:ro \
            -v "$VOLUME_PATH":/destination \
            instrumentisto/rsync \
            rsync -av --ignore-existing /source/ /destination/ 2>&1 | tail -1

        # Count total files
        TOTAL_FILES=$(docker exec $SERVICE_NAME sh -c 'find /app/media -type f | wc -l' 2>/dev/null)
        echo -e "${GREEN}✓ Media sync complete. Total files: $TOTAL_FILES${NC}"
    else
        echo -e "${YELLOW}⚠ Could not determine volume path, falling back to container-based sync...${NC}"

        # Fallback: copy into container and use rsync there
        if docker cp /tmp/medsum-new-media/. $SERVICE_NAME:/tmp/new-media/ 2>/dev/null; then

            # Try to ensure rsync is available in container
            echo -e "${BLUE}Checking for rsync in container...${NC}"
            RSYNC_AVAILABLE=$(docker exec $SERVICE_NAME sh -c '
                if command -v rsync >/dev/null 2>&1; then
                    echo "yes"
                else
                    # Try to install rsync
                    apt-get update -qq && apt-get install -y -qq rsync >/dev/null 2>&1 && echo "installed" || echo "no"
                fi
            ' 2>/dev/null)

            if [ "$RSYNC_AVAILABLE" = "yes" ] || [ "$RSYNC_AVAILABLE" = "installed" ]; then
                echo -e "${GREEN}✓ Rsync is available${NC}"
                docker exec $SERVICE_NAME sh -c '
                    rsync -a --ignore-existing /tmp/new-media/ /app/media/
                    rm -rf /tmp/new-media
                    find /app/media -type f | wc -l
                ' 2>/dev/null | tail -1 | xargs -I {} echo -e "${GREEN}✓ Media sync complete. Total files: {}${NC}"
            else
                echo -e "${RED}✗ Rsync is not available and could not be installed${NC}"
                echo -e "${YELLOW}⚠ CRITICAL: Rsync operation required to safely preserve user uploads${NC}"
                echo -e "${YELLOW}  Using 'cp -n' as fallback has different behavior than 'rsync --ignore-existing'${NC}"
                echo -e ""
                read -p "Do you want to proceed with 'cp -n' fallback? (yes/no): " -r CONFIRM
                echo ""

                if [[ $CONFIRM =~ ^[Yy][Ee][Ss]$ ]] || [[ $CONFIRM =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}Proceeding with cp fallback...${NC}"
                    docker exec $SERVICE_NAME sh -c '
                        cp -rn /tmp/new-media/* /app/media/ 2>/dev/null || true
                        rm -rf /tmp/new-media
                        find /app/media -type f | wc -l
                    ' 2>/dev/null | tail -1 | xargs -I {} echo -e "${YELLOW}⚠ Copy complete (using cp). Total files: {}${NC}"
                else
                    echo -e "${RED}Sync operation aborted by user${NC}"
                    docker exec $SERVICE_NAME sh -c 'rm -rf /tmp/new-media' 2>/dev/null || true
                    echo -e "${YELLOW}Files extracted to /tmp/medsum-new-media/ for manual sync${NC}"
                fi
            fi
        else
            echo -e "${RED}✗ Could not copy files to container${NC}"
        fi
    fi

    # Cleanup host temp directory
    rm -rf /tmp/medsum-new-media
fi

# Step 6: Verify container is running
echo -e "\n${YELLOW}[6/6] Verifying container status...${NC}"
sleep 5  # Give container time to start

if docker ps | grep -q "$SERVICE_NAME"; then
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$SERVICE_NAME")
    CONTAINER_HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' "$SERVICE_NAME")

    echo -e "${GREEN}✓ Container is running${NC}"
    echo -e "${BLUE}  Status: $CONTAINER_STATUS${NC}"
    echo -e "${BLUE}  Health: $CONTAINER_HEALTH${NC}"

    # Show container info
    echo -e "\n${BLUE}Container Information:${NC}"
    docker ps --filter "name=$SERVICE_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    # Show recent logs
    echo -e "\n${BLUE}Recent container logs:${NC}"
    docker logs --tail 20 "$SERVICE_NAME"

    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${RED}Error: Container is not running!${NC}"
    echo -e "${RED}Checking logs:${NC}"
    docker logs "$SERVICE_NAME"
    exit 1
fi

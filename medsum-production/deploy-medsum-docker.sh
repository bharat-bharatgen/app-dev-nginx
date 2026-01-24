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
echo -e "\n${YELLOW}[1/5] Checking docker-compose file...${NC}"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}Error: docker-compose.yml not found at $COMPOSE_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker-compose file found${NC}"

# Step 2: Navigate to compose directory
echo -e "\n${YELLOW}[2/5] Navigating to project directory...${NC}"
cd "$COMPOSE_DIR"
echo -e "${GREEN}✓ Working directory: $(pwd)${NC}"

# Step 3: Pull latest image
echo -e "\n${YELLOW}[3/5] Pulling latest Docker image...${NC}"
docker compose pull
echo -e "${GREEN}✓ Latest image pulled${NC}"

# Step 4: Stop and remove old container, start new one
echo -e "\n${YELLOW}[4/5] Restarting container with new image...${NC}"
docker compose down
docker compose up -d
echo -e "${GREEN}✓ Container restarted${NC}"

# Step 5: Verify container is running
echo -e "\n${YELLOW}[5/5] Verifying container status...${NC}"
sleep 2  # Give container time to start

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

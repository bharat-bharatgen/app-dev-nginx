#!/bin/bash
# Deploy medsum.conf to nginx Docker container
# This script copies the configuration, tests it, and reloads nginx

set -e  # Exit on any error

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting nginx deployment for medsum.conf...${NC}"

# Source and destination paths
SOURCE_CONF="/home/ubuntu/apps-dev/nginx/medsum.conf"
DEST_CONF="/home/ubuntu/style-transfer/nginx/conf.d/medsum.conf"
CONTAINER_NAME="nginx"

# Step 1: Verify source file exists
echo -e "\n${YELLOW}[1/4] Checking source configuration file...${NC}"
if [ ! -f "$SOURCE_CONF" ]; then
    echo -e "${RED}Error: Source file $SOURCE_CONF not found!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Source file found${NC}"

# Step 2: Copy configuration to nginx conf.d directory
echo -e "\n${YELLOW}[2/4] Copying configuration to nginx conf.d directory...${NC}"
cp "$SOURCE_CONF" "$DEST_CONF"
echo -e "${GREEN}✓ Configuration copied${NC}"

# Step 3: Test nginx configuration
echo -e "\n${YELLOW}[3/4] Testing nginx configuration...${NC}"
if docker exec "$CONTAINER_NAME" nginx -t; then
    echo -e "${GREEN}✓ Configuration test passed${NC}"
else
    echo -e "${RED}Error: Configuration test failed!${NC}"
    echo -e "${RED}Please check the configuration and try again.${NC}"
    exit 1
fi

# Step 4: Reload nginx
echo -e "\n${YELLOW}[4/4] Reloading nginx...${NC}"
docker exec "$CONTAINER_NAME" nginx -s reload
echo -e "${GREEN}✓ Nginx reloaded successfully${NC}"

echo -e "\n${GREEN}Deployment completed successfully!${NC}"
echo -e "Configuration deployed: $SOURCE_CONF -> $DEST_CONF"

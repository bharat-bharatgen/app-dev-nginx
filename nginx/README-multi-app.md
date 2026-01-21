# Multi-App Path-Based Routing Guide

## Overview

This guide explains how to host multiple applications under a single domain using path-based routing on `apps.bharatgen.dev`.

## URL Structure

```
https://apps.bharatgen.dev/          → Main app (port 4001)
https://apps.bharatgen.dev/ifsca     → IFSCA app (example: port 5001)
https://apps.bharatgen.dev/mahagpt   → MahaGPT app (example: port 5002)
```

## Configuration File

- **Reference config**: `/home/ubuntu/apps-dev/nginx/apps.conf.multi-app`
- **Active config**: `/home/ubuntu/apps-dev/nginx/apps.conf`
- **Deployed to**: `/home/ubuntu/style-transfer/nginx/conf.d/apps.conf`

## Important: proxy_pass Trailing Slash

The trailing slash in `proxy_pass` is critical:

### Option 1: Strip the prefix path (RECOMMENDED)
```nginx
location /ifsca/ {
    proxy_pass http://backend:5001/;  # ← Note trailing slash
}
```
**Result**:
- Request: `https://apps.bharatgen.dev/ifsca/dashboard`
- Backend receives: `http://backend:5001/dashboard`
- The `/ifsca` prefix is stripped

### Option 2: Keep the prefix path
```nginx
location /ifsca/ {
    proxy_pass http://backend:5001;  # ← No trailing slash
}
```
**Result**:
- Request: `https://apps.bharatgen.dev/ifsca/dashboard`
- Backend receives: `http://backend:5001/ifsca/dashboard`
- The `/ifsca` prefix is kept

## Adding a New App

### Step 1: Identify Backend Details
- Backend host and port (e.g., `10.67.19.153:5003`)
- Path prefix (e.g., `/newapp`)
- Does the backend expect the path prefix or not?

### Step 2: Add Location Block
Edit `/home/ubuntu/apps-dev/nginx/apps.conf`:

```nginx
# New App - /newapp
location /newapp/ {
    proxy_pass http://10.67.19.153:5003/;  # Adjust as needed

    # WebSocket Support
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    # Forwarding headers
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Original-URI $request_uri;

    # Timeout settings
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
    proxy_connect_timeout 60;
}
```

### Step 3: Deploy and Test

```bash
# Copy to Docker nginx
cp /home/ubuntu/apps-dev/nginx/apps.conf /home/ubuntu/style-transfer/nginx/conf.d/apps.conf

# Test configuration
docker exec nginx nginx -t

# Reload nginx (zero downtime)
docker exec nginx nginx -s reload

# Test the new app
curl -k https://localhost/newapp/ -H "Host: apps.bharatgen.dev"
```

## Common Patterns

### Pattern 1: Next.js / React Apps
```nginx
location /myapp/ {
    proxy_pass http://backend:3000/;  # Strip /myapp
    proxy_set_header Host $host;
    # ... other headers
}
```
**Note**: Next.js apps may need `basePath` configured to handle the prefix.

### Pattern 2: Docker Service
```nginx
location /dockerapp/ {
    proxy_pass http://docker-service-name:8080/;  # Use Docker DNS
    # ... other headers
}
```

### Pattern 3: External Service
```nginx
location /external/ {
    proxy_pass http://external-ip:port/;
    # ... other headers
}
```

## Testing Backends

Before adding to nginx config, test if backends are reachable:

```bash
# From host
curl -s http://10.67.19.153:5001/

# From Docker nginx
docker exec nginx curl -s http://10.67.19.153:5001/
```

## Location Block Priority

Nginx processes location blocks in this order:
1. Exact match: `location = /path`
2. Prefix match (longest first): `location /path/`
3. Regular expression: `location ~ pattern`
4. Fallback: `location /`

**Best Practice**: Use specific prefixes (`/ifsca/`, `/mahagpt/`) before the catch-all root `/`.

## Current Configuration

### Active Routes
- `/` → `http://10.67.19.153:4001` (main app)
- `/health` → Health check endpoint

### Planned Routes (examples in apps.conf.multi-app)
- `/ifsca/` → `http://10.67.19.153:5001/` (placeholder)
- `/mahagpt/` → `http://10.67.19.153:5002/` (placeholder)

## WebSocket Support

All location blocks include WebSocket support via:
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

This ensures apps using WebSocket (real-time features) work correctly.

## Troubleshooting

### Issue: 404 Not Found
- Check if location path matches the request path
- Verify trailing slashes are consistent
- Check backend is running and accessible

### Issue: Static assets not loading
- Frontend apps may need `basePath` or `publicPath` configured
- Check if assets are being requested with correct prefix
- Consider using location blocks for static files:
  ```nginx
  location ~* ^/myapp/.*\.(js|css|png|jpg|gif|ico)$ {
      proxy_pass http://backend:3000;
  }
  ```

### Issue: 502 Bad Gateway
- Backend service is not running
- Backend is not reachable from Docker nginx
- Check with: `docker exec nginx curl http://backend:port/`

## Quick Reference Commands

```bash
# Edit config
nano /home/ubuntu/apps-dev/nginx/apps.conf

# Deploy
cp /home/ubuntu/apps-dev/nginx/apps.conf /home/ubuntu/style-transfer/nginx/conf.d/apps.conf

# Test syntax
docker exec nginx nginx -t

# Reload nginx
docker exec nginx nginx -s reload

# View logs
docker logs nginx --tail 50

# Test specific app
curl -k -H "Host: apps.bharatgen.dev" https://localhost/ifsca/
```

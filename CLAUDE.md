# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository manages nginx configurations for multiple bharatgen.dev domains through a **shared Docker nginx container**. Configurations are developed here and deployed to `/home/ubuntu/style-transfer/nginx/conf.d/` where the Docker nginx reads them.

## Critical Architecture Concepts

### Shared Nginx Container
- Docker nginx container is managed by another team (`/home/ubuntu/style-transfer/`)
- Multiple teams share this nginx instance
- **Never modify `/home/ubuntu/style-transfer/nginx/conf.d/default.conf`** (other team's config)
- Always create separate `.conf` files for new domains

### Two-Directory System
```
Source (this repo):    /home/ubuntu/apps-dev/nginx/*.conf
Deployed (Docker):     /home/ubuntu/style-transfer/nginx/conf.d/*.conf
```

Changes flow: Edit source → Copy to deployed → Test → Reload nginx

### Docker Network
- Shared network: `shared-net-vijay` (172.24.0.0/16)
- Gateway: 172.24.0.1
- Services on this network can be reached by Docker service name
- External services (10.67.19.153:*) accessible directly from nginx container

## Common Commands

### Deploy Configuration Changes
```bash
# 1. Edit source config
nano /home/ubuntu/apps-dev/nginx/DOMAIN.conf

# 2. Copy to deployed location
cp /home/ubuntu/apps-dev/nginx/DOMAIN.conf \
   /home/ubuntu/style-transfer/nginx/conf.d/DOMAIN.conf

# 3. ALWAYS test before reload
docker exec nginx nginx -t

# 4. Graceful reload (zero downtime)
docker exec nginx nginx -s reload

# 5. Verify
curl -k -H "Host: DOMAIN.bharatgen.dev" https://localhost/
```

### Docker Service Management
```bash
# Restart medsum-server
cd /home/ubuntu/apps-dev/medsum-production
docker compose restart

# Update to new image version
docker compose pull
docker compose up -d

# View logs
docker logs medsum-server --tail 50 -f

# Check service health
curl http://localhost:8084/
curl -k https://medsum.bharatgen.dev/
```

### Debugging
```bash
# View active nginx config
docker exec nginx nginx -T

# Check nginx logs
docker logs nginx --tail 100

# Test backend reachability from nginx
docker exec nginx curl -s http://SERVICE:PORT/

# List services on Docker network
docker network inspect shared-net-vijay | grep Name
```

## Deployment Safety Protocol

**MANDATORY steps for ANY nginx config change:**

1. ✅ Edit source config in `/home/ubuntu/apps-dev/nginx/`
2. ✅ Copy to `/home/ubuntu/style-transfer/nginx/conf.d/`
3. ✅ **ALWAYS run `docker exec nginx nginx -t`** (catches syntax errors)
4. ✅ Only reload if test passes: `docker exec nginx nginx -s reload`
5. ✅ Verify the change worked

**Never:**
- ❌ Edit files directly in `/home/ubuntu/style-transfer/nginx/conf.d/`
- ❌ Run `docker restart nginx` (causes downtime, use reload instead)
- ❌ Skip the `nginx -t` test step
- ❌ Modify `default.conf` (other team's file)

## Configuration Patterns

### proxy_pass Trailing Slash Behavior
This is **critical** and frequently misunderstood:

**Strip path prefix (recommended):**
```nginx
location /ifsca/ {
    proxy_pass http://backend:4000/;  # ← Trailing slash
}
# Request: /ifsca/dashboard → Backend receives: /dashboard
```

**Keep path prefix:**
```nginx
location /ifsca/ {
    proxy_pass http://backend:4000;  # ← No trailing slash
}
# Request: /ifsca/dashboard → Backend receives: /ifsca/dashboard
```

### Backend Addressing

**Docker service on shared-net-vijay:**
```nginx
proxy_pass http://medsum-server:8000;  # Use service name
```

**External service:**
```nginx
proxy_pass http://10.67.19.153:4000;  # Use IP:port
```

**Host machine service:**
```nginx
proxy_pass http://172.24.0.1:PORT;  # Use gateway IP
```

### SSL Certificate
All domains use the wildcard certificate:
- Path: `/etc/nginx/certs/fullchain1.pem` and `privkey1.pem`
- Covers: `*.bharatgen.dev`
- Expires: March 15, 2026
- No changes needed for new `*.bharatgen.dev` domains

## Current Active Domains

| Domain | Config File | Backend | Type |
|--------|-------------|---------|------|
| medsum.bharatgen.dev | medsum.conf | medsum-server:8000 | GCP Docker image |
| apps.bharatgen.dev/ifsca | apps.conf | 10.67.19.153:4000 | External, path-based |

## Adding New Domains

See `/home/ubuntu/apps-dev/README.md` for:
- Option A: Simple full-domain proxy
- Option B: Path-based routing (multiple apps on one domain)

Key decision: Does the backend expect the path prefix or should nginx strip it?

## File Organization

**Configuration source files:**
- `nginx/apps.conf` - apps.bharatgen.dev
- `nginx/medsum.conf` - medsum.bharatgen.dev
- `nginx/apps.conf.multi-app` - Reference for multi-app setup

**Documentation:**
- `README.md` - Complete setup guide with examples
- `nginx/README-multi-app.md` - Path-based routing guide
- `nginx/ARCHITECTURE.md` - Architecture diagrams
- `nginx-setup-plan.md` - Original implementation plan

**Medsum Production:**
- `medsum-production/docker-compose.yml` - Production medsum service
- Image: `asia-east2-docker.pkg.dev/amrita-body-scan/medsum-repo/medsum:1.3`
- Services: Django (8000) + Flask (8084) in single container
- Volumes: Media, tmp, conversation logs mounted from `/projects2/`

**Legacy Test Server (archived):**
- `test-server.js` - Node.js HTTP/WebSocket test server (no longer in use)
- `Dockerfile` - Node.js 24 Alpine container (replaced by GCP image)
- `docker-compose.yml` - Old test server definition (replaced by medsum-production/)

## WebSocket Support

All nginx configs include WebSocket support. Required headers:
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

Timeout settings for long-lived connections:
```nginx
proxy_read_timeout 86400;  # 24 hours
proxy_send_timeout 86400;
proxy_connect_timeout 60;
```

## When Making Changes

**Before editing any nginx config, ask:**
1. Is this a new domain or modification to existing?
2. Will the backend be a Docker service or external service?
3. Does the backend expect path prefixes or not? (affects trailing slash)
4. Is WebSocket support needed? (yes for most modern apps)

**After making changes:**
1. Always test with `docker exec nginx nginx -t`
2. Check nginx logs after reload: `docker logs nginx --tail 20`
3. Verify the endpoint works: `curl -k -H "Host: DOMAIN" https://localhost/`

**If something breaks:**
1. Check nginx logs: `docker logs nginx --tail 100`
2. Test backend directly: `docker exec nginx curl http://BACKEND/`
3. Verify config syntax: `docker exec nginx nginx -T | grep DOMAIN`
4. Rollback: Copy previous version from source and reload

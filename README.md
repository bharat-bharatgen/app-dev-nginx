# Nginx Setup for bharatgen.dev Domains

This directory contains nginx configurations and documentation for managing multiple domains under bharatgen.dev.

## Quick Reference

### Active Domains
- **medsum.bharatgen.dev** → Docker service `medsum-server:8000` (Production - PostgreSQL)
- **apps.bharatgen.dev/ifsca** → Service at `10.67.19.153:4000`

### Key Files
```
/home/ubuntu/apps-dev/
├── nginx/
│   ├── apps.conf              # apps.bharatgen.dev config
│   ├── medsum.conf            # medsum.bharatgen.dev config
│   ├── apps.conf.multi-app    # Reference: multi-app setup
│   ├── README-multi-app.md    # Guide: path-based routing
│   └── ARCHITECTURE.md        # Architecture diagrams
├── medsum-production/         # Medsum production deployment
│   ├── docker-compose.yml     # medsum-server + PostgreSQL
│   ├── README.md              # Deployment documentation
│   ├── deploy-medsum-docker-v1_8.sh  # Deploy script (v1.8+)
│   └── backup-medsum-db-v1_8.sh      # Backup script (v1.8+)
├── docker-compose.yml         # medsum-test-server
├── Dockerfile                 # Node.js 24 Alpine
├── test-server.js             # Test server code
└── package.json               # Dependencies
```

## Setup Summary

### What We Built

1. **Nginx Configuration Management**
   - Separate configs for each domain in `/home/ubuntu/apps-dev/nginx/`
   - Deployed to Docker nginx at `/home/ubuntu/style-transfer/nginx/conf.d/`
   - Zero disruption to existing services

2. **SSL/HTTPS**
   - Using existing wildcard certificate: `*.bharatgen.dev`
   - Auto HTTP to HTTPS redirect
   - Expires: March 15, 2026

3. **Docker Integration**
   - Test server running in Docker on `shared-net-vijay` network
   - Consistent with existing team infrastructure

---

## How to Add a New Domain

### Option A: Simple Domain (Full Proxy)

**Example**: Route `newdomain.bharatgen.dev` to `http://10.67.19.153:5000`

1. **Create configuration file**:
```bash
nano /home/ubuntu/apps-dev/nginx/newdomain.conf
```

2. **Add this configuration**:
```nginx
# Configuration for newdomain.bharatgen.dev
# Managed by: apps-dev team

# HTTP server - redirects to HTTPS
server {
    listen 80;
    server_name newdomain.bharatgen.dev;

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl;
    server_name newdomain.bharatgen.dev;

    # SSL certificate (wildcard *.bharatgen.dev)
    ssl_certificate /etc/nginx/certs/fullchain1.pem;
    ssl_certificate_key /etc/nginx/certs/privkey1.pem;

    # SSL parameters
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    client_max_body_size 200M;

    # Proxy to backend
    location / {
        proxy_pass http://10.67.19.153:5000;

        # WebSocket Support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Forwarding headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeout settings
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60;
    }

    # Health check
    location /health {
        access_log off;
        return 200 '{"status":"healthy"}';
        add_header Content-Type application/json;
    }
}
```

3. **Deploy**:
```bash
# Copy to Docker nginx
cp /home/ubuntu/apps-dev/nginx/newdomain.conf \
   /home/ubuntu/style-transfer/nginx/conf.d/newdomain.conf

# Test configuration
docker exec nginx nginx -t

# Reload nginx (zero downtime)
docker exec nginx nginx -s reload
```

4. **Verify**:
```bash
curl -k -H "Host: newdomain.bharatgen.dev" https://localhost/
```

---

### Option B: Path-Based Routing (Multiple Apps on One Domain)

**Example**: Add `https://apps.bharatgen.dev/mahagpt` → `http://10.67.19.153:5002`

1. **Edit existing config**:
```bash
nano /home/ubuntu/apps-dev/nginx/apps.conf
```

2. **Add new location block** (before the catch-all `location /`):
```nginx
# MahaGPT App - /mahagpt
location /mahagpt/ {
    proxy_pass http://10.67.19.153:5002/;

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

3. **Deploy**:
```bash
cp /home/ubuntu/apps-dev/nginx/apps.conf \
   /home/ubuntu/style-transfer/nginx/conf.d/apps.conf
docker exec nginx nginx -t
docker exec nginx nginx -s reload
```

4. **Verify**:
```bash
curl -k -H "Host: apps.bharatgen.dev" https://localhost/mahagpt/
```

---

## How to Dockerize a New Service

**Example**: Create a Docker service that nginx can route to

1. **Create Dockerfile**:
```bash
cd /home/ubuntu/apps-dev/myapp
```

```dockerfile
FROM node:24-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --production
COPY . .
EXPOSE 8080
CMD ["node", "server.js"]
```

2. **Create docker-compose.yml**:
```yaml
version: '3.8'

services:
  myapp:
    build: .
    container_name: myapp-service
    restart: unless-stopped
    networks:
      - shared-net-vijay

networks:
  shared-net-vijay:
    external: true
```

3. **Build and start**:
```bash
docker compose up -d --build
```

4. **Update nginx config** to use service name:
```nginx
location / {
    proxy_pass http://myapp-service:8080;
    # ... headers
}
```

5. **Deploy and reload nginx**

---

## Common Operations

### View Active Nginx Config
```bash
docker exec nginx nginx -T
```

### Check Nginx Logs
```bash
docker logs nginx --tail 50
docker logs nginx -f  # Follow logs
```

### Test Backend Connectivity
```bash
# From host
curl -s http://10.67.19.153:4000/

# From Docker nginx
docker exec nginx curl -s http://10.67.19.153:4000/
```

### List Running Services on Network
```bash
docker network inspect shared-net-vijay | grep Name
```

### Restart Docker Service
```bash
cd /home/ubuntu/apps-dev
docker compose restart
```

### View Service Logs
```bash
docker logs medsum-test-server --tail 50
```

---

## Troubleshooting

### Issue: 502 Bad Gateway
**Cause**: Backend service is not reachable

**Fix**:
1. Check if backend is running:
   ```bash
   curl http://10.67.19.153:PORT/
   ```

2. Test from Docker nginx:
   ```bash
   docker exec nginx curl http://BACKEND:PORT/
   ```

3. For Docker services, verify they're on the same network:
   ```bash
   docker network inspect shared-net-vijay
   ```

### Issue: 404 Not Found
**Cause**: Path mismatch or wrong proxy_pass

**Fix**:
1. Check nginx config for the location block
2. Verify `proxy_pass` URL is correct
3. Check if trailing slash matters:
   - `proxy_pass http://backend/;` strips the location path
   - `proxy_pass http://backend;` keeps the location path

### Issue: WebSocket Connection Failed
**Cause**: Missing WebSocket headers

**Fix**: Ensure these headers are in the location block:
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

### Issue: Configuration Test Fails
**Cause**: Syntax error in nginx config

**Fix**:
```bash
# Check which config has error
docker exec nginx nginx -t

# View the problematic config
docker exec nginx cat /etc/nginx/conf.d/FILENAME.conf
```

### Issue: SSL Certificate Error
**Cause**: Certificate expired or missing

**Fix**:
1. Check certificate expiry:
   ```bash
   openssl x509 -in /projects/data/cert/fullchain1.pem -text -noout | grep "Not After"
   ```

2. If expired, contact the team managing SSL certificates

---

## Path Stripping Behavior

Understanding `proxy_pass` trailing slash is critical:

### Strip Path (Recommended)
```nginx
location /ifsca/ {
    proxy_pass http://backend:4000/;  # ← Trailing slash
}
```
- Request: `https://apps.bharatgen.dev/ifsca/dashboard`
- Backend receives: `/dashboard` (path stripped)

### Keep Path
```nginx
location /ifsca/ {
    proxy_pass http://backend:4000;  # ← No trailing slash
}
```
- Request: `https://apps.bharatgen.dev/ifsca/dashboard`
- Backend receives: `/ifsca/dashboard` (path kept)

---

## Network Architecture

```
Internet
   ↓
Docker Nginx (port 443)
   ↓
┌──────────────┬──────────────┬──────────────┐
│              │              │              │
medsum-test    External       External
-server:8084   10.67.19.153   10.67.19.153
(Docker)       :4000          :5002
               (IFSCA)        (Future)
```

### Network Details
- **Docker Network**: `shared-net-vijay` (172.24.0.0/16)
- **Gateway**: 172.24.0.1
- **Nginx Container**: Can reach Docker services by name
- **External Services**: Accessible via IP:port

---

## Security Notes

1. **SSL/TLS**: All traffic encrypted with *.bharatgen.dev certificate
2. **HTTP Redirect**: All HTTP requests redirect to HTTPS
3. **No Info Leakage**: Root paths return 404 (no internal routing info exposed)
4. **Headers**: Client IP preserved via X-Real-IP and X-Forwarded-For
5. **Timeouts**: 24-hour timeouts support long-lived WebSocket connections

---

## Key Decisions Made

1. **Why Docker nginx?**: Already managing other team's services, port 443 exposed
2. **Why separate configs?**: Easy to manage, no conflicts with other team
3. **Why path stripping?**: Most apps expect to run at root path
4. **Why Docker for test server?**: Consistent with infrastructure, easier networking
5. **Why not port 80?**: Docker nginx only exposes port 443, HTTPS-only is fine

---

## Certificate Renewal

**Current Certificate**: `*.bharatgen.dev`
- **Expires**: March 15, 2026
- **Location**: `/projects/data/cert/fullchain1.pem` and `privkey1.pem`

**When it expires**:
1. Coordinate with team managing certificates
2. New certificate should be placed in `/projects/data/cert/`
3. No nginx config changes needed (same wildcard)
4. Just reload nginx: `docker exec nginx nginx -s reload`

---

## Medsum Production

For medsum production deployment details, see [medsum-production/README.md](medsum-production/README.md).

**Quick commands:**
```bash
# Deploy new version
cd /home/ubuntu/apps-dev/medsum-production
./deploy-medsum-docker-v1_8.sh

# Backup database
./backup-medsum-db-v1_8.sh

# View logs
docker logs -f medsum-server
```

---

## Contact

For questions or issues:
- Check [README-multi-app.md](nginx/README-multi-app.md) for detailed multi-app guide
- Check [ARCHITECTURE.md](nginx/ARCHITECTURE.md) for architecture diagrams
- Coordinate with infrastructure team for Docker network changes

---

## Quick Command Reference

```bash
# Deploy config changes
cp /home/ubuntu/apps-dev/nginx/FILE.conf /home/ubuntu/style-transfer/nginx/conf.d/
docker exec nginx nginx -t
docker exec nginx nginx -s reload

# View nginx status
docker ps | grep nginx
docker stats nginx --no-stream

# Test domain
curl -k -H "Host: DOMAIN.bharatgen.dev" https://localhost/PATH

# View logs
docker logs nginx --tail 50
docker logs medsum-test-server --tail 50

# Restart services
docker compose -f /home/ubuntu/apps-dev/docker-compose.yml restart
docker restart nginx  # AVOID - causes downtime
```

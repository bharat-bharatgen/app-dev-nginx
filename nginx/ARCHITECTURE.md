# apps.bharatgen.dev - Multi-App Architecture

## Current Architecture (Single App)

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet / Users                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ HTTPS (443)
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Docker Nginx (nginx container)                 │
│                  apps.bharatgen.dev                          │
│                                                              │
│  Location /    →  proxy_pass http://10.67.19.153:4001      │
│  SSL: *.bharatgen.dev                                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ HTTP
                      ▼
            ┌──────────────────┐
            │  Backend Service │
            │  10.67.19.153    │
            │  Port: 4001      │
            └──────────────────┘
```

## Future Architecture (Multi-App with Path Routing)

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet / Users                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ HTTPS (443)
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Docker Nginx (nginx container)                 │
│                  apps.bharatgen.dev                          │
│                  SSL: *.bharatgen.dev                        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Location Routing                                      │ │
│  │                                                        │ │
│  │  /           → Main App (4001)                        │ │
│  │  /ifsca/     → IFSCA App (5001)                       │ │
│  │  /mahagpt/   → MahaGPT App (5002)                     │ │
│  │  /health     → Health Check                           │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────┬────────────┬────────────┬────────────────────────┘
            │            │            │
            │            │            │ HTTP
            ▼            ▼            ▼
    ┌──────────┐  ┌──────────┐  ┌──────────┐
    │   Main   │  │  IFSCA   │  │ MahaGPT  │
    │   App    │  │   App    │  │   App    │
    │          │  │          │  │          │
    │  :4001   │  │  :5001   │  │  :5002   │
    └──────────┘  └──────────┘  └──────────┘
       10.67.19.153
```

## URL Mapping Examples

### Example 1: User visits IFSCA app

```
User Request:
  https://apps.bharatgen.dev/ifsca/dashboard

Nginx Processing:
  1. Receives HTTPS request on port 443
  2. Matches location /ifsca/
  3. Strips /ifsca prefix (because proxy_pass has trailing /)
  4. Forwards to: http://10.67.19.153:5001/dashboard

Backend Receives:
  GET /dashboard HTTP/1.1
  Host: apps.bharatgen.dev
  X-Real-IP: <client-ip>
  X-Forwarded-For: <client-ip>
  X-Forwarded-Proto: https
  X-Original-URI: /ifsca/dashboard
```

### Example 2: User visits MahaGPT app

```
User Request:
  https://apps.bharatgen.dev/mahagpt/chat

Nginx Processing:
  1. Receives HTTPS request on port 443
  2. Matches location /mahagpt/
  3. Strips /mahagpt prefix
  4. Forwards to: http://10.67.19.153:5002/chat

Backend Receives:
  GET /chat HTTP/1.1
  Host: apps.bharatgen.dev
  X-Original-URI: /mahagpt/chat
```

### Example 3: User visits main app

```
User Request:
  https://apps.bharatgen.dev/

Nginx Processing:
  1. Receives HTTPS request on port 443
  2. Matches location /
  3. Forwards to: http://10.67.19.153:4001/

Backend Receives:
  GET / HTTP/1.1
  Host: apps.bharatgen.dev
```

## Network Topology

```
┌────────────────────────────────────────────────────────────┐
│              Docker Network: shared-net-vijay              │
│                     172.24.0.0/16                          │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │    nginx     │  │ medsum-test  │  │   frontend   │   │
│  │              │  │   -server    │  │              │   │
│  │ 172.24.0.8   │  │              │  │              │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                            │
└────────────────────────────────────────────────────────────┘
                         │
                         │ Gateway: 172.24.0.1
                         │
┌────────────────────────┴────────────────────────────────────┐
│                      Host Machine                           │
│                    10.67.18.206                             │
│                                                             │
│  Apps can reach external services:                         │
│  - 10.67.19.153:4001 (Main app)                            │
│  - 10.67.19.153:5001 (IFSCA app)                           │
│  - 10.67.19.153:5002 (MahaGPT app)                         │
└─────────────────────────────────────────────────────────────┘
```

## File Organization

```
/home/ubuntu/apps-dev/
├── nginx/
│   ├── apps.conf              ← Current active config (single app)
│   ├── apps.conf.multi-app    ← Reference config (multi-app)
│   ├── medsum.conf            ← medsum.bharatgen.dev config
│   ├── README-multi-app.md    ← This guide
│   └── ARCHITECTURE.md        ← Architecture diagrams
│
├── docker-compose.yml         ← medsum-test-server definition
├── Dockerfile                 ← Node.js 24 Alpine image
├── test-server.js             ← Test server code
└── package.json               ← Dependencies

/home/ubuntu/style-transfer/nginx/conf.d/  (Docker nginx configs)
├── default.conf               ← Other team's config
├── apps.conf                  ← Deployed: apps.bharatgen.dev
└── medsum.conf                ← Deployed: medsum.bharatgen.dev
```

## Deployment Workflow

```
┌─────────────────────────────────────────────────┐
│ Step 1: Edit source config                      │
│ /home/ubuntu/apps-dev/nginx/apps.conf           │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ Step 2: Copy to Docker nginx                    │
│ cp to /home/ubuntu/style-transfer/              │
│        nginx/conf.d/apps.conf                   │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ Step 3: Test configuration                      │
│ docker exec nginx nginx -t                      │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ Step 4: Graceful reload                         │
│ docker exec nginx nginx -s reload               │
│ (Zero downtime - active connections continue)   │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ Step 5: Verify                                  │
│ curl -k -H "Host: ..." https://localhost/...   │
└─────────────────────────────────────────────────┘
```

## Security Considerations

1. **SSL/TLS**: All traffic encrypted with wildcard *.bharatgen.dev certificate
2. **HTTP Redirect**: All HTTP requests automatically redirected to HTTPS
3. **Headers**: X-Real-IP and X-Forwarded-For preserve client information
4. **Timeouts**: Long timeouts (24 hours) support WebSocket connections
5. **Isolation**: Each app is isolated by path prefix

## Scalability

This architecture supports:
- ✅ Multiple apps under one domain
- ✅ Independent deployment of each app
- ✅ Different technologies per app (Next.js, Django, Go, etc.)
- ✅ WebSocket support for all apps
- ✅ Easy addition of new apps (just add location block)
- ✅ Apps can be on different hosts/ports

## Migration Plan (When Adding Multi-App Support)

**Phase 1: Preparation**
1. Identify backend services and ports
2. Test backend reachability from nginx container
3. Decide on URL paths (/ifsca, /mahagpt, etc.)

**Phase 2: Configuration**
1. Copy `apps.conf.multi-app` to `apps.conf`
2. Update proxy_pass URLs with actual backends
3. Adjust trailing slashes based on app requirements

**Phase 3: Deployment**
1. Deploy updated config to Docker nginx
2. Test configuration syntax
3. Reload nginx (zero downtime)
4. Verify each app individually

**Phase 4: Testing**
1. Test each app's main page
2. Test navigation within each app
3. Test WebSocket features (if applicable)
4. Verify static assets load correctly

# Nginx Setup Plan for medsum.bharatgen.dev

## Overview
- **Current Domain**: medsum.bharatgen.dev → localhost:8084
- **Future Domain**: apps.bharatgen.dev (planned)
- **Config Location**: /home/ubuntu/apps-dev/nginx/
- **Safety**: Zero disruption to existing services

## Implementation Steps

### 1. Create Test Server
- Create Node.js/Express server on port 8084
- Add WebSocket support for testing
- Include test endpoints for HTTP and WebSocket connections
- Set up as a background service for easy testing
- **Safety**: New service, no conflict with existing ones

### 2. Check Current Setup (Discovery Phase)
- Verify nginx is installed (system-level)
- **Check for Docker nginx containers running**
- List all existing nginx configurations in sites-enabled
- Check which ports are currently in use
- Identify existing domains being served
- **Safety**: Pure read-only operations, no changes

### 3. Analyze Existing Configurations
- Review existing nginx server blocks
- Check for potential domain/port conflicts
- Verify medsum.bharatgen.dev is not already configured
- **Safety**: Ensures we don't override existing configs

### 4. Create Modular Configuration Structure
- Set up `/home/ubuntu/apps-dev/nginx/` directory
- Create separate `medsum.bharatgen.dev.conf`
- Prepare shared snippets for reusability
- **Safety**: New files only, no modification of existing configs

### 5. Create Nginx Configuration for medsum.bharatgen.dev
- Write new standalone config file
- Use unique server_name directive
- Set up reverse proxy to localhost:8084
- **Safety**: Isolated config that doesn't touch existing domains

### 6. Configure WebSocket Support
- Add `Upgrade` and `Connection` headers
- Set appropriate proxy timeouts
- Enable connection keep-alive
- **Safety**: Scoped to medsum.bharatgen.dev only

### 7. Test Configuration Syntax
- Run `nginx -t` to validate syntax
- **Safety**: Test-only, doesn't reload nginx
- If errors found, fix before proceeding

### 8. SSL Certificate Setup
- Install certbot if needed
- Obtain SSL certificate for medsum.bharatgen.dev
- Configure HTTPS (port 443) server block
- Add HTTP to HTTPS redirect
- Update config with SSL settings
- **Safety**: Certbot doesn't reload nginx automatically with standalone mode

### 9. Enable Configuration
- Create symlink from `/home/ubuntu/apps-dev/nginx/` to `/etc/nginx/sites-enabled/`
- Run `nginx -t` again to verify full configuration
- **Safety**: Final validation before any reload

### 10. Graceful Reload
- Use `nginx -s reload` (NOT restart)
- **Safety**: Zero-downtime reload, existing connections maintained
- Active connections continue on old config
- New connections use new config

### 11. Verification
- Test HTTP to HTTPS redirect
- Verify test server responds correctly
- Test WebSocket connections work through nginx
- Verify existing services still work
- Document setup for adding apps.bharatgen.dev later

## Final Directory Structure

```
/home/ubuntu/apps-dev/nginx/
├── medsum.conf (medsum.bharatgen.dev → medsum-test-server:8084 Docker service)
├── apps.conf (apps.bharatgen.dev → 10.67.19.153:4001)
├── medsum.conf.docker (backup/reference)
└── snippets/
    ├── ssl-params.conf (reference only)
    └── websocket-headers.conf (reference only)

/home/ubuntu/style-transfer/nginx/conf.d/
├── default.conf (other team's config)
├── medsum.conf (deployed)
└── apps.conf (deployed)
```

## Deployed Services

### medsum.bharatgen.dev
- **Backend**: Docker service `medsum-test-server:8084`
- **Network**: shared-net-vijay
- **Status**: ✅ Active
- **Features**: HTTPS, WebSocket support
- **SSL**: Wildcard *.bharatgen.dev certificate

### apps.bharatgen.dev
- **Routes**:
  - `/ifsca/` → http://10.67.19.153:4001 (path stripped)
  - `/` → Returns info message
  - `/health` → Health check
- **Status**: ✅ Active
- **Features**: HTTPS, WebSocket support, Path-based routing
- **SSL**: Wildcard *.bharatgen.dev certificate
- **Note**: Path `/ifsca` is stripped before forwarding to backend

## Safety Guarantees

✅ **No service disruption because:**
1. All new configs are in separate files
2. Using `nginx -t` before any reload
3. Using `nginx -s reload` (graceful) instead of restart
4. No modification to existing configuration files
5. New domain only - doesn't touch existing domains
6. Read-only discovery phase before any changes

## Potential Issues to Check

❓ **Items to verify during discovery:**
- If Docker nginx is running on ports 80/443, there will be a conflict
- If medsum.bharatgen.dev is already configured, we'll detect it
- Check for any port conflicts with existing services

## Notes

- This plan ensures zero downtime for existing services
- Modular structure allows easy addition of apps.bharatgen.dev in the future
- All changes are additive, not modifying existing configurations
- Graceful reload maintains active connections

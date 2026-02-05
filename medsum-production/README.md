# Medsum Production Deployment

## Overview
Medsum application deployment using Docker Compose with PostgreSQL database.

## Current Version
- **Medsum Image**: 1.8+ (PostgreSQL)
- **Database**: PostgreSQL 16
- **Network**: shared-net-vijay

## Services
| Service | Container | Port (Host:Container) |
|---------|-----------|----------------------|
| medsum-server | medsum-server | 8084:8000, 8085:8084 |
| medsum-postgres | medsum-postgres | 5433:5432 |

## Directory Structure
```
/home/ubuntu/apps-dev/medsum-production/
├── docker-compose.yml          # Main compose file
├── custom_entrypoint.sh        # Django proxy settings injection
├── django_proxy_settings.py    # HTTPS proxy headers config
├── db_backup/                  # Local database backups
├── backup-medsum-db-v1_8.sh    # PostgreSQL backup script (v1.8+)
├── deploy-medsum-docker-v1_8.sh # Deployment script (v1.8+)
├── backup-medsum-db.sh         # [LEGACY] SQLite backup (v1.7)
├── deploy-medsum-docker.sh     # [LEGACY] SQLite deploy (v1.7)
└── get-logs.sh                 # Log extraction utility
```

## Data Volumes
| Purpose | Host Path |
|---------|-----------|
| PostgreSQL Data | /projects2/data2/app-dev/team-app/amrita_postgres |
| Media Files | /projects2/data2/app-dev/team-app/amrita/media |
| Flask Temp | /projects2/data2/app-dev/team-app/amrita/flask_service/tmp |
| Conversation Logs | /projects2/data2/app-dev/team-app/amrita/conversation_logs |
| DB Backups (Remote) | /projects2/data2/app-dev/team-app/amrita_db_backup |

## Common Commands

### Start Services
```bash
cd /home/ubuntu/apps-dev/medsum-production
docker compose up -d
```

### Stop Services
```bash
docker compose down
```

### View Logs
```bash
docker logs -f medsum-server
docker logs -f medsum-postgres
```

### Backup Database
```bash
./backup-medsum-db-v1_8.sh
```

### Deploy New Version
1. Update image tag in `docker-compose.yml`
2. Run deployment script:
```bash
./deploy-medsum-docker-v1_8.sh
```

### Reload Nginx (after container restart)
```bash
docker exec nginx nginx -s reload
```

## Database Connection
- **Host**: medsum-postgres (internal) or localhost:5433 (external)
- **Database**: medsum_db
- **User**: medsum_user

## URLs
- **Production**: https://medsum.bharatgen.dev/
- **Admin**: https://medsum.bharatgen.dev/admin/

## Migration History
- **2026-02-05**: Migrated from SQLite (v1.7) to PostgreSQL (v1.8)

## Troubleshooting

### 502 Bad Gateway after container restart
Nginx caches DNS. Reload nginx after restarting medsum-server:
```bash
docker exec nginx nginx -s reload
```

### Check database connection
```bash
docker exec medsum-server python manage.py shell -c "from django.db import connection; print(connection.vendor)"
# Expected: postgresql
```

### Verify PostgreSQL is accessible
```bash
docker exec medsum-postgres pg_isready -U medsum_user -d medsum_db
```

#!/bin/bash
set -e

echo "===== Applying Django Proxy Settings ====="

# Append proxy settings import to Django settings.py if not already present
if ! grep -q "django_proxy_settings" /app/medisum/settings.py; then
    echo "" >> /app/medisum/settings.py
    echo "# Import proxy settings for HTTPS behind nginx" >> /app/medisum/settings.py
    echo "try:" >> /app/medisum/settings.py
    echo "    from django_proxy_settings import *" >> /app/medisum/settings.py
    echo "except ImportError:" >> /app/medisum/settings.py
    echo "    pass" >> /app/medisum/settings.py
    echo "Proxy settings added to Django configuration"
else
    echo "Proxy settings already configured"
fi

# Run the original entrypoint
exec /app/entrypoint.sh

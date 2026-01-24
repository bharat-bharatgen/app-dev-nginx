# Django proxy settings for HTTPS behind nginx reverse proxy
# This file configures Django to trust the X-Forwarded-Proto header from nginx

# Trust the X-Forwarded-Proto header from nginx to determine if request is HTTPS
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# Trust the X-Forwarded-Host header
USE_X_FORWARDED_HOST = True

# Optionally, trust X-Forwarded-Port
USE_X_FORWARDED_PORT = True

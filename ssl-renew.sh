#!/bin/bash

# SSL Certificate Renewal Script
# Add this to crontab: 0 12 * * * /path/to/ssl-renew.sh

set -e

# Configuration
COMPOSE_FILE="docker-compose.prod.yml"
LOG_FILE="/var/log/ssl-renew.log"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

cd "$(dirname "$0")"

log "Starting SSL certificate renewal check..."

# Renew certificates
docker-compose -f $COMPOSE_FILE run --rm certbot renew --quiet

# Reload nginx if certificates were renewed
if [ $? -eq 0 ]; then
    log "Reloading nginx configuration..."
    docker-compose -f $COMPOSE_FILE exec nginx nginx -s reload
    log "SSL certificate renewal completed successfully"
else
    log "SSL certificate renewal failed"
    exit 1
fi

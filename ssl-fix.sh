#!/bin/bash

# SSL Fix Script for Production Environment
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Configuration
DOMAIN="new.neyamotenterprise.com"
EMAIL="md@neyamotenterprise.com"

log "Starting SSL certificate fix process..."

# Step 1: Stop all services
log "Stopping all services..."
docker-compose -f docker-compose.prod.yml down

# Step 2: Create necessary directories
log "Creating SSL directories..."
mkdir -p certbot/conf
mkdir -p certbot/www/.well-known/acme-challenge

# Step 3: Use HTTP-only configuration temporarily
log "Setting up HTTP-only nginx configuration..."
if [ -f nginx/conf.d/default.conf ]; then
    cp nginx/conf.d/default.conf nginx/conf.d/default.conf.backup
fi
cp nginx/conf.d/http-only.conf nginx/conf.d/default.conf

# Step 4: Start nginx with HTTP-only config
log "Starting nginx with HTTP-only configuration..."
docker-compose -f docker-compose.prod.yml up -d nginx
sleep 10

# Step 5: Test ACME challenge path
log "Testing ACME challenge accessibility..."
echo "test-challenge-$(date +%s)" > certbot/www/.well-known/acme-challenge/test-challenge

# Wait for nginx to be ready
for i in {1..30}; do
    if curl -f http://$DOMAIN/.well-known/acme-challenge/test-challenge >/dev/null 2>&1; then
        log "ACME challenge path is accessible"
        rm -f certbot/www/.well-known/acme-challenge/test-challenge
        break
    fi
    if [ $i -eq 30 ]; then
        error "ACME challenge path not accessible after 30 attempts. Check DNS and firewall."
    fi
    sleep 2
done

# Step 6: Generate SSL certificate
log "Generating SSL certificate..."
docker-compose -f docker-compose.prod.yml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d $DOMAIN

# Step 7: Verify certificate was created
if [ ! -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
    error "SSL certificate was not created successfully"
fi

log "SSL certificate created successfully"

# Step 8: Restore full SSL configuration
log "Restoring full SSL configuration..."
if [ -f nginx/conf.d/default.conf.backup ]; then
    cp nginx/conf.d/default.conf.backup nginx/conf.d/default.conf
else
    error "Backup configuration not found"
fi

# Step 9: Restart nginx with SSL configuration
log "Restarting nginx with SSL configuration..."
docker-compose -f docker-compose.prod.yml restart nginx

# Step 10: Wait for nginx to be healthy
log "Waiting for nginx to be healthy..."
for i in {1..60}; do
    if docker-compose -f docker-compose.prod.yml ps nginx | grep -q "Up"; then
        log "Nginx is running with SSL configuration"
        break
    fi
    if [ $i -eq 60 ]; then
        warn "Nginx taking longer than expected to start"
    fi
    sleep 2
done

# Step 11: Test HTTPS connectivity
log "Testing HTTPS connectivity..."
sleep 5
if curl -f -k https://$DOMAIN >/dev/null 2>&1; then
    log "✅ HTTPS is working correctly"
else
    warn "HTTPS test failed, but certificate is installed. Check nginx logs."
fi

# Step 12: Start certbot for auto-renewal
log "Starting certbot for auto-renewal..."
docker-compose -f docker-compose.prod.yml up -d certbot

log "🎉 SSL setup completed successfully!"
log "Your site should now be accessible at: https://$DOMAIN"
log ""
log "To check status: docker-compose -f docker-compose.prod.yml ps"
log "To view logs: docker-compose -f docker-compose.prod.yml logs nginx"

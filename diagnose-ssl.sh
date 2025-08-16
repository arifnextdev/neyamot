#!/bin/bash

# SSL Diagnostic and Fix Script
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
}

DOMAIN="new.neyamotenterprise.com"

log "🔍 Diagnosing SSL/HTTPS connectivity issues..."

# Check 1: Nginx container status
log "Checking nginx container status..."
docker-compose -f docker-compose.prod.yml ps nginx

# Check 2: Nginx logs
log "Checking nginx logs for errors..."
docker-compose -f docker-compose.prod.yml logs --tail=20 nginx

# Check 3: SSL certificate files
log "Checking SSL certificate files..."
if [ -d "certbot/conf/live/$DOMAIN" ]; then
    log "✅ SSL certificate directory exists"
    ls -la certbot/conf/live/$DOMAIN/
else
    error "❌ SSL certificate directory not found"
    log "SSL certificates need to be generated first"
fi

# Check 4: Nginx configuration
log "Checking nginx configuration syntax..."
docker-compose -f docker-compose.prod.yml exec nginx nginx -t || warn "Nginx configuration has errors"

# Check 5: Port accessibility
log "Checking if ports 80 and 443 are accessible..."
netstat -tlnp | grep -E ':80|:443' || warn "Ports may not be properly bound"

# Check 6: Domain resolution
log "Checking domain resolution..."
dig +short $DOMAIN || warn "Domain resolution failed"

# Check 7: HTTP connectivity (should work)
log "Testing HTTP connectivity..."
curl -I http://$DOMAIN/.well-known/acme-challenge/ || warn "HTTP ACME challenge path not accessible"

log "🔧 Attempting automatic fix..."

# Fix 1: Ensure nginx is using HTTP-only config first
log "Switching to HTTP-only configuration..."
cp nginx/conf.d/http-only.conf nginx/conf.d/default.conf
docker-compose -f docker-compose.prod.yml restart nginx
sleep 5

# Fix 2: Test HTTP connectivity
log "Testing HTTP after config switch..."
if curl -f http://$DOMAIN >/dev/null 2>&1; then
    log "✅ HTTP is working"
else
    error "❌ HTTP still not working - check DNS and firewall"
fi

# Fix 3: Generate SSL certificates if missing
if [ ! -d "certbot/conf/live/$DOMAIN" ]; then
    log "Generating SSL certificates..."
    docker-compose -f docker-compose.prod.yml run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email md@neyamotenterprise.com \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d $DOMAIN
    
    if [ $? -eq 0 ]; then
        log "✅ SSL certificates generated successfully"
    else
        error "❌ SSL certificate generation failed"
        exit 1
    fi
fi

# Fix 4: Switch back to full SSL configuration
log "Switching to full SSL configuration..."
if [ -f "nginx/conf.d/default.conf.backup" ]; then
    cp nginx/conf.d/default.conf.backup nginx/conf.d/default.conf
else
    # Create full SSL config if backup doesn't exist
    cat > nginx/conf.d/default.conf << 'EOF'
# Upstream servers
upstream api_backend {
    server api:3001;
    keepalive 32;
}

upstream web_backend {
    server web:3000;
    keepalive 32;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name new.neyamotenterprise.com;

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all HTTP traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl;
    server_name new.neyamotenterprise.com;
    http2 on;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/new.neyamotenterprise.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/new.neyamotenterprise.com/privkey.pem;
    
    # SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;

    # API routes
    location /api/ {
        proxy_pass http://api_backend/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Next.js app
    location / {
        proxy_pass http://web_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF
fi

# Fix 5: Restart nginx with SSL configuration
log "Restarting nginx with SSL configuration..."
docker-compose -f docker-compose.prod.yml restart nginx

# Fix 6: Wait for nginx to be healthy
log "Waiting for nginx to be healthy..."
for i in {1..30}; do
    if docker-compose -f docker-compose.prod.yml ps nginx | grep -q "Up.*healthy"; then
        log "✅ Nginx is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        warn "Nginx taking longer than expected to be healthy"
        docker-compose -f docker-compose.prod.yml logs --tail=10 nginx
    fi
    sleep 2
done

# Final test
log "🧪 Final connectivity test..."
sleep 5

if curl -f -k https://$DOMAIN >/dev/null 2>&1; then
    log "🎉 HTTPS is now working!"
else
    warn "HTTPS still not working. Check nginx logs:"
    docker-compose -f docker-compose.prod.yml logs --tail=10 nginx
fi

log "Diagnosis and fix attempt completed."

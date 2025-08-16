#!/bin/bash

# Fix nginx configuration issues
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

log "🔧 Fixing nginx configuration issues..."

# Step 1: Stop nginx to fix configuration
log "Stopping nginx..."
docker-compose -f docker-compose.prod.yml stop nginx

# Step 2: Clean up nginx configuration files
log "Cleaning up nginx configuration..."
rm -f nginx/conf.d/default.conf
rm -f nginx/conf.d/default.conf.backup

# Step 3: Create clean HTTP-only configuration
log "Creating clean HTTP-only configuration..."
cat > nginx/conf.d/default.conf << 'EOF'
# HTTP server for SSL certificate generation
server {
    listen 80;
    server_name new.neyamotenterprise.com;

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri $uri/ =404;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Temporary redirect to HTTPS (will be updated after SSL setup)
    location / {
        return 301 https://$server_name$request_uri;
    }
}
EOF

# Step 4: Start nginx with clean configuration
log "Starting nginx with clean configuration..."
docker-compose -f docker-compose.prod.yml up -d nginx

# Step 5: Wait for nginx to be ready
log "Waiting for nginx to be ready..."
sleep 10

# Step 6: Check nginx status
log "Checking nginx status..."
docker-compose -f docker-compose.prod.yml ps nginx

# Step 7: Test nginx configuration
log "Testing nginx configuration..."
docker-compose -f docker-compose.prod.yml exec nginx nginx -t

# Step 8: Check if HTTP is working locally
log "Testing local HTTP connectivity..."
if docker-compose -f docker-compose.prod.yml exec nginx curl -f http://localhost/health >/dev/null 2>&1; then
    log "✅ Local HTTP is working"
else
    warn "Local HTTP test failed"
fi

# Step 9: Check firewall status
log "Checking firewall status..."
if command -v ufw >/dev/null 2>&1; then
    ufw status
elif command -v iptables >/dev/null 2>&1; then
    iptables -L INPUT -n | grep -E '80|443'
else
    warn "Cannot check firewall - install ufw or check iptables manually"
fi

# Step 10: Test external connectivity
log "Testing external HTTP connectivity..."
if curl -f http://new.neyamotenterprise.com/health >/dev/null 2>&1; then
    log "✅ External HTTP is working"
    
    # Step 11: Generate SSL certificates
    log "Generating SSL certificates..."
    docker-compose -f docker-compose.prod.yml run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email md@neyamotenterprise.com \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d new.neyamotenterprise.com
    
    if [ $? -eq 0 ]; then
        log "✅ SSL certificates generated successfully"
        
        # Step 12: Create full SSL configuration
        log "Creating full SSL configuration..."
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
        try_files $uri $uri/ =404;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Redirect all HTTP traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name new.neyamotenterprise.com;

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

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

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
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
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
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF
        
        # Step 13: Restart nginx with SSL configuration
        log "Restarting nginx with SSL configuration..."
        docker-compose -f docker-compose.prod.yml restart nginx
        
        # Step 14: Final test
        sleep 10
        log "Testing HTTPS connectivity..."
        if curl -f -k https://new.neyamotenterprise.com/health >/dev/null 2>&1; then
            log "🎉 HTTPS is now working!"
        else
            warn "HTTPS still not working, check nginx logs"
        fi
    else
        error "SSL certificate generation failed"
    fi
else
    error "External HTTP connectivity failed. Check:"
    echo "1. Domain DNS points to this server: $(curl -s ifconfig.me)"
    echo "2. Firewall allows port 80: sudo ufw allow 80"
    echo "3. No other service using port 80: sudo lsof -i :80"
fi

log "Configuration fix completed."

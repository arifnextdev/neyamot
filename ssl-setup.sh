#!/bin/bash

# Enhanced SSL setup script with validation
set -e

# Configuration
DOMAIN="new.neyamotenterprise.com"
EMAIL="md@neyamotenterprise.com"

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

# Pre-flight checks
validate_domain() {
    log "Validating domain configuration..."
    
    # Check DNS resolution
    if ! dig +short $DOMAIN | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' > /dev/null; then
        error "Domain $DOMAIN does not resolve to an IP address"
    fi
    
    # Get server's public IP
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
    DOMAIN_IP=$(dig +short $DOMAIN | head -n1)
    
    if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
        warn "Domain IP ($DOMAIN_IP) doesn't match server IP ($SERVER_IP)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "Domain validation passed"
}

test_acme_challenge() {
    log "Testing ACME challenge path..."
    
    # Create test file
    mkdir -p certbot/www/.well-known/acme-challenge/
    echo "test-challenge" > certbot/www/.well-known/acme-challenge/test-file
    
    # Start nginx temporarily
    docker-compose -f docker-compose.prod.yml up -d nginx
    sleep 5
    
    # Test challenge path
    if curl -f http://$DOMAIN/.well-known/acme-challenge/test-file 2>/dev/null | grep -q "test-challenge"; then
        log "ACME challenge path working correctly"
    else
        error "ACME challenge path not accessible. Check firewall and DNS."
    fi
    
    # Cleanup
    rm -f certbot/www/.well-known/acme-challenge/test-file
}

setup_ssl_with_retry() {
    log "Setting up SSL certificates with enhanced validation..."
    
    # Step 1: Use HTTP-only config for certificate generation
    log "Switching to HTTP-only nginx configuration..."
    docker-compose -f docker-compose.prod.yml stop nginx
    
    # Backup current config and use HTTP-only version
    cp nginx/conf.d/default.conf nginx/conf.d/default.conf.backup
    cp nginx/conf.d/http-only.conf nginx/conf.d/default.conf
    
    # Start nginx with HTTP-only config
    docker-compose -f docker-compose.prod.yml up -d nginx
    sleep 10
    
    # Step 2: Test ACME challenge path
    log "Testing ACME challenge accessibility..."
    echo "test-challenge-$(date +%s)" > certbot/www/.well-known/acme-challenge/test-challenge
    
    if curl -f http://$DOMAIN/.well-known/acme-challenge/test-challenge >/dev/null 2>&1; then
        log "ACME challenge path accessible"
        rm -f certbot/www/.well-known/acme-challenge/test-challenge
    else
        error "ACME challenge path not accessible. Check firewall and DNS."
    fi
    
    # Step 3: Try SSL certificate generation with dry-run first
    log "Testing certificate generation (dry-run)..."
    if docker-compose -f docker-compose.prod.yml run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        --dry-run \
        -d $DOMAIN; then
        log "Dry-run successful, proceeding with actual certificate..."
    else
        # Restore original config on failure
        cp nginx/conf.d/default.conf.backup nginx/conf.d/default.conf
        error "Dry-run failed. Check domain configuration and try again."
    fi
    
    # Step 4: Generate actual certificate
    log "Generating SSL certificate..."
    docker-compose -f docker-compose.prod.yml run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        -d $DOMAIN
    
    # Step 5: Restore full SSL config and restart nginx
    log "Restoring full SSL configuration..."
    cp nginx/conf.d/default.conf.backup nginx/conf.d/default.conf
    docker-compose -f docker-compose.prod.yml restart nginx
    
    # Wait for nginx to be healthy
    log "Waiting for nginx to be healthy..."
    for i in {1..30}; do
        if docker-compose -f docker-compose.prod.yml ps nginx | grep -q "Up (healthy)"; then
            log "Nginx is healthy"
            break
        fi
        sleep 2
    done
    
    log "SSL certificates configured successfully"
}

# Main execution
case "$1" in
    validate)
        validate_domain
        ;;
    test)
        test_acme_challenge
        ;;
    setup)
        validate_domain
        test_acme_challenge
        setup_ssl_with_retry
        ;;
    *)
        echo "Usage: $0 {validate|test|setup}"
        echo ""
        echo "Commands:"
        echo "  validate - Check domain DNS configuration"
        echo "  test     - Test ACME challenge path"
        echo "  setup    - Full SSL setup with validation"
        exit 1
        ;;
esac

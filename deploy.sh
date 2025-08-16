#!/bin/bash

# Production deployment script for AlphaNet
# Usage: ./deploy.sh [init|update|ssl|backup]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="new.neyamotenterprise.com"
EMAIL="admin@neyamotenterprise.com"

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

check_requirements() {
    log "Checking requirements..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed"
    fi
    
    if [ ! -f ".env" ]; then
        error ".env file not found. Please copy .env.example to .env and configure it."
    fi
    
    log "Requirements check passed"
}

init_deployment() {
    log "Initializing production deployment..."
    
    # Create necessary directories
    mkdir -p certbot/conf certbot/www nginx_logs api_logs
    
    # Set proper permissions
    chmod 755 certbot/conf certbot/www
    
    # Generate strong passwords if not set
    if ! grep -q "POSTGRES_PASSWORD=" .env || grep -q "your_secure_postgres_password" .env; then
        warn "Generating secure database password..."
        POSTGRES_PASS=$(openssl rand -base64 32)
        sed -i "s/your_secure_postgres_password/$POSTGRES_PASS/g" .env
    fi
    
    if ! grep -q "REDIS_PASSWORD=" .env || grep -q "your_redis_password" .env; then
        warn "Generating secure Redis password..."
        REDIS_PASS=$(openssl rand -base64 32)
        sed -i "s/your_redis_password/$REDIS_PASS/g" .env
    fi
    
    if ! grep -q "JWT_SECRET=" .env || grep -q "your_very_secure_jwt_secret_key_here" .env; then
        warn "Generating secure JWT secret..."
        JWT_SECRET=$(openssl rand -base64 64)
        sed -i "s/your_very_secure_jwt_secret_key_here/$JWT_SECRET/g" .env
    fi
    
    log "Initialization complete"
}

setup_ssl() {
    log "Setting up SSL certificates..."
    
    # Start nginx without SSL first
    docker-compose -f docker-compose.prod.yml up -d nginx
    
    # Wait for nginx to be ready
    sleep 10
    
    # Get SSL certificate
    docker-compose -f docker-compose.prod.yml run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        -d $DOMAIN
    
    # Restart nginx with SSL
    docker-compose -f docker-compose.prod.yml restart nginx
    
    log "SSL certificates configured"
}

deploy() {
    log "Starting production deployment..."
    
    # Build and start services
    docker-compose -f docker-compose.prod.yml build --no-cache
    docker-compose -f docker-compose.prod.yml up -d
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    sleep 30
    
    # Run database migrations
    log "Running database migrations..."
    docker-compose -f docker-compose.prod.yml exec api npx prisma migrate deploy
    
    # Generate Prisma client
    docker-compose -f docker-compose.prod.yml exec api npx prisma generate
    
    log "Deployment complete"
}

update_deployment() {
    log "Updating production deployment..."
    
    # Pull latest changes and rebuild
    docker-compose -f docker-compose.prod.yml pull
    docker-compose -f docker-compose.prod.yml build --no-cache
    
    # Restart services with zero downtime
    docker-compose -f docker-compose.prod.yml up -d --force-recreate
    
    log "Update complete"
}

backup_database() {
    log "Creating database backup..."
    
    BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
    
    docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres alphanet_db > $BACKUP_FILE
    
    log "Database backup created: $BACKUP_FILE"
}

show_status() {
    log "Checking deployment status..."
    
    docker-compose -f docker-compose.prod.yml ps
    
    echo ""
    log "Health check:"
    curl -f https://$DOMAIN/api/health || warn "Health check failed"
}

case "$1" in
    init)
        check_requirements
        init_deployment
        deploy
        setup_ssl
        show_status
        ;;
    update)
        check_requirements
        update_deployment
        show_status
        ;;
    ssl)
        setup_ssl
        ;;
    backup)
        backup_database
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {init|update|ssl|backup|status}"
        echo ""
        echo "Commands:"
        echo "  init   - Initialize and deploy for the first time"
        echo "  update - Update existing deployment"
        echo "  ssl    - Setup/renew SSL certificates"
        echo "  backup - Create database backup"
        echo "  status - Check deployment status"
        exit 1
        ;;
esac

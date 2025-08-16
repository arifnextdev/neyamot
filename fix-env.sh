#!/bin/bash

# Fix .env.prod with secure values
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

log "Generating secure environment variables..."

# Generate secure values
DB_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/')
REDIS_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/')
JWT_SECRET=$(openssl rand -base64 32 | tr -d '=+/')
PGADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/')

log "Updating .env.prod with secure values..."

# Update .env.prod with generated values
sed -i "s/your_secure_db_password/$DB_PASSWORD/g" .env.prod
sed -i "s/your_secure_redis_password/$REDIS_PASSWORD/g" .env.prod
sed -i "s/your_very_secure_jwt_secret_key_here_min_32_chars/$JWT_SECRET/g" .env.prod
sed -i "s/your_secure_pgadmin_password/$PGADMIN_PASSWORD/g" .env.prod

log "✅ Environment variables updated successfully!"
log ""
log "Next steps:"
log "1. Update email credentials in .env.prod if needed"
log "2. Update OAuth credentials if using social login"
log "3. Update payment gateway credentials if using bKash"
log "4. Restart services: docker-compose -f docker-compose.prod.yml restart"
log ""
warn "Keep these credentials secure and backed up!"

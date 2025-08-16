#!/bin/bash

# Git Conflict Resolution Script
# Run this on your server to resolve the merge conflict

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

log "Resolving Git merge conflict..."

# Step 1: Backup existing files that are causing conflicts
log "Backing up conflicting files..."
if [ -f ".env" ]; then
    cp .env .env.backup
    log "Backed up .env to .env.backup"
fi

if [ -f "nginx/conf.d/http-only.conf" ]; then
    cp nginx/conf.d/http-only.conf nginx/conf.d/http-only.conf.backup
    log "Backed up http-only.conf"
fi

if [ -f "ssl-setup.sh" ]; then
    cp ssl-setup.sh ssl-setup.sh.backup
    log "Backed up ssl-setup.sh"
fi

# Step 2: Remove the conflicting files
log "Removing conflicting files..."
rm -f .env
rm -f nginx/conf.d/http-only.conf
rm -f ssl-setup.sh

# Step 3: Complete the git pull
log "Completing git pull..."
git pull origin main

# Step 4: Restore your environment file if it existed
if [ -f ".env.backup" ]; then
    log "Restoring your environment configuration..."
    cp .env.backup .env
    log "Environment file restored"
else
    warn "No previous .env found. You'll need to create one from .env.example"
fi

# Step 5: Set executable permissions
log "Setting executable permissions..."
chmod +x deploy.sh
chmod +x ssl-fix.sh
chmod +x ssl-setup.sh

log "✅ Git conflict resolved successfully!"
log ""
log "Next steps:"
log "1. Review your .env file and update if needed"
log "2. Run: ./deploy.sh update"
log ""
log "Your backup files are saved as:"
log "- .env.backup"
log "- nginx/conf.d/http-only.conf.backup" 
log "- ssl-setup.sh.backup"

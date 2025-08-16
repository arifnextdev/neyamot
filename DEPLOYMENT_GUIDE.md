# Production Deployment Guide

## Overview
This guide covers the complete process of pushing your code to GitHub and deploying it on your production server.

## Prerequisites
- GitHub repository set up
- Production server with Docker and Docker Compose installed
- Domain pointing to your server IP
- SSH access to your server

---

## Part 1: Local Development & GitHub Push

### 1. Prepare Your Code for Production

```bash
# Navigate to your project directory
cd /home/ariful-islam/Downloads/alphanet-main\ \(1\)/alphanet-main/apps

# Update .gitignore to exclude sensitive files
echo "
.env
.env.local
.env.prod
.env.staging
node_modules/
dist/
build/
logs/
*.log
.DS_Store
certbot/conf/
postgres_data/
redis_data/
pgadmin_data/
nginx_logs/
api_logs/
" >> .gitignore
```

### 2. Commit and Push to GitHub

```bash
# Initialize git if not already done
git init

# Add all files
git add .

# Commit changes
git commit -m "feat: production deployment setup with SSL configuration"

# Add your GitHub repository as remote
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git

# Push to main branch
git push -u origin main
```

---

## Part 2: Server Deployment

### 1. Connect to Your Server

```bash
# SSH into your production server
ssh root@your-server-ip
# or
ssh your-username@your-server-ip
```

### 2. Install Dependencies (if not already installed)

```bash
# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Git
apt install git -y

# Install curl and other utilities
apt install curl wget nano -y
```

### 3. Clone Your Repository

```bash
# Navigate to your preferred directory
cd /opt

# Clone your repository
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git neyamot-production

# Navigate to the project
cd neyamot-production
```

### 4. Set Up Environment Variables

```bash
# Copy the example environment file
cp .env.example .env.prod

# Edit the production environment file
nano .env.prod
```

**Update these critical values in `.env.prod`:**
```env
# Database Configuration
DATABASE_URL="postgresql://postgres:YOUR_SECURE_DB_PASSWORD@postgres:5432/alphanet_prod?schema=public"
POSTGRES_PASSWORD=YOUR_SECURE_DB_PASSWORD

# Redis Configuration
REDIS_PASSWORD=YOUR_SECURE_REDIS_PASSWORD

# JWT Configuration
JWT_SECRET=YOUR_VERY_SECURE_JWT_SECRET_MIN_32_CHARS

# Application URLs
API_URL=https://new.neyamotenterprise.com/api
FRONTEND_URL=https://new.neyamotenterprise.com
DOMAIN=new.neyamotenterprise.com

# SSL Configuration
SSL_EMAIL=md@neyamotenterprise.com

# Email Configuration (use your actual SMTP settings)
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USER=your_email@gmail.com
MAIL_PASS=your_app_password

# PgAdmin
PGADMIN_DEFAULT_EMAIL=admin@neyamotenterprise.com
PGADMIN_DEFAULT_PASSWORD=YOUR_SECURE_PGADMIN_PASSWORD
```

### 5. Set Up SSL Certificates

```bash
# Make SSL script executable
chmod +x ssl-fix.sh

# Run SSL setup (this will generate Let's Encrypt certificates)
./ssl-fix.sh
```

### 6. Build and Start Services

```bash
# Build and start all services
docker-compose -f docker-compose.prod.yml up -d --build

# Check service status
docker-compose -f docker-compose.prod.yml ps
```

### 7. Initialize Database

```bash
# Run database migrations (if using Prisma)
docker-compose -f docker-compose.prod.yml exec api npx prisma migrate deploy

# Generate Prisma client
docker-compose -f docker-compose.prod.yml exec api npx prisma generate

# Seed database (if you have seed data)
docker-compose -f docker-compose.prod.yml exec api npx prisma db seed
```

---

## Part 3: Ongoing Deployment Process

### For Future Updates

Create this deployment script on your server:

```bash
# Create deployment script
nano /opt/neyamot-production/deploy.sh
```

Add the deployment script content (see deploy.sh file).

### Usage for Updates

```bash
# On your server, run:
cd /opt/neyamot-production
./deploy.sh
```

---

## Part 4: Monitoring & Maintenance

### Check Service Status
```bash
# View all services
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# View specific service logs
docker-compose -f docker-compose.prod.yml logs -f nginx
docker-compose -f docker-compose.prod.yml logs -f api
```

### SSL Certificate Renewal
SSL certificates will auto-renew via the certbot container. To manually renew:

```bash
docker-compose -f docker-compose.prod.yml exec certbot certbot renew
docker-compose -f docker-compose.prod.yml restart nginx
```

### Backup Database
```bash
# Create backup
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres alphanet_prod > backup_$(date +%Y%m%d_%H%M%S).sql
```

---

## Troubleshooting

### Common Issues

1. **SSL Certificate Issues**
   - Ensure domain points to server IP
   - Check firewall allows ports 80 and 443
   - Run `./ssl-fix.sh` again

2. **Database Connection Issues**
   - Check DATABASE_URL in .env.prod
   - Ensure PostgreSQL container is healthy

3. **Service Not Starting**
   - Check logs: `docker-compose -f docker-compose.prod.yml logs SERVICE_NAME`
   - Verify environment variables

### Useful Commands
```bash
# Restart all services
docker-compose -f docker-compose.prod.yml restart

# Rebuild and restart specific service
docker-compose -f docker-compose.prod.yml up -d --build api

# Clean up unused Docker resources
docker system prune -a

# View resource usage
docker stats
```

---

## Security Checklist

- [ ] Strong passwords for all services
- [ ] Firewall configured (only ports 22, 80, 443 open)
- [ ] SSH key-based authentication
- [ ] Regular security updates
- [ ] Database backups scheduled
- [ ] SSL certificates auto-renewal working
- [ ] Environment variables secured

---

## Support

If you encounter issues:
1. Check the logs first
2. Verify environment variables
3. Ensure all prerequisites are met
4. Check domain DNS configuration

# Neyamot Enterprise Testing Guide

Complete step-by-step testing documentation for local development, staging, and production deployments.

## 📋 Table of Contents

1. [Changes Summary](#changes-summary)
2. [Local Development Testing](#local-development-testing)
3. [Docker Development Testing](#docker-development-testing)
4. [Staging Deployment Testing](#staging-deployment-testing)
5. [Production Deployment Testing](#production-deployment-testing)
6. [CI/CD Pipeline Testing](#cicd-pipeline-testing)
7. [Security Testing](#security-testing)
8. [Performance Testing](#performance-testing)
9. [Troubleshooting](#troubleshooting)

## 🔄 Changes Summary

### Files Created/Modified

#### **Production Configuration Files**
- `docker-compose.prod.yml` - Production Docker Compose with SSL, security, monitoring
- `nginx/nginx.conf` - Production Nginx configuration with security headers
- `nginx/conf.d/default.conf` - SSL-enabled reverse proxy configuration
- `api/Dockerfile` - Multi-stage production-ready API container
- `web/Dockerfile` - Multi-stage production-ready web container
- `web/next.config.js` - Updated for standalone builds and environment variables
- `.env.example` - Complete production environment template
- `deploy.sh` - Automated deployment script with SSL setup
- `ssl-renew.sh` - SSL certificate renewal automation

#### **Staging Configuration Files**
- `docker-compose.staging.yml` - Staging environment configuration
- `nginx/staging.conf` - HTTP-only staging Nginx configuration
- `.env.staging` - Staging environment template

#### **Database & Infrastructure**
- `postgres/init/01-init.sql` - Database initialization with security
- `redis/redis.conf` - Production Redis configuration with security
- `api/src/health/health.controller.ts` - Health check endpoint
- `api/src/health/health.module.ts` - Health check module

#### **CI/CD Pipeline Files**
- `.github/workflows/ci-cd.yml` - Main CI/CD pipeline
- `.github/workflows/staging.yml` - Staging deployment workflow
- `.github/workflows/security.yml` - Security scanning workflow
- `.github/workflows/database-migration.yml` - Database migration workflow
- `sonar-project.properties` - Code quality configuration

#### **Documentation**
- `README.md` - Complete production deployment guide
- `GITHUB_SETUP.md` - GitHub CI/CD setup instructions
- `.dockerignore` - Docker build optimization

#### **Code Changes**
- `api/src/main.ts` - Environment-based CORS configuration
- `api/src/app.module.ts` - Environment-based Redis configuration, Health module
- `api/src/auth/google.strategy.ts` - Environment-based callback URLs
- `api/src/auth/facebook.strategy.ts` - Environment-based callback URLs
- `api/src/auth/auth.controller.ts` - Environment-based redirect URLs
- `api/src/auth/auth.service.ts` - Environment-based reset URLs
- `api/src/bkash/bikash.service.ts` - Environment-based payment URLs
- `api/src/tasks/tasks.processor.ts` - Environment-based Redis configuration
- `web/src/lib/config.ts` - Environment-based API URL

## 🧪 Local Development Testing

### Prerequisites
```bash
# Required software
- Node.js 18+
- Docker & Docker Compose
- Git
```

### Step 1: Setup Local Environment

```bash
# 1. Navigate to project directory
cd /home/ariful-islam/Downloads/alphanet-main\ \(1\)/alphanet-main/apps

# 2. Install API dependencies
cd api
npm install

# 3. Install Web dependencies
cd ../web
npm install
cd ..

# 4. Setup environment file
cp .env.example .env.local

# 5. Edit .env.local with local values
nano .env.local
```

**Local Environment Variables (.env.local):**
```bash
# Database
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/neyamot_dev?schema=public"

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# URLs
API_URL=http://localhost:3001
FRONTEND_URL=http://localhost:3000
DOMAIN=localhost

# JWT
JWT_SECRET=local_jwt_secret_for_development
JWT_EXPIRES_IN=7d
```

### Step 2: Start Local Services

```bash
# 1. Start PostgreSQL and Redis
docker-compose up -d postgres redis-stack

# 2. Wait for services to be ready
sleep 10

# 3. Generate Prisma client
cd api
npx prisma generate

# 4. Run database migrations
npx prisma migrate dev --name init

# 5. Seed database (optional)
npx prisma db seed
```

### Step 3: Start Applications

```bash
# Terminal 1: Start API
cd api
npm run dev

# Terminal 2: Start Web (new terminal)
cd web
npm run dev
```

### Step 4: Test Local Setup

```bash
# 1. Test API health
curl http://localhost:3001/health

# Expected response:
{
  "status": "ok",
  "timestamp": "2025-01-16T05:57:00.000Z",
  "uptime": 123.456,
  "environment": "development",
  "version": "1.0.0",
  "database": "connected"
}

# 2. Test web application
curl http://localhost:3000

# 3. Test API endpoints
curl http://localhost:3001/api/products
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","name":"Test User"}'

# 4. Test database connection
cd api
npx prisma studio
# Opens Prisma Studio at http://localhost:5555
```

## 🐳 Docker Development Testing

### Step 1: Build Development Images

```bash
# 1. Build API image
docker build -t alphanet-api:dev ./api

# 2. Build Web image  
docker build -t alphanet-web:dev ./web

# 3. Test images
docker run --rm alphanet-api:dev node --version
docker run --rm alphanet-web:dev node --version
```

### Step 2: Test with Development Compose

```bash
# 1. Create development compose file
cp docker-compose.yml docker-compose.dev.yml

# 2. Update image references in docker-compose.dev.yml
# Change to use local built images

# 3. Start development stack
docker-compose -f docker-compose.dev.yml up -d

# 4. Check all services are running
docker-compose -f docker-compose.dev.yml ps

# 5. Test health endpoints
curl http://localhost:3001/health
curl http://localhost:3000
```

### Step 3: Test Container Networking

```bash
# 1. Test API to database connection
docker-compose -f docker-compose.dev.yml exec api npx prisma db pull

# 2. Test API to Redis connection
docker-compose -f docker-compose.dev.yml exec api node -e "
const Redis = require('ioredis');
const redis = new Redis({host: 'redis-stack', port: 6379});
redis.ping().then(console.log).catch(console.error);
"

# 3. Test web to API connection
docker-compose -f docker-compose.dev.yml logs web | grep -i "api"
```

## 🎭 Staging Deployment Testing

### Step 1: Prepare Staging Environment

```bash
# 1. Setup staging server (run on staging server)
sudo mkdir -p /opt/neyamot-staging
sudo chown $USER:$USER /opt/neyamot-staging
cd /opt/neyamot-staging

# 2. Clone repository
git clone https://github.com/yourusername/neyamot-enterprise.git .
git checkout develop

# 3. Setup staging environment
cp .env.staging .env

# 4. Edit staging environment variables
nano .env
```

### Step 2: Test Staging Deployment

```bash
# 1. Build staging images
docker-compose -f docker-compose.staging.yml build

# 2. Start staging services
docker-compose -f docker-compose.staging.yml up -d

# 3. Check service status
docker-compose -f docker-compose.staging.yml ps

# 4. Wait for services to be ready
sleep 30

# 5. Run database migrations
docker-compose -f docker-compose.staging.yml exec api npx prisma migrate deploy
```

### Step 3: Test Staging Functionality

```bash
# 1. Test health endpoint
curl http://staging.neyamotenterprise.com/api/health

# 2. Test web application
curl http://staging.neyamotenterprise.com

# 3. Test API endpoints
curl http://staging.neyamotenterprise.com/api/products

# 4. Test authentication
curl -X POST http://staging.neyamotenterprise.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"staging@example.com","password":"password123","name":"Staging User"}'

# 5. Test database connectivity
docker-compose -f docker-compose.staging.yml exec postgres psql -U postgres -d neyamot_staging -c "SELECT COUNT(*) FROM \"User\";"
```

### Step 4: Test Staging Load Balancing

```bash
# 1. Scale API service
docker-compose -f docker-compose.staging.yml up -d --scale api=2

# 2. Test load distribution
for i in {1..10}; do
  curl -s http://staging.neyamotenterprise.com/api/health | jq '.uptime'
  sleep 1
done

# 3. Check Nginx logs
docker-compose -f docker-compose.staging.yml logs nginx
```

## 🚀 Production Deployment Testing

### Step 1: Prepare Production Environment

```bash
# 1. Setup production server (run on production server)
sudo mkdir -p /opt/neyamot-production
sudo chown $USER:$USER /opt/neyamot-production
cd /opt/neyamot-production

# 2. Clone repository
git clone https://github.com/yourusername/neyamot-enterprise.git .

# 3. Setup production environment
cp .env.example .env

# 4. Configure production environment variables
nano .env
# Set all production values including:
# - Strong passwords
# - Production domain
# - SSL email
# - OAuth credentials
# - Payment gateway credentials
```

### Step 2: Test Production Deployment Script

```bash
# 1. Make deploy script executable
chmod +x deploy.sh

# 2. Test deployment script (dry run)
./deploy.sh init

# This will:
# - Check requirements
# - Generate secure passwords
# - Build and start services
# - Setup SSL certificates
# - Run health checks
```

### Step 3: Test SSL Certificate Setup

```bash
# 1. Check SSL certificate
openssl s_client -connect new.neyamotenterprise.com:443 -servername new.neyamotenterprise.com

# 2. Test SSL grade
curl -I https://new.neyamotenterprise.com

# 3. Test HTTP to HTTPS redirect
curl -I http://new.neyamotenterprise.com

# 4. Test SSL renewal
./ssl-renew.sh
```

### Step 4: Test Production Functionality

```bash
# 1. Test HTTPS health endpoint
curl https://new.neyamotenterprise.com/api/health

# 2. Test web application
curl https://new.neyamotenterprise.com

# 3. Test rate limiting
for i in {1..15}; do
  curl -w "%{http_code}\n" -o /dev/null -s https://new.neyamotenterprise.com/api/health
done
# Should show 429 (rate limited) after 10 requests

# 4. Test authentication rate limiting
for i in {1..10}; do
  curl -X POST -w "%{http_code}\n" -o /dev/null -s \
    https://new.neyamotenterprise.com/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"wrong"}'
done
# Should show 429 after 5 attempts
```

### Step 5: Test Production Security

```bash
# 1. Test security headers
curl -I https://new.neyamotenterprise.com

# Should include:
# - Strict-Transport-Security
# - X-Frame-Options: SAMEORIGIN
# - X-XSS-Protection: 1; mode=block
# - X-Content-Type-Options: nosniff

# 2. Test CORS
curl -H "Origin: https://malicious-site.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: X-Requested-With" \
  -X OPTIONS https://new.neyamotenterprise.com/api/health

# 3. Test database access (should fail from outside)
telnet new.neyamotenterprise.com 5432
# Should timeout or be refused
```

## 🔄 CI/CD Pipeline Testing

### Step 1: Test GitHub Actions Locally

```bash
# 1. Install act (GitHub Actions local runner)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# 2. Test workflows locally
act -W .github/workflows/ci-cd.yml --list

# 3. Run specific job
act -j test-api

# 4. Run with secrets
act -j test-api --secret-file .secrets
```

### Step 2: Test CI/CD Pipeline

```bash
# 1. Create feature branch
git checkout -b feature/test-deployment

# 2. Make a small change
echo "# Test change" >> README.md
git add README.md
git commit -m "test: trigger CI/CD pipeline"

# 3. Push to trigger pipeline
git push origin feature/test-deployment

# 4. Create pull request to main
# This will trigger the full CI/CD pipeline

# 5. Monitor GitHub Actions
# Go to GitHub → Actions tab
# Watch the pipeline execution
```

### Step 3: Test Deployment Automation

```bash
# 1. Test staging deployment
git checkout develop
git merge feature/test-deployment
git push origin develop

# This should trigger staging deployment

# 2. Test production deployment
git checkout main
git merge develop
git push origin main

# This should trigger production deployment

# 3. Monitor deployment logs
# Check GitHub Actions logs
# Check server logs: docker-compose -f docker-compose.prod.yml logs
```

## 🔒 Security Testing

### Step 1: Test Container Security

```bash
# 1. Scan images for vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image alphanet-api:latest

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image alphanet-web:latest

# 2. Test container users
docker run --rm alphanet-api:latest whoami
# Should return: nestjs

docker run --rm alphanet-web:latest whoami
# Should return: nextjs

# 3. Test file permissions
docker run --rm alphanet-api:latest ls -la /app
# Should show nestjs:nodejs ownership
```

### Step 2: Test Network Security

```bash
# 1. Test port exposure
nmap -p 1-65535 new.neyamotenterprise.com
# Should only show ports 80 and 443 open

# 2. Test internal network isolation
docker-compose -f docker-compose.prod.yml exec web ping postgres
# Should work (internal network)

# 3. Test external access to internal services
telnet new.neyamotenterprise.com 5432
# Should fail (PostgreSQL not exposed)

telnet new.neyamotenterprise.com 6379
# Should fail (Redis not exposed)
```

### Step 3: Test Application Security

```bash
# 1. Test SQL injection protection
curl -X POST https://new.neyamotenterprise.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com'\''OR 1=1--","password":"test"}'

# 2. Test XSS protection
curl https://new.neyamotenterprise.com/api/health \
  -H "X-Forwarded-For: <script>alert('xss')</script>"

# 3. Test CSRF protection
curl -X POST https://new.neyamotenterprise.com/api/auth/login \
  -H "Origin: https://malicious-site.com" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'
```

## ⚡ Performance Testing

### Step 1: Load Testing

```bash
# 1. Install Apache Bench
sudo apt-get install apache2-utils

# 2. Test API performance
ab -n 1000 -c 10 https://new.neyamotenterprise.com/api/health

# 3. Test web performance
ab -n 100 -c 5 https://new.neyamotenterprise.com/

# 4. Test database performance
docker-compose -f docker-compose.prod.yml exec postgres \
  pgbench -i -s 10 alphanet_db

docker-compose -f docker-compose.prod.yml exec postgres \
  pgbench -c 10 -j 2 -t 1000 alphanet_db
```

### Step 2: Monitor Performance

```bash
# 1. Monitor container resources
docker stats

# 2. Monitor database performance
docker-compose -f docker-compose.prod.yml exec postgres \
  psql -U postgres -d alphanet_db -c "
    SELECT query, calls, total_time, mean_time 
    FROM pg_stat_statements 
    ORDER BY total_time DESC 
    LIMIT 10;"

# 3. Monitor Redis performance
docker-compose -f docker-compose.prod.yml exec redis-stack redis-cli info stats
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. **Container Won't Start**
```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs [service_name]

# Check resource usage
docker system df
docker system prune -f

# Rebuild without cache
docker-compose -f docker-compose.prod.yml build --no-cache
```

#### 2. **Database Connection Issues**
```bash
# Test database connectivity
docker-compose -f docker-compose.prod.yml exec postgres pg_isready

# Check database logs
docker-compose -f docker-compose.prod.yml logs postgres

# Reset database
docker-compose -f docker-compose.prod.yml down -v
docker-compose -f docker-compose.prod.yml up -d postgres
```

#### 3. **SSL Certificate Issues**
```bash
# Check certificate status
docker-compose -f docker-compose.prod.yml logs certbot

# Manual certificate renewal
./ssl-renew.sh

# Check certificate expiry
echo | openssl s_client -servername new.neyamotenterprise.com \
  -connect new.neyamotenterprise.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

#### 4. **Performance Issues**
```bash
# Check container resources
docker stats --no-stream

# Check disk space
df -h

# Clean up Docker
docker system prune -a -f
docker volume prune -f
```

#### 5. **CI/CD Pipeline Failures**
```bash
# Check GitHub Actions logs
# Go to GitHub → Actions → Failed workflow

# Test locally
act -j [job_name]

# Check secrets
# GitHub → Settings → Secrets and variables → Actions
```

### Health Check Commands

```bash
# Complete system health check
./deploy.sh status

# Individual service checks
curl https://new.neyamotenterprise.com/api/health
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml exec postgres pg_isready
docker-compose -f docker-compose.prod.yml exec redis-stack redis-cli ping
```

### Monitoring Commands

```bash
# Real-time logs
docker-compose -f docker-compose.prod.yml logs -f

# Resource monitoring
watch docker stats

# Network monitoring
docker network ls
docker network inspect apps_app_network
```

This comprehensive testing guide covers all aspects of your Neyamot Enterprise deployment from local development to production. Follow each section step-by-step to ensure your application is working correctly at every stage.

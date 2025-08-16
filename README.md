# AlphaNet Production Deployment Guide

A production-ready NestJS API and Next.js web application with Docker, Nginx reverse proxy, and SSL certificates.

## 🏗️ Architecture

- **Frontend**: Next.js 15 with TypeScript and Tailwind CSS
- **Backend**: NestJS with Prisma ORM
- **Database**: PostgreSQL 15
- **Cache**: Redis Stack
- **Reverse Proxy**: Nginx with SSL/TLS
- **Containerization**: Docker & Docker Compose
- **SSL**: Let's Encrypt certificates via Certbot

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Domain name pointing to your server (new.neyamotenterprise.com)
- Server with ports 80 and 443 open

### Initial Deployment

1. **Clone and setup environment**:
   ```bash
   git clone <repository>
   cd apps
   cp .env.example .env
   ```

2. **Configure environment variables**:
   Edit `.env` file with your production values:
   ```bash
   # Update these critical values
   DOMAIN=new.neyamotenterprise.com
   SSL_EMAIL=admin@neyamotenterprise.com
   
   # Database credentials (will be auto-generated if not set)
   POSTGRES_PASSWORD=your_secure_password
   REDIS_PASSWORD=your_redis_password
   JWT_SECRET=your_jwt_secret
   
   # OAuth credentials
   GOOGLE_CLIENT_ID=your_google_client_id
   GOOGLE_CLIENT_SECRET=your_google_client_secret
   
   # Email configuration
   MAIL_HOST=smtp.gmail.com
   MAIL_USER=your_email@gmail.com
   MAIL_PASS=your_app_password
   ```

3. **Deploy**:
   ```bash
   ./deploy.sh init
   ```

This will:
- Generate secure passwords if not provided
- Build and start all services
- Setup SSL certificates
- Run database migrations
- Perform health checks

## 📋 Available Commands

```bash
# Initial deployment
./deploy.sh init

# Update existing deployment
./deploy.sh update

# Setup/renew SSL certificates
./deploy.sh ssl

# Create database backup
./deploy.sh backup

# Check deployment status
./deploy.sh status
```

## 🔧 Manual Operations

### Database Operations

```bash
# Access database
docker-compose -f docker-compose.prod.yml exec postgres psql -U postgres -d alphanet_db

# Run migrations
docker-compose -f docker-compose.prod.yml exec api npx prisma migrate deploy

# Generate Prisma client
docker-compose -f docker-compose.prod.yml exec api npx prisma generate

# Database backup
docker-compose -f docker-compose.prod.yml exec postgres pg_dump -U postgres alphanet_db > backup.sql
```

### Service Management

```bash
# View logs
docker-compose -f docker-compose.prod.yml logs -f [service_name]

# Restart specific service
docker-compose -f docker-compose.prod.yml restart [service_name]

# Scale services
docker-compose -f docker-compose.prod.yml up -d --scale api=2

# Update single service
docker-compose -f docker-compose.prod.yml up -d --no-deps --build api
```

## 🔒 Security Features

### Network Security
- Custom Docker network with subnet isolation
- Services only expose necessary ports
- Database and Redis only accessible internally
- Rate limiting on API endpoints
- Stricter rate limiting on authentication endpoints

### SSL/TLS Configuration
- TLS 1.2 and 1.3 only
- Strong cipher suites
- HSTS headers
- Automatic HTTP to HTTPS redirect

### Application Security
- Non-root users in containers
- Security headers (X-Frame-Options, X-XSS-Protection, etc.)
- CORS properly configured for production domain
- Environment-based configuration
- Secrets management via environment variables

### Database Security
- Strong password authentication (scram-sha-256)
- Connection limits
- Separate application user with limited privileges
- Regular backups

## 📊 Monitoring & Health Checks

### Health Endpoints
- API Health: `https://new.neyamotenterprise.com/api/health`
- Database connectivity check included
- Uptime and environment information

### Container Health Checks
- All services have built-in health checks
- Automatic restart on failure
- Dependency-based startup order

### Logs
- Centralized logging with Docker
- Nginx access and error logs
- Application logs with timestamps
- Redis and PostgreSQL logs

## 🔄 SSL Certificate Management

SSL certificates are automatically managed via Let's Encrypt:

```bash
# Initial setup (done during init)
./deploy.sh ssl

# Renew certificates (setup cron job)
0 12 * * * /path/to/deploy.sh ssl
```

## 🚨 Troubleshooting

### Common Issues

1. **SSL Certificate Issues**:
   ```bash
   # Check certificate status
   docker-compose -f docker-compose.prod.yml logs certbot
   
   # Manually renew
   ./deploy.sh ssl
   ```

2. **Database Connection Issues**:
   ```bash
   # Check database health
   docker-compose -f docker-compose.prod.yml exec postgres pg_isready
   
   # View database logs
   docker-compose -f docker-compose.prod.yml logs postgres
   ```

3. **Application Not Starting**:
   ```bash
   # Check service logs
   docker-compose -f docker-compose.prod.yml logs api
   docker-compose -f docker-compose.prod.yml logs web
   
   # Rebuild containers
   docker-compose -f docker-compose.prod.yml build --no-cache
   ```

### Performance Tuning

1. **Database Optimization**:
   - Adjust PostgreSQL settings in docker-compose.prod.yml
   - Monitor query performance
   - Set up connection pooling

2. **Redis Configuration**:
   - Tune memory settings in redis.conf
   - Monitor cache hit rates
   - Adjust eviction policies

3. **Nginx Optimization**:
   - Enable gzip compression (already configured)
   - Adjust worker processes
   - Fine-tune cache settings

## 📈 Scaling

### Horizontal Scaling
```bash
# Scale API instances
docker-compose -f docker-compose.prod.yml up -d --scale api=3

# Scale web instances
docker-compose -f docker-compose.prod.yml up -d --scale web=2
```

### Load Balancing
Nginx is configured to load balance between multiple instances automatically.

## 🔐 Environment Variables Reference

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `DOMAIN` | Your domain name | Yes | - |
| `SSL_EMAIL` | Email for SSL certificates | Yes | - |
| `DATABASE_URL` | PostgreSQL connection string | Yes | - |
| `POSTGRES_PASSWORD` | Database password | Yes | - |
| `REDIS_PASSWORD` | Redis password | Yes | - |
| `JWT_SECRET` | JWT signing secret | Yes | - |
| `API_URL` | API base URL | Yes | - |
| `FRONTEND_URL` | Frontend base URL | Yes | - |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID | No | - |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret | No | - |
| `MAIL_HOST` | SMTP server host | No | - |
| `MAIL_USER` | SMTP username | No | - |
| `MAIL_PASS` | SMTP password | No | - |

## 📞 Support

For issues and questions:
1. Check the logs using the commands above
2. Review the troubleshooting section
3. Ensure all environment variables are properly set
4. Verify domain DNS settings point to your server

## 🔄 Updates and Maintenance

### Regular Maintenance Tasks
- Monitor disk space and clean up old Docker images
- Review and rotate logs
- Update dependencies regularly
- Monitor SSL certificate expiration
- Backup database regularly
- Review security logs

### Update Process
1. Test changes in development
2. Create database backup
3. Run `./deploy.sh update`
4. Verify deployment with `./deploy.sh status`
5. Monitor logs for any issues

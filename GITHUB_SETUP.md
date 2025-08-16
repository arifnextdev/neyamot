# GitHub CI/CD Setup Guide

This guide will help you set up the complete CI/CD pipeline for your AlphaNet project.

## 🔧 Required GitHub Secrets

### Repository Secrets
Navigate to your GitHub repository → Settings → Secrets and variables → Actions

#### Production Environment Secrets
```
PROD_HOST=your.production.server.ip
PROD_USER=deploy
PROD_SSH_KEY=-----BEGIN OPENSSH PRIVATE KEY-----
...your private key...
-----END OPENSSH PRIVATE KEY-----
```

#### Staging Environment Secrets
```
STAGING_HOST=your.staging.server.ip
STAGING_USER=deploy
STAGING_SSH_KEY=-----BEGIN OPENSSH PRIVATE KEY-----
...your staging private key...
-----END OPENSSH PRIVATE KEY-----
STAGING_PORT=22
```

#### Database Secrets
```
# Production Database
DATABASE_URL=postgresql://user:password@host:5432/database

# Staging Database  
STAGING_DATABASE_URL=postgresql://user:password@host:5432/staging_database
```

#### Notification Secrets
```
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

#### Security Scanning Secrets
```
SONAR_TOKEN=your_sonarcloud_token
GITLEAKS_LICENSE=your_gitleaks_license (optional)
```

## 🏗️ Server Setup

### 1. Production Server Setup

SSH into your production server and run:

```bash
# Create deployment directory
sudo mkdir -p /opt/alphanet-production
sudo chown $USER:$USER /opt/alphanet-production

# Clone repository
cd /opt/alphanet-production
git clone https://github.com/yourusername/alphanet.git .

# Copy environment file
cp .env.example .env
# Edit .env with production values

# Make deploy script executable
chmod +x deploy.sh
```

### 2. Staging Server Setup

```bash
# Create staging directory
sudo mkdir -p /opt/alphanet-staging
sudo chown $USER:$USER /opt/alphanet-staging

# Clone repository
cd /opt/alphanet-staging
git clone https://github.com/yourusername/alphanet.git .

# Copy staging environment file
cp .env.staging .env

# Make scripts executable
chmod +x deploy.sh
```

### 3. SSH Key Setup

Generate SSH keys for deployment:

```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_deploy

# Add public key to authorized_keys on both servers
cat ~/.ssh/github_deploy.pub >> ~/.ssh/authorized_keys

# Copy private key content for GitHub secrets
cat ~/.ssh/github_deploy
```

## 🚀 Workflow Overview

### Main CI/CD Pipeline (`ci-cd.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`

**Jobs:**
1. **test-api** - Run API tests with PostgreSQL and Redis
2. **test-web** - Run web application tests and build
3. **security-scan** - Vulnerability scanning with Trivy
4. **build-and-push** - Build and push Docker images to GitHub Container Registry
5. **deploy-staging** - Deploy to staging (develop branch)
6. **deploy-production** - Deploy to production (main branch)

### Staging Deployment (`staging.yml`)

**Triggers:**
- Push to `develop` branch
- Manual workflow dispatch

**Features:**
- Deploys to staging environment
- HTTP-only configuration
- Slack notifications

### Security Scanning (`security.yml`)

**Triggers:**
- Push to main/develop branches
- Pull requests
- Daily scheduled scan at 2 AM UTC

**Scans:**
- Dependency vulnerabilities
- Container image vulnerabilities
- Code quality analysis
- Secrets detection

### Database Migration (`database-migration.yml`)

**Triggers:**
- Manual workflow dispatch

**Options:**
- Environment: staging/production
- Migration type: deploy/reset/seed

## 🔄 Deployment Flow

### Development to Staging
1. Push code to `develop` branch
2. CI/CD runs tests and security scans
3. Builds and pushes Docker images
4. Deploys to staging server
5. Sends Slack notification

### Staging to Production
1. Create pull request from `develop` to `main`
2. Code review and approval
3. Merge to `main` branch
4. CI/CD runs full test suite
5. Builds production Docker images
6. Deploys to production server
7. Runs health checks
8. Sends deployment notifications

## 📊 Container Registry

Images are pushed to GitHub Container Registry:
- `ghcr.io/yourusername/alphanet/api:latest`
- `ghcr.io/yourusername/alphanet/web:latest`
- `ghcr.io/yourusername/alphanet/api:develop`
- `ghcr.io/yourusername/alphanet/web:develop`

## 🔒 Security Features

### Automated Security Scanning
- **Dependency scanning** - npm audit for known vulnerabilities
- **Container scanning** - Trivy for OS and application vulnerabilities
- **Code quality** - SonarCloud integration
- **Secrets detection** - GitLeaks for exposed secrets

### Security Best Practices
- Non-root containers
- Minimal base images
- Security headers in Nginx
- Rate limiting
- Environment-based secrets

## 🚨 Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   ```bash
   # Test SSH connection
   ssh -i ~/.ssh/github_deploy user@server
   
   # Check SSH key permissions
   chmod 600 ~/.ssh/github_deploy
   ```

2. **Docker Build Failed**
   ```bash
   # Check Dockerfile syntax
   docker build -t test ./api
   docker build -t test ./web
   ```

3. **Database Migration Failed**
   ```bash
   # Check database connection
   npx prisma db pull
   
   # Reset and retry
   npx prisma migrate reset --force
   ```

4. **Health Check Failed**
   ```bash
   # Check service logs
   docker-compose -f docker-compose.prod.yml logs api
   
   # Manual health check
   curl -f https://new.neyamotenterprise.com/api/health
   ```

## 📈 Monitoring

### Health Checks
- API health endpoint: `/api/health`
- Database connectivity check
- Service uptime monitoring

### Notifications
- Slack notifications for deployments
- Email alerts for failed builds
- Security scan results

## 🔧 Customization

### Adding New Environments
1. Create new Docker Compose file
2. Add environment-specific secrets
3. Update workflow files
4. Configure server setup

### Custom Deployment Steps
Edit `.github/workflows/ci-cd.yml` to add:
- Additional testing steps
- Custom build processes
- Integration tests
- Performance tests

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Nginx Configuration Guide](https://nginx.org/en/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## 🆘 Support

For issues with the CI/CD pipeline:
1. Check GitHub Actions logs
2. Verify all secrets are set correctly
3. Test SSH connections manually
4. Review server logs
5. Check Docker container status

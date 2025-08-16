# Server Configuration Guide for Neyamot Enterprise Production

Complete server setup guide for deploying Neyamot Enterprise to production server **103.20.53.236**.

## 📋 Server Information

- **Server IP**: 103.20.53.236
- **Domain**: new.neyamotenterprise.com
- **OS**: Ubuntu 20.04/22.04 LTS (recommended)
- **Architecture**: x86_64

## 🔧 Initial Server Setup

### Step 1: Connect to Server

```bash
# Connect via SSH (replace 'username' with your actual username)
ssh username@103.20.53.236

# Or if using root access
ssh root@103.20.53.236
```

### Step 2: Update System

```bash
# Update package lists
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git vim htop unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release
```

### Step 3: Create Application User

```bash
# Create dedicated user for the application
sudo useradd -m -s /bin/bash neyamot
sudo usermod -aG sudo neyamot

# Set password for the user
sudo passwd neyamot

# Switch to the new user
sudo su - neyamot
```

## 🐳 Docker Installation

### Install Docker Engine

```bash
# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists
sudo apt update

# Install Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker neyamot

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version
docker compose version
```

### Configure Docker (Optional but Recommended)

```bash
# Create Docker daemon configuration
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

# Restart Docker
sudo systemctl restart docker
```

## 🔥 Firewall Configuration

### Configure UFW (Ubuntu Firewall)

```bash
# Enable UFW
sudo ufw enable

# Allow SSH (important - don't lock yourself out!)
sudo ufw allow ssh
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow specific IP for management (optional - replace with your IP)
# sudo ufw allow from YOUR_MANAGEMENT_IP to any port 22

# Check firewall status
sudo ufw status verbose
```

## 📁 Application Directory Setup

### Create Application Directories

```bash
# Create application directory
sudo mkdir -p /opt/neyamot-production
sudo chown neyamot:neyamot /opt/neyamot-production

# Create backup directory
sudo mkdir -p /opt/neyamot-backups
sudo chown neyamot:neyamot /opt/neyamot-backups

# Create SSL certificates directory
sudo mkdir -p /opt/neyamot-ssl
sudo chown neyamot:neyamot /opt/neyamot-ssl

# Switch to application directory
cd /opt/neyamot-production
```

## 🔑 SSH Key Setup for GitHub Actions

### Generate SSH Key for Deployment

```bash
# Generate SSH key pair for deployment
ssh-keygen -t ed25519 -f ~/.ssh/neyamot_deploy -N ""

# Add public key to authorized_keys
cat ~/.ssh/neyamot_deploy.pub >> ~/.ssh/authorized_keys

# Set proper permissions
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/neyamot_deploy
chmod 644 ~/.ssh/neyamot_deploy.pub

# Display private key (copy this to GitHub Secrets)
echo "=== PRIVATE KEY FOR GITHUB SECRETS ==="
cat ~/.ssh/neyamot_deploy
echo "=== END PRIVATE KEY ==="

# Display public key
echo "=== PUBLIC KEY ==="
cat ~/.ssh/neyamot_deploy.pub
echo "=== END PUBLIC KEY ==="
```

## 🌐 Domain Configuration

### Configure DNS Records

**Add these DNS records to your domain provider:**

```
Type: A
Name: new.neyamotenterprise.com
Value: 103.20.53.236
TTL: 300

Type: A  
Name: www.new.neyamotenterprise.com
Value: 103.20.53.236
TTL: 300

Type: CNAME
Name: staging.new.neyamotenterprise.com
Value: new.neyamotenterprise.com
TTL: 300
```

### Verify DNS Propagation

```bash
# Check DNS resolution
nslookup new.neyamotenterprise.com
dig new.neyamotenterprise.com

# Test from external service
# Visit: https://dnschecker.org/#A/new.neyamotenterprise.com
```

## 📦 Deploy Application

### Clone Repository

```bash
# Clone your repository (replace with your actual repository URL)
git clone https://github.com/yourusername/neyamot-enterprise.git /opt/neyamot-production
cd /opt/neyamot-production

# Make sure you're on the main branch
git checkout main
```

### Setup Environment Variables

```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env
```

**Configure these key variables in `.env`:**

```bash
# Domain Configuration
DOMAIN=new.neyamotenterprise.com
API_URL=https://new.neyamotenterprise.com/api
FRONTEND_URL=https://new.neyamotenterprise.com

# Database Configuration
DATABASE_URL="postgresql://neyamot_user:STRONG_DB_PASSWORD@postgres:5432/neyamot_db?schema=public"
POSTGRES_DB=neyamot_db
POSTGRES_USER=neyamot_user
POSTGRES_PASSWORD=STRONG_DB_PASSWORD

# Redis Configuration
REDIS_HOST=redis-stack
REDIS_PORT=6379
REDIS_PASSWORD=STRONG_REDIS_PASSWORD

# JWT Configuration
JWT_SECRET=VERY_STRONG_JWT_SECRET_AT_LEAST_32_CHARACTERS
JWT_EXPIRES_IN=7d

# SSL Configuration
SSL_EMAIL=your-email@example.com

# Generate strong passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 48)
```

### Make Deploy Script Executable

```bash
# Make deployment script executable
chmod +x deploy.sh
chmod +x ssl-renew.sh
```

## 🚀 Initial Deployment

### Run Initial Deployment

```bash
# Run initial deployment (this will setup everything)
./deploy.sh init

# This script will:
# 1. Check system requirements
# 2. Generate secure passwords if not set
# 3. Build Docker images
# 4. Start all services
# 5. Setup SSL certificates with Let's Encrypt
# 6. Run database migrations
# 7. Perform health checks
```

### Verify Deployment

```bash
# Check all services are running
docker compose -f docker-compose.prod.yml ps

# Check application health
curl https://new.neyamotenterprise.com/api/health

# Check web application
curl https://new.neyamotenterprise.com

# Check SSL certificate
curl -I https://new.neyamotenterprise.com
```

## 🔒 Security Hardening

### SSH Security

```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Add/modify these settings:
Port 22
PermitRootLogin no
PasswordAuthentication yes  # Change to 'no' after setting up key-based auth
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

# Restart SSH service
sudo systemctl restart sshd
```

### System Security

```bash
# Install fail2ban for intrusion prevention
sudo apt install -y fail2ban

# Configure fail2ban
sudo tee /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

# Start and enable fail2ban
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

# Check fail2ban status
sudo fail2ban-client status
```

### Automatic Security Updates

```bash
# Install unattended upgrades
sudo apt install -y unattended-upgrades

# Configure automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades

# Edit configuration
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

## 📊 Monitoring Setup

### System Monitoring

```bash
# Install monitoring tools
sudo apt install -y htop iotop nethogs

# Setup log rotation for Docker
sudo tee /etc/logrotate.d/docker <<EOF
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=1M
    missingok
    delaycompress
    copytruncate
}
EOF
```

### Application Monitoring

```bash
# Create monitoring script
tee ~/monitor.sh <<EOF
#!/bin/bash
echo "=== System Status ==="
date
uptime
echo ""

echo "=== Docker Status ==="
docker compose -f /opt/alphanet-production/docker-compose.prod.yml ps
echo ""

echo "=== Application Health ==="
curl -s https://new.neyamotenterprise.com/api/health | jq .
echo ""

echo "=== SSL Certificate Status ==="
echo | openssl s_client -servername new.neyamotenterprise.com -connect new.neyamotenterprise.com:443 2>/dev/null | openssl x509 -noout -dates
echo ""

echo "=== Disk Usage ==="
df -h
echo ""

echo "=== Memory Usage ==="
free -h
EOF

chmod +x ~/monitor.sh

# Run monitoring
./monitor.sh
```

## 🔄 Backup Configuration

### Setup Automated Backups

```bash
# Create backup script
tee ~/backup.sh <<EOF
#!/bin/bash
BACKUP_DIR="/opt/neyamot-backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p \$BACKUP_DIR

# Backup database
docker compose -f /opt/neyamot-production/docker-compose.prod.yml exec -T postgres pg_dump -U neyamot_user neyamot_db > \$BACKUP_DIR/db_backup_\$DATE.sql

# Backup application files
tar -czf \$BACKUP_DIR/app_backup_\$DATE.tar.gz -C /opt/neyamot-production --exclude=node_modules --exclude=.git .

# Keep only last 7 days of backups
find \$BACKUP_DIR -name "*.sql" -mtime +7 -delete
find \$BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: \$DATE"
EOF

chmod +x ~/backup.sh

# Setup cron job for daily backups
(crontab -l 2>/dev/null; echo "0 2 * * * /home/neyamot/backup.sh >> /var/log/backup.log 2>&1") | crontab -
```

## 🔧 SSL Certificate Renewal

### Setup Automatic SSL Renewal

```bash
# Setup cron job for SSL renewal (already created in ssl-renew.sh)
(crontab -l 2>/dev/null; echo "0 3 * * 0 /opt/neyamot-production/ssl-renew.sh >> /var/log/ssl-renew.log 2>&1") | crontab -

# Test SSL renewal
./ssl-renew.sh
```

## 📝 GitHub Actions Configuration

### Required GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

```bash
# Server Connection
PRODUCTION_HOST=103.20.53.236
PRODUCTION_USER=neyamot
PRODUCTION_SSH_KEY=<contents of ~/.ssh/neyamot_deploy private key>

# Environment Variables (copy from your .env file)
PRODUCTION_DATABASE_URL=postgresql://neyamot_user:PASSWORD@postgres:5432/neyamot_db?schema=public
PRODUCTION_JWT_SECRET=<your JWT secret>
PRODUCTION_REDIS_PASSWORD=<your Redis password>
PRODUCTION_SSL_EMAIL=<your email>

# Docker Registry (if using private registry)
DOCKER_USERNAME=<your docker username>
DOCKER_PASSWORD=<your docker password>

# Notifications (optional)
SLACK_WEBHOOK_URL=<your slack webhook URL>
```

## 🔍 Troubleshooting

### Common Issues

#### 1. **DNS Not Resolving**
```bash
# Check DNS configuration
nslookup new.neyamotenterprise.com 8.8.8.8

# Wait for DNS propagation (can take up to 48 hours)
# Use online DNS checker: https://dnschecker.org/
```

#### 2. **SSL Certificate Issues**
```bash
# Check certificate status
docker compose -f docker-compose.prod.yml logs certbot

# Manual certificate generation
docker compose -f docker-compose.prod.yml run --rm certbot certonly --webroot --webroot-path=/var/www/certbot --email your-email@example.com --agree-tos --no-eff-email -d new.neyamotenterprise.com
```

#### 3. **Application Not Starting**
```bash
# Check logs
docker compose -f docker-compose.prod.yml logs

# Check specific service
docker compose -f docker-compose.prod.yml logs api
docker compose -f docker-compose.prod.yml logs web
```

#### 4. **Database Connection Issues**
```bash
# Check database logs
docker compose -f docker-compose.prod.yml logs postgres

# Test database connection
docker compose -f docker-compose.prod.yml exec postgres psql -U neyamot_user -d neyamot_db -c "SELECT version();"
```

### Health Check Commands

```bash
# Complete system check
./deploy.sh status

# Check individual services
curl https://new.neyamotenterprise.com/api/health
docker compose -f docker-compose.prod.yml ps
docker stats --no-stream
```

## 📞 Support Commands

### Useful Management Commands

```bash
# View application logs
docker compose -f docker-compose.prod.yml logs -f

# Restart application
docker compose -f docker-compose.prod.yml restart

# Update application
git pull origin main
./deploy.sh update

# Backup database
./backup.sh

# Monitor system resources
htop

# Check disk space
df -h

# Check memory usage
free -h

# Check network connections
netstat -tlnp
```

This guide provides complete server configuration for your Neyamot Enterprise application on server **103.20.53.236**. Follow each section step-by-step to ensure a secure and properly configured production environment.

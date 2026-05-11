<p align="center">
  <img src="https://img.shields.io/badge/WordPress-6.7-21759B?style=for-the-badge&logo=wordpress&logoColor=white" alt="WordPress 6.7">
  <img src="https://img.shields.io/badge/PHP-8.3-777BB4?style=for-the-badge&logo=php&logoColor=white" alt="PHP 8.3">
  <img src="https://img.shields.io/badge/Docker-24+-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/Nginx-1.27-009639?style=for-the-badge&logo=nginx&logoColor=white" alt="Nginx">
  <img src="https://img.shields.io/badge/MariaDB-11.4-003545?style=for-the-badge&logo=mariadb&logoColor=white" alt="MariaDB">
  <img src="https://img.shields.io/badge/Redis-7.4-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License MIT">
  <img src="https://img.shields.io/badge/Terraform-Ready-7B42BC?style=for-the-badge&logo=terraform&logoColor=white" alt="Terraform">
</p>

<h1 align="center">Enterprise WordPress 2026</h1>

<p align="center">
  <strong>Lightning-fast &middot; Hardened &middot; One-command deploy</strong>
</p>

<p align="center">
  Production-grade WordPress deployment stack with Nginx, PHP-FPM, MariaDB, Redis object caching,<br>
  automated SSL, security hardening, and comprehensive automation scripts.<br>
  Includes full AWS infrastructure via Terraform (ECS Fargate, RDS, WAF, CloudFront).
</p>

---

## Documentation Links
- [Deployment Guide](docs/deployment.md)
- [Architecture Overview](docs/architecture.md)

## Architecture

```
                                 Internet
                                    |
                             [Let's Encrypt]
                                    |
                          +---------+---------+
                          |     Fail2ban      |
                          |  (IP banning)     |
                          +---------+---------+
                                    |
                          +---------+---------+
                          |      Nginx        |
                          |  (Reverse Proxy)  |
                          |  - HTTP/2 + TLS   |
                          |  - FastCGI Cache  |
                          |  - Rate Limiting  |
                          |  - Security Hdrs  |
                          +---------+---------+
                                    |
                    +---------------+---------------+
                    |                               |
          +---------+---------+           +---------+---------+
          |    PHP 8.3 FPM    |           |    Static Files   |
          |    (WordPress)    |           |  (Served directly |
          |  - OPcache        |           |   by Nginx)       |
          |  - 512M memory    |           +-------------------+
          +---------+---------+
                    |
          +---------+---------+
          |                   |
  +-------+-------+   +------+------+
  |   MariaDB 11  |   |   Redis 7   |
  |  (Database)   |   | (Obj Cache) |
  |  - InnoDB     |   | - LRU 256MB |
  |  - 1GB buffer |   | - No persist|
  +---------------+   +-------------+
```

### Stack Components

| Service | Image | Purpose |
|---------|-------|---------|
| **Nginx** | `nginx:1.27-alpine` | Reverse proxy, SSL termination, static files, FastCGI cache |
| **WordPress** | `wordpress:6.7-php8.3-fpm-alpine` | Application server with PHP-FPM |
| **MariaDB** | `mariadb:11.4` | Database server (faster than MySQL for WordPress) |
| **Redis** | `redis:7.4-alpine` | In-memory object cache (transients, queries) |
| **Certbot** | `certbot/certbot:v3.0.1` | Automated Let's Encrypt SSL certificates |
| **Fail2ban** | `crazymax/fail2ban:1.1.0` | Intrusion prevention (brute force protection) |
| **WP-CLI** | `wordpress:cli-2.11-php8.3` | WordPress command-line management |

---

## Quick Start

### Prerequisites

- **Docker** 24+ with Docker Compose v2
- **Domain name** (for production SSL) or `localhost` for dev
- **2GB+ RAM** (4GB recommended for production)

### 5-Step Deploy

```bash
# 1. Clone the repository
git clone https://github.com/moussan/Enterprise-Wordpress-2026.git
cd Enterprise-Wordpress-2026

# 2. Configure environment
cp .env.example .env
nano .env  # Edit passwords and domain

# 3. Deploy (development)
./scripts/deploy.sh --dev

# 4. Or deploy (production with SSL)
./scripts/deploy.sh --production

# 5. Open your site
# Dev:  http://localhost:8080
# Prod: https://your-domain.com
```

Or use the **one-liner** for development:

```bash
git clone https://github.com/moussan/Enterprise-Wordpress-2026.git && cd Enterprise-Wordpress-2026 && ./scripts/deploy.sh --dev
```

For a comprehensive guide, see the [Deployment Guide](docs/deployment.md).

---

## Environment Variables

All configuration is in `.env`. Copy `.env.example` and customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPOSE_PROJECT_NAME` | `enterprise-wp` | Docker project prefix for all containers/volumes |
| `DOMAIN` | `example.com` | Your domain name (use `localhost` for dev) |
| `CERTBOT_EMAIL` | `admin@example.com` | Email for SSL certificate notifications |
| `MYSQL_ROOT_PASSWORD` | *(required)* | MariaDB root password |
| `MYSQL_DATABASE` | `wordpress` | WordPress database name |
| `MYSQL_USER` | `wordpress` | WordPress database user |
| `MYSQL_PASSWORD` | *(required)* | WordPress database password |
| `WP_TABLE_PREFIX` | `wp_` | Database table prefix (randomize for security) |
| `WP_SITE_URL` | `https://example.com` | Full site URL with protocol |
| `WP_SITE_TITLE` | `Enterprise WordPress` | Site title |
| `WP_ADMIN_USER` | `admin` | Admin username |
| `WP_ADMIN_PASSWORD` | *(required)* | Admin password (change immediately!) |
| `WP_ADMIN_EMAIL` | `admin@example.com` | Admin email address |
| `WP_FORCE_SSL` | `true` | Force HTTPS in admin panel |
| `WP_DEBUG` | `false` | Enable WordPress debug mode |
| `NGINX_HTTP_PORT` | `80` | HTTP port (use `8080` for dev) |
| `NGINX_HTTPS_PORT` | `443` | HTTPS port |
| `BACKUP_RETENTION` | `7` | Number of backups to keep |

---

## Performance

### What's Included

| Optimization | Impact | Details |
|-------------|--------|---------|
| **Nginx FastCGI Cache** | 10-100x faster | Full-page cache for anonymous visitors |
| **Redis Object Cache** | 30-50% faster | WordPress transients and query results cached in memory |
| **PHP OPcache** | 3-5x faster | Precompiled PHP bytecode eliminates parse overhead |
| **Gzip Compression** | 60-80% smaller | Text responses compressed at level 6 |
| **HTTP/2** | 40-50% faster | Multiplexed connections, header compression |
| **Static File Caching** | Instant | 365-day browser cache for assets |
| **MariaDB Tuning** | 2-3x faster | InnoDB buffer pool, query optimization |
| **PHP-FPM Dynamic Pool** | Auto-scale | Workers scale with traffic (2-16 workers) |

### Expected Performance

| Metric | Value |
|--------|-------|
| Time to First Byte (cached) | < 50ms |
| Page load (cached) | < 1s |
| Concurrent users | 500-1000+ |
| Requests/second | 1000+ (cached) |
| Database queries/page | 0 (cached), ~30 (uncached) |

---

## Security Features

| Feature | Protection Against |
|---------|-------------------|
| **TLS 1.2/1.3** with modern ciphers | Eavesdropping, MITM attacks |
| **HSTS** (Strict-Transport-Security) | SSL stripping, downgrade attacks |
| **Content-Security-Policy** | XSS, data injection, clickjacking |
| **X-Frame-Options** | Clickjacking |
| **X-Content-Type-Options** | MIME sniffing attacks |
| **Referrer-Policy** | Information leakage |
| **Fail2ban** | Brute force login attacks |
| **Rate limiting** (login, xmlrpc, global) | DDoS, credential stuffing |
| **xmlrpc.php** rate limited | Amplification attacks |
| **PHP upload directory** execution blocked | Malicious file uploads |
| **Sensitive file** access denied | .env, wp-config.php exposure |
| **DISALLOW_FILE_EDIT** | Code injection via admin panel |
| **Hidden PHP/Nginx versions** | Fingerprinting, targeted exploits |
| **Non-root containers** | Container escape, privilege escalation |
| **Network isolation** | Backend services unreachable from internet |
| **Disabled dangerous PHP functions** | Remote code execution |

See [docs/SECURITY.md](docs/SECURITY.md) for the full security guide.

---

## Scripts Reference

| Script | Description |
|--------|-------------|
| `scripts/deploy.sh` | One-command full deployment |
| `scripts/backup.sh` | Database + files backup with retention |
| `scripts/restore.sh` | Restore from any backup |
| `scripts/update.sh` | Safe update: backup -> pull -> restart |
| `scripts/healthcheck.sh` | Check all service health |
| `scripts/wpcli.sh` | WP-CLI command wrapper |
| `scripts/ssl.sh` | SSL certificate management |

### Script Usage Examples

```bash
# Deploy
./scripts/deploy.sh --dev                    # Development mode
./scripts/deploy.sh --production             # Production with SSL

# Backups
./scripts/backup.sh                          # Full backup
./scripts/backup.sh --db-only               # Database only
./scripts/restore.sh --latest               # Restore latest

# Updates
./scripts/update.sh                          # Safe update
./scripts/update.sh --dry-run               # Preview changes

# WordPress management
./scripts/wpcli.sh plugin list              # List plugins
./scripts/wpcli.sh core version             # WP version
./scripts/wpcli.sh cache flush              # Flush cache
./scripts/wpcli.sh user list                # List users

# Health
./scripts/healthcheck.sh                     # Full status
./scripts/healthcheck.sh --quiet            # Exit code only

# SSL
./scripts/ssl.sh init                        # Get certificate
./scripts/ssl.sh renew                       # Renew certificate
```

---

## Makefile Targets

Run `make help` to see all targets:

| Target | Description |
|--------|-------------|
| `make up` | Start services (development) |
| `make up-prod` | Start services (production) |
| `make down` | Stop all services |
| `make restart` | Restart all services |
| `make logs` | Follow all logs |
| `make logs-wp` | Follow WordPress logs |
| `make logs-nginx` | Follow Nginx logs |
| `make logs-db` | Follow MariaDB logs |
| `make deploy` | Run deploy script |
| `make backup` | Create backup |
| `make restore` | Restore latest backup |
| `make update` | Safe update |
| `make status` | Health check |
| `make ssl` | Initialize SSL |
| `make wpcli CMD="..."` | Run WP-CLI command |
| `make shell-wp` | WordPress container shell |
| `make shell-db` | MariaDB CLI |
| `make shell-redis` | Redis CLI |
| `make validate` | Validate all configs |
| `make clean` | Remove unused Docker resources |

---

## Production Checklist

Before going live, verify these items:

- [ ] **Passwords changed** -- All defaults in `.env` replaced with strong passwords
- [ ] **Domain configured** -- `DOMAIN` set to your actual domain
- [ ] **DNS pointing** -- A records point to your server IP
- [ ] **SSL initialized** -- Run `make ssl` or `./scripts/ssl.sh init`
- [ ] **Table prefix** -- Changed `WP_TABLE_PREFIX` from default `wp_`
- [ ] **Debug disabled** -- `WP_DEBUG=false` in `.env`
- [ ] **Admin user** -- Changed default admin username from `admin`
- [ ] **File mods disabled** -- `WP_DISALLOW_FILE_MODS=true` for locked-down prod
- [ ] **Backup configured** -- `BACKUP_RETENTION` set, cron scheduled
- [ ] **Monitoring** -- Health check endpoint monitored externally
- [ ] **Firewall** -- Server firewall allows only ports 80, 443, 22
- [ ] **SSH hardened** -- Key-only auth, no root login
- [ ] **GitHub Secrets** -- Deploy secrets configured for CI/CD

---

## Backup & Restore

### Automated Backups

```bash
# Create full backup (database + wp-content)
make backup

# Schedule via cron (every day at 3 AM)
0 3 * * * cd /opt/wordpress && ./scripts/backup.sh >> /var/log/wp-backup.log 2>&1
```

### Manual Restore

```bash
# List available backups
./scripts/restore.sh

# Restore specific backup
./scripts/restore.sh backup_20260411_120000

# Restore latest backup
./scripts/restore.sh --latest

# Database only
./scripts/restore.sh backup_20260411_120000 --db-only
```

Backups are stored in `./backups/` with automatic retention (default: 7 backups).

---

## Upgrading

### Updating the Stack

```bash
# Safe update: creates backup, pulls images, restarts
make update

# Preview what would change
./scripts/update.sh --dry-run
```

### Major WordPress Upgrades

```bash
# 1. Create backup
make backup

# 2. Update WordPress core
make wpcli CMD="core update"

# 3. Update database
make wpcli CMD="core update-db"

# 4. Update plugins
make wpcli CMD="plugin update --all"

# 5. Verify
make status
```

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for comprehensive solutions.

### Common Issues

<details>
<summary><strong>Container won't start</strong></summary>

```bash
# Check container logs
docker compose logs <service-name>

# Check resource usage
docker stats

# Validate configuration
make validate
```
</details>

<details>
<summary><strong>Database connection refused</strong></summary>

```bash
# Check if MariaDB is healthy
docker compose ps mariadb

# Check MariaDB logs
docker compose logs mariadb

# Test connection
docker compose exec mariadb mariadb -uwordpress -p wordpress -e "SELECT 1"
```
</details>

<details>
<summary><strong>White screen of death</strong></summary>

```bash
# Enable debug mode
# Set WP_DEBUG=true in .env, then:
docker compose restart wordpress

# Check PHP error logs
docker compose logs wordpress
```
</details>

<details>
<summary><strong>SSL certificate issues</strong></summary>

```bash
# Check certificate status
./scripts/ssl.sh status

# Re-obtain certificate
./scripts/ssl.sh init

# Use staging for testing (no rate limits)
./scripts/ssl.sh staging
```
</details>

<details>
<summary><strong>Redis not connecting</strong></summary>

```bash
# Check Redis status
docker compose exec redis redis-cli ping

# Check Redis memory
docker compose exec redis redis-cli info memory

# Reinstall Redis Object Cache plugin
make wpcli CMD="plugin deactivate redis-cache"
make wpcli CMD="plugin activate redis-cache"
make wpcli CMD="redis enable"
```
</details>

---

## AWS Infrastructure (Terraform)

This project includes a complete **Terraform** setup for AWS deployment:

```
terraform/          # Root Terraform configuration
modules/
  networking/       # VPC, subnets, routing
  security/         # WAF, security groups
  database/         # RDS MariaDB
  storage/          # EFS, S3
  alb/              # Application Load Balancer
  compute/          # ECS Fargate
  cdn/              # CloudFront CDN
```

See `architecture/` for Architecture Decision Records (ADRs) and `security/` for threat models and compliance mapping.

---

## Project Structure

```
Enterprise-Wordpress-2026/
├── config/
│   ├── nginx/
│   │   ├── nginx.conf              # Main Nginx configuration
│   │   ├── wordpress.conf          # Production server block (HTTPS)
│   │   └── wordpress-dev.conf      # Development server block (HTTP)
│   ├── php/
│   │   ├── php.ini                 # PHP configuration (OPcache, limits)
│   │   └── www.conf                # PHP-FPM pool configuration
│   ├── mariadb/
│   │   └── my.cnf                  # MariaDB tuning (InnoDB, logging)
│   ├── redis/
│   │   └── redis.conf              # Redis cache configuration
│   ├── wordpress/
│   │   └── wp-config-extra.php     # Extra WordPress constants
│   └── fail2ban/
│       ├── jail.local              # Fail2ban jail configuration
│       └── filter.d/               # Custom filter definitions
├── scripts/
│   ├── deploy.sh                   # One-command deployment
│   ├── backup.sh                   # Backup with retention
│   ├── restore.sh                  # Restore from backup
│   ├── update.sh                   # Safe update procedure
│   ├── healthcheck.sh              # Service health checks
│   ├── wpcli.sh                    # WP-CLI wrapper
│   └── ssl.sh                      # SSL certificate management
├── docs/
│   ├── ARCHITECTURE.md             # Detailed architecture guide
│   ├── SECURITY.md                 # Security hardening guide
│   ├── PERFORMANCE.md              # Performance tuning guide
│   ├── TROUBLESHOOTING.md          # Comprehensive troubleshooting
│   └── CONTRIBUTING.md             # Contribution guidelines
├── terraform/                      # AWS Infrastructure as Code
├── modules/                        # Terraform modules
├── architecture/                   # Architecture Decision Records
├── security/                       # Threat model & compliance
├── .github/workflows/
│   ├── ci.yml                      # CI: lint, validate, security
│   └── deploy.yml                  # CD: automated deployment
├── docker-compose.yml              # Production stack
├── docker-compose.override.yml     # Development overrides
├── Makefile                        # Common operations
├── .env.example                    # Environment template
├── CHANGELOG.md                    # Version history
└── LICENSE                         # MIT License
```

---

## Contributing

We welcome contributions! See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run validation (`make validate`)
5. Commit with a descriptive message
6. Push and open a Pull Request

---

## License

This project is licensed under the **MIT License** -- see [LICENSE](LICENSE) for details.

---

## Author

**Moussa El Najmi** -- Senior AWS Solutions Architect

- GitHub: [@moussan](https://github.com/moussan)
- Location: Calgary, Canada

---

<p align="center">
  <sub>Built with modern DevOps practices for enterprise-grade WordPress hosting.</sub>
</p>

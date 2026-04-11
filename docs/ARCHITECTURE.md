# Architecture Guide

## Overview

Enterprise WordPress 2026 uses a multi-container Docker architecture designed for performance, security, and maintainability. The stack runs on any Docker-compatible host (bare metal, VM, or cloud instance).

## Container Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │              Docker Host                     │
                    │                                             │
 Internet ────────►│  ┌─────────────────────────────────────┐    │
        Port 80/443│  │        Frontend Network              │    │
                    │  │  ┌──────────┐  ┌──────────────────┐ │    │
                    │  │  │ Fail2ban │  │     Certbot      │ │    │
                    │  │  └────┬─────┘  └──────────────────┘ │    │
                    │  │       │                              │    │
                    │  │  ┌────┴─────┐                       │    │
                    │  │  │  Nginx   │◄─── SSL Termination   │    │
                    │  │  │  :80/443 │     FastCGI Cache     │    │
                    │  │  └────┬─────┘     Rate Limiting     │    │
                    │  └───────┼──────────────────────────────┘    │
                    │          │                                   │
                    │  ┌───────┼──────────────────────────────┐    │
                    │  │       │   Backend Network (internal)  │    │
                    │  │  ┌────┴─────────┐                    │    │
                    │  │  │  WordPress   │                    │    │
                    │  │  │  PHP 8.3 FPM │                    │    │
                    │  │  │  :9000       │                    │    │
                    │  │  └──┬────────┬──┘                    │    │
                    │  │     │        │                        │    │
                    │  │  ┌──┴──┐  ┌──┴──┐                    │    │
                    │  │  │Maria│  │Redis│                    │    │
                    │  │  │ DB  │  │:6379│                    │    │
                    │  │  │:3306│  └─────┘                    │    │
                    │  │  └─────┘                             │    │
                    │  └──────────────────────────────────────┘    │
                    └─────────────────────────────────────────────┘
```

## Network Isolation

| Network | Subnet | Services | Internet Access |
|---------|--------|----------|-----------------|
| **Frontend** | `172.20.0.0/24` | Nginx, Certbot, Fail2ban | Yes (ports 80/443) |
| **Backend** | `172.20.1.0/24` | WordPress, MariaDB, Redis, Nginx | No (internal only) |

The backend network is marked `internal: true`, preventing any direct internet access to the database or cache. Nginx bridges both networks to route traffic from the frontend to PHP-FPM.

## Request Flow

### Cached Request (Anonymous Visitor)
```
Client → Nginx → FastCGI Cache HIT → Response (< 50ms)
```

### Uncached Request
```
Client → Nginx → PHP-FPM → WordPress Core
                                ├── Redis (object cache lookup)
                                ├── MariaDB (database query)
                                └── Response → Nginx → FastCGI Cache STORE → Client
```

### Admin / Logged-in Request
```
Client → Nginx → PHP-FPM → WordPress Core
                                ├── Redis (object cache)
                                ├── MariaDB (database)
                                └── Response (cache bypassed)
```

## Volume Architecture

| Volume | Mount Point | Purpose | Shared Between |
|--------|------------|---------|----------------|
| `wordpress_data` | `/var/www/html` | WordPress core files, themes, plugins | WordPress (rw), Nginx (ro), WP-CLI (rw) |
| `mariadb_data` | `/var/lib/mysql` | Database files | MariaDB only |
| `certbot_conf` | `/etc/letsencrypt` | SSL certificates | Certbot (rw), Nginx (ro) |
| `certbot_www` | `/var/www/certbot` | ACME challenge files | Certbot (rw), Nginx (ro) |
| `nginx_logs` | `/var/log/nginx` | Access and error logs | Nginx (rw), Fail2ban (ro) |
| `fastcgi_cache` | `/var/run/nginx-cache` | FastCGI page cache | Nginx only |
| `fail2ban_data` | `/data` | Ban database | Fail2ban only |

## Service Dependencies

```
                    ┌──────────┐
                    │  Nginx   │
                    └────┬─────┘
                         │ depends on
                    ┌────┴─────┐
                    │WordPress │
                    └──┬────┬──┘
                       │    │ depends on
                ┌──────┴┐  ┌┴──────┐
                │MariaDB│  │ Redis │
                └───────┘  └───────┘
```

Services start in dependency order. Each service has health checks that must pass before dependent services start.

## Resource Allocation

### Production Defaults

| Service | CPU Limit | Memory Limit | CPU Reserve | Memory Reserve |
|---------|-----------|-------------|-------------|----------------|
| Nginx | 1.0 | 512MB | 0.25 | 128MB |
| WordPress | 2.0 | 1GB | 0.5 | 256MB |
| MariaDB | 2.0 | 2GB | 0.5 | 512MB |
| Redis | 0.5 | 512MB | 0.1 | 64MB |
| Certbot | 0.25 | 128MB | - | - |
| Fail2ban | 0.25 | 128MB | - | - |
| **Total** | **6.0** | **4.28GB** | **1.35** | **960MB** |

### Development Defaults

Resource limits are halved in `docker-compose.override.yml` for local development.

## AWS Infrastructure (Terraform)

For cloud deployment at scale, the Terraform modules provision:

| Module | Resources |
|--------|-----------|
| `networking` | VPC, public/private/isolated subnets, NAT Gateway |
| `security` | WAF, security groups, IAM roles |
| `database` | RDS MySQL Multi-AZ, Secrets Manager |
| `storage` | EFS for wp-content, S3 for media offloading |
| `alb` | Application Load Balancer, HTTPS listener |
| `compute` | ECS Fargate tasks, auto-scaling |
| `cdn` | CloudFront distribution |

See `architecture/ADR-001-compute-fargate.md` and `architecture/ADR-002-storage-efs.md` for architectural decision records.

## Design Decisions

### Why Nginx over Apache?
- 10x better for static file serving (sendfile, zero-copy)
- Built-in FastCGI caching (no need for Varnish)
- Lower memory footprint per connection
- Native HTTP/2 support
- Better rate limiting capabilities

### Why MariaDB over MySQL?
- Drop-in MySQL replacement, fully compatible
- Better query optimizer for WordPress read-heavy workloads
- Faster InnoDB operations
- More active community development
- Thread pool available in community edition

### Why Redis over Memcached?
- Richer data structures (lists, sets, sorted sets)
- Better WordPress plugin ecosystem (Redis Object Cache)
- Built-in LRU eviction
- Optional persistence (if needed later)
- Lua scripting for complex cache operations

### Why Alpine-based images?
- 5-10x smaller image sizes (faster pulls, less disk)
- Smaller attack surface
- Faster container startup
- Same functionality with musl libc

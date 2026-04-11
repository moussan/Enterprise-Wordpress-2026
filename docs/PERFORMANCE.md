# Performance Tuning Guide

## Overview

This guide covers every performance optimization in the stack and how to tune them for your specific workload.

## Caching Layers

Enterprise WordPress 2026 implements four caching layers:

```
Request → Browser Cache → Nginx FastCGI Cache → Redis Object Cache → MariaDB Query Cache
```

### Layer 1: Browser Cache (Static Assets)

Static files are cached in the visitor's browser for 365 days:

```nginx
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|webp|avif|woff|woff2|ttf|otf|eot)$ {
    expires 365d;
    add_header Cache-Control "public, immutable";
}
```

**Impact**: Zero server load for returning visitors' static assets.

### Layer 2: Nginx FastCGI Cache (Full-Page)

Anonymous visitors get full HTML pages served directly from Nginx's disk cache, bypassing PHP entirely.

**Configuration** (`config/nginx/nginx.conf`):
```
Cache zone:     256MB memory for keys, 1GB disk storage
Cache duration: 60 minutes for 200/301/302 responses
Stale serving:  Yes (while revalidating or on backend errors)
Lock:           One request updates cache at a time (thundering herd protection)
```

**What's cached**: All anonymous GET requests (no cookies, no query strings).

**What's bypassed**: POST requests, logged-in users, search results, WooCommerce cart/checkout, wp-admin.

**Verify cache status**:
```bash
# Check X-FastCGI-Cache header
curl -I https://your-site.com/
# HIT = served from cache, MISS = passed to PHP, BYPASS = skipped
```

### Layer 3: Redis Object Cache (WordPress)

WordPress stores transients, option autoloads, and query results in Redis instead of the database.

**Configuration** (`config/redis/redis.conf`):
```
Max memory:     256MB
Eviction:       allkeys-lru (least recently used removed first)
Persistence:    Disabled (cache only)
```

**Setup**:
```bash
./scripts/wpcli.sh plugin install redis-cache --activate
./scripts/wpcli.sh redis enable
```

**Monitor**:
```bash
# Redis memory usage
docker compose exec redis redis-cli info memory

# Cache hit rate
docker compose exec redis redis-cli info stats | grep hit
```

### Layer 4: PHP OPcache (Bytecode)

PHP files are compiled to bytecode once and cached in shared memory:

**Configuration** (`config/php/php.ini`):
```
Memory:         256MB
Max files:      20,000
Revalidation:   Every 60 seconds
File cache:     /tmp/opcache (survives restarts)
```

## PHP-FPM Tuning

### Process Management

The PHP-FPM pool uses dynamic process management:

| Setting | Value | Tuning Guide |
|---------|-------|-------------|
| `pm` | `dynamic` | Best for variable traffic |
| `pm.max_children` | `16` | `Available_RAM / 50MB` |
| `pm.start_servers` | `4` | `max_children / 4` |
| `pm.min_spare_servers` | `2` | `start_servers / 2` |
| `pm.max_spare_servers` | `8` | `max_children / 2` |
| `pm.max_requests` | `500` | Prevents memory leaks |

### Memory Calculator

Each PHP-FPM worker uses approximately 40-60MB for WordPress:

| Container Memory | Max Children | Concurrent PHP Requests |
|-----------------|-------------|------------------------|
| 512MB | 8 | 8 |
| 1GB | 16 | 16 |
| 2GB | 32 | 32 |
| 4GB | 64 | 64 |

## MariaDB Tuning

### InnoDB Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| `innodb_buffer_pool_size` | `1G` | Cache data + indexes in memory |
| `innodb_log_file_size` | `256M` | Write performance (larger = fewer flushes) |
| `innodb_flush_log_at_trx_commit` | `1` | ACID compliance (change to 2 for speed) |
| `innodb_flush_method` | `O_DIRECT` | Skip OS cache (InnoDB caches internally) |
| `innodb_io_capacity` | `2000` | SSD IOPS (200 for HDD) |

### Buffer Pool Sizing

Rule of thumb: 50-80% of memory allocated to MariaDB container.

| Container Memory | Buffer Pool | Use Case |
|-----------------|-------------|----------|
| 1GB | 512MB | Development |
| 2GB | 1GB | Small production |
| 4GB | 2-3GB | Medium production |
| 8GB | 5-6GB | Large production |

### Slow Query Analysis

Slow queries are logged automatically (threshold: 2 seconds):

```bash
# View slow query log
docker compose exec mariadb cat /var/lib/mysql/slow-query.log

# Analyze with mysqldumpslow
docker compose exec mariadb mysqldumpslow /var/lib/mysql/slow-query.log
```

## Nginx Tuning

### Worker Configuration

| Setting | Value | Tuning |
|---------|-------|--------|
| `worker_processes` | `auto` | Matches CPU cores |
| `worker_connections` | `4096` | Per worker; increase for very high traffic |
| `worker_rlimit_nofile` | `65535` | File descriptor limit |

### Gzip Compression

Enabled at level 6 (good balance of CPU vs compression ratio):

- Level 1: Fastest, least compression
- Level 6: Default, good balance
- Level 9: Best compression, highest CPU

### Connection Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `keepalive_timeout` | `65s` | Connection reuse window |
| `keepalive_requests` | `1000` | Max requests per connection |
| `sendfile` | `on` | Zero-copy file serving |
| `tcp_nopush` | `on` | Combine headers + body |
| `tcp_nodelay` | `on` | Disable Nagle's algorithm |

## Benchmarking

### Quick Load Test

```bash
# Install Apache Bench
apt-get install apache2-utils

# Test cached pages (should be very fast)
ab -n 1000 -c 50 http://localhost:8080/

# Test uncached pages
ab -n 100 -c 10 http://localhost:8080/?nocache=1
```

### Expected Results

| Scenario | Requests/sec | Avg Response Time |
|----------|-------------|-------------------|
| Cached page (FastCGI) | 1000-5000 | 1-10ms |
| Uncached page (Redis hit) | 100-300 | 50-200ms |
| Uncached page (cold) | 30-100 | 200-500ms |
| Admin page | 10-30 | 500-1500ms |

## Production Recommendations

1. **Enable OPcache with `validate_timestamps=0`** in production and restart PHP after deploys
2. **Increase `innodb_flush_log_at_trx_commit=2`** if you can tolerate losing 1 second of transactions on crash
3. **Scale PHP-FPM workers** based on your actual traffic patterns
4. **Monitor Redis memory** -- if near 256MB, increase `maxmemory` or check for cache stampede
5. **Enable WP_DISABLE_CRON** and use system cron for more reliable scheduled tasks
6. **Use a CDN** (CloudFront, Cloudflare) in front of Nginx for global static asset delivery

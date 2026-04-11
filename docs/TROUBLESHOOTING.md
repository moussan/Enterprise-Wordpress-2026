# Troubleshooting Guide

## Quick Diagnostics

```bash
# Check all services
make status

# View logs (all services)
make logs

# Validate configuration
make validate
```

---

## Container Issues

### Container won't start

**Symptoms**: `docker compose ps` shows container as "restarting" or "exited".

**Steps**:
```bash
# Check container logs
docker compose logs <service-name>

# Check for resource constraints
docker stats --no-stream

# Verify Docker has enough disk space
docker system df

# Check host memory
free -h
```

**Common causes**:
- **Out of memory**: Increase container memory limits or reduce `pm.max_children`
- **Port conflict**: Another service using port 80/443 (`sudo lsof -i :80`)
- **Volume permission**: Reset with `docker compose down && docker compose up -d`

### Container healthy but site unreachable

```bash
# Check Nginx is listening
docker compose exec nginx netstat -tlnp

# Check PHP-FPM is listening
docker compose exec wordpress netstat -tlnp

# Test from inside Nginx container
docker compose exec nginx wget -O- http://wordpress:9000/fpm-ping
```

---

## Database Issues

### Connection refused

**Symptoms**: WordPress shows "Error establishing a database connection".

```bash
# Check MariaDB status
docker compose ps mariadb

# Check MariaDB logs
docker compose logs mariadb --tail=50

# Test connection manually
docker compose exec mariadb mariadb -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} -e "SELECT 1"

# Check MariaDB is accepting connections
docker compose exec mariadb mariadb -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW PROCESSLIST"
```

**Common causes**:
- MariaDB still starting up (wait for health check to pass)
- Wrong credentials in `.env`
- Database not created (check `MYSQL_DATABASE` variable)

### Database too slow

```bash
# Check slow query log
docker compose exec mariadb cat /var/lib/mysql/slow-query.log

# Check InnoDB status
docker compose exec mariadb mariadb -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW ENGINE INNODB STATUS\G"

# Check table sizes
docker compose exec mariadb mariadb -uroot -p${MYSQL_ROOT_PASSWORD} -e "
  SELECT table_name, 
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
  FROM information_schema.tables 
  WHERE table_schema='${MYSQL_DATABASE}'
  ORDER BY (data_length + index_length) DESC
  LIMIT 20;"

# Optimize tables
./scripts/wpcli.sh db optimize
```

---

## WordPress Issues

### White Screen of Death (WSOD)

```bash
# Enable debug mode
# Edit .env: WP_DEBUG=true, WP_DEBUG_LOG=true
docker compose restart wordpress

# Check PHP error logs
docker compose logs wordpress --tail=100

# Check WordPress debug log
docker compose exec wordpress cat /var/www/html/wp-content/debug.log
```

**Common causes**:
- PHP fatal error (memory, syntax, incompatible plugin)
- PHP memory limit too low (increase `memory_limit` in `config/php/php.ini`)
- Corrupted theme/plugin (deactivate via WP-CLI)

### Plugin causing issues

```bash
# Deactivate all plugins
./scripts/wpcli.sh plugin deactivate --all

# Activate one by one to find the culprit
./scripts/wpcli.sh plugin activate <plugin-name>

# Check for plugin updates
./scripts/wpcli.sh plugin list --update=available
```

### Permalink issues (404 on all pages)

```bash
# Flush rewrite rules
./scripts/wpcli.sh rewrite flush

# Check Nginx config is passing to PHP correctly
make validate
```

---

## Redis Issues

### Redis not connecting

```bash
# Check Redis is running
docker compose exec redis redis-cli ping
# Expected: PONG

# Check Redis memory
docker compose exec redis redis-cli info memory

# Check connection count
docker compose exec redis redis-cli info clients

# Verify WordPress Redis plugin
./scripts/wpcli.sh plugin status redis-cache
```

### Redis full (evictions)

```bash
# Check eviction stats
docker compose exec redis redis-cli info stats | grep evicted

# Increase memory if needed (config/redis/redis.conf)
# maxmemory 512mb

# Or flush the cache
docker compose exec redis redis-cli FLUSHDB
```

---

## Nginx Issues

### Configuration error

```bash
# Test Nginx config
docker compose exec nginx nginx -t

# Common issues: missing semicolons, unclosed brackets
# Check the specific file mentioned in the error
```

### FastCGI cache not working

```bash
# Check cache header
curl -I http://localhost:8080/
# Look for: X-FastCGI-Cache: HIT (or MISS, BYPASS)

# Check cache directory
docker compose exec nginx ls -la /var/run/nginx-cache/

# Purge cache
docker compose exec nginx rm -rf /var/run/nginx-cache/*
docker compose exec nginx nginx -s reload
```

### 502 Bad Gateway

```bash
# PHP-FPM is down or overloaded
docker compose logs wordpress --tail=50

# Check PHP-FPM pool status
docker compose exec wordpress php-fpm-healthcheck

# Restart PHP-FPM
docker compose restart wordpress
```

---

## SSL Issues

### Certificate not obtained

```bash
# Check DNS is pointing to your server
dig +short your-domain.com

# Check port 80 is accessible (required for ACME challenge)
curl http://your-domain.com/.well-known/acme-challenge/test

# Try staging first (no rate limits)
./scripts/ssl.sh staging

# Check Certbot logs
docker compose logs certbot
```

### Certificate expired

```bash
# Check current certificate
./scripts/ssl.sh status

# Force renewal
docker compose run --rm certbot renew --force-renewal

# Reload Nginx
docker compose exec nginx nginx -s reload
```

---

## Performance Issues

### Site is slow

```bash
# 1. Check FastCGI cache is working
curl -I http://localhost:8080/
# X-FastCGI-Cache should be HIT for anonymous visitors

# 2. Check Redis is connected
./scripts/wpcli.sh redis status

# 3. Check PHP-FPM workers
docker compose exec wordpress php-fpm-healthcheck

# 4. Check database performance
docker compose exec mariadb mariadb -uroot -p -e "SHOW PROCESSLIST"

# 5. Run full health check
make status
```

### High memory usage

```bash
# Check per-container memory
docker stats --no-stream

# Reduce PHP-FPM workers (config/php/www.conf)
# pm.max_children = 8  (reduce from 16)

# Reduce MariaDB buffer pool (config/mariadb/my.cnf)
# innodb_buffer_pool_size = 512M  (reduce from 1G)

# Reduce Redis memory (config/redis/redis.conf)
# maxmemory 128mb  (reduce from 256mb)
```

---

## Backup/Restore Issues

### Backup fails

```bash
# Check disk space
df -h

# Check MariaDB is accessible
docker compose exec mariadb mariadb -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SELECT 1"

# Check backup directory permissions
ls -la backups/

# Run backup with verbose output
bash -x ./scripts/backup.sh
```

### Restore fails

```bash
# Verify backup file exists and is not empty
ls -la backups/

# Try restoring database only
./scripts/restore.sh <backup_name> --db-only

# If files backup is corrupted, try database only and reinstall WordPress
./scripts/restore.sh <backup_name> --db-only
docker compose restart wordpress
```

---

## Getting Help

If you're still stuck:

1. Check `docker compose logs` for all services
2. Run `make validate` to verify configuration
3. Run `make status` for a full health report
4. Open an issue on GitHub with the diagnostic output

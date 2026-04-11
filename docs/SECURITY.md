# Security Guide

## Overview

Enterprise WordPress 2026 implements defense-in-depth security across all layers: network, application, runtime, and data. This guide details every security control and how to configure them.

## Security Architecture

```
Layer 1: Network    → Firewall, Docker network isolation, rate limiting
Layer 2: Transport  → TLS 1.2/1.3, HSTS, certificate management
Layer 3: Web Server → Security headers, file access control, WAF
Layer 4: Application → WordPress hardening, PHP restrictions
Layer 5: Data       → Encrypted storage, secure credentials
Layer 6: Monitoring → Fail2ban, access logs, slow query logs
```

## Network Security

### Docker Network Isolation

The stack uses two separate Docker networks:

- **Frontend** (`172.20.0.0/24`): Nginx, Certbot, Fail2ban -- internet-facing
- **Backend** (`172.20.1.0/24`, internal): WordPress, MariaDB, Redis -- no internet access

MariaDB and Redis are **never** directly accessible from the internet.

### Firewall Configuration

On the host server, configure iptables/ufw:

```bash
# Allow SSH (restrict to your IP if possible)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable
```

### Rate Limiting

Nginx enforces rate limits at three levels:

| Endpoint | Rate | Burst | Purpose |
|----------|------|-------|---------|
| `/wp-login.php` | 5 req/s | 5 | Brute force protection |
| `/xmlrpc.php` | 1 req/s | 2 | Amplification attack prevention |
| All PHP endpoints | 30 req/s | 20 | General abuse prevention |

## Transport Security (SSL/TLS)

### Configuration

- **Protocols**: TLS 1.2 and TLS 1.3 only (TLS 1.0/1.1 disabled)
- **Cipher suites**: ECDHE with AES-GCM and ChaCha20-Poly1305
- **Key exchange**: ECDHE (forward secrecy)
- **Session caching**: 50MB shared cache, 24-hour timeout
- **OCSP Stapling**: Enabled for faster certificate validation

### HSTS

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

Once enabled, browsers will refuse HTTP connections for 1 year.

### Certificate Management

```bash
# Obtain certificate
./scripts/ssl.sh init

# Renew (automatic via Certbot service)
./scripts/ssl.sh renew

# Test with staging first (no rate limits)
./scripts/ssl.sh staging
```

## HTTP Security Headers

| Header | Value | Protection |
|--------|-------|-----------|
| `X-Frame-Options` | `SAMEORIGIN` | Clickjacking |
| `X-XSS-Protection` | `1; mode=block` | Reflected XSS (legacy browsers) |
| `X-Content-Type-Options` | `nosniff` | MIME confusion attacks |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Information leakage |
| `Content-Security-Policy` | See nginx config | XSS, data injection |
| `Permissions-Policy` | Camera, mic, geo disabled | Feature abuse |
| `Strict-Transport-Security` | 1 year, subdomains, preload | SSL stripping |

### Content Security Policy

The default CSP is:
```
default-src 'self' https:;
script-src 'self' 'unsafe-inline' 'unsafe-eval' https:;
style-src 'self' 'unsafe-inline' https:;
img-src 'self' data: https:;
font-src 'self' https: data:;
frame-ancestors 'self';
```

Customize this in `config/nginx/wordpress.conf` based on your plugins and theme requirements. Some plugins may require additional CSP directives.

## File Access Control

### Blocked Files

| Pattern | Reason |
|---------|--------|
| `.*` (dotfiles) | .env, .git, .htaccess exposure |
| `wp-config.php` | Database credentials |
| `readme.html`, `license.txt` | WordPress version disclosure |
| `wp-config-sample.php` | Configuration template |
| `wp-content/uploads/*.php` | Uploaded malicious scripts |
| `wp-includes/*.php` | Direct inclusion file access |

### Upload Security

PHP execution is blocked in `/wp-content/uploads/` to prevent uploaded files from being executed as code:

```nginx
location ~* /wp-content/uploads/.*\.php$ {
    deny all;
}
```

## WordPress Hardening

### Security Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `DISALLOW_FILE_EDIT` | `true` | Prevents theme/plugin editing in admin |
| `DISALLOW_FILE_MODS` | configurable | Prevents all file modifications (plugins, themes) |
| `FORCE_SSL_ADMIN` | `true` | Forces HTTPS for admin panel |
| `WP_AUTO_UPDATE_CORE` | `minor` | Only auto-update security patches |

### Recommended Security Plugins

```bash
# Firewall + malware scanner
./scripts/wpcli.sh plugin install wordfence --activate

# Two-factor authentication
./scripts/wpcli.sh plugin install two-factor --activate

# Security auditing
./scripts/wpcli.sh plugin install sucuri-scanner --activate
```

## PHP Security

### Disabled Functions

The following dangerous PHP functions are disabled in `config/php/php.ini`:

```
exec, passthru, shell_exec, system, proc_open, popen, parse_ini_file, show_source
```

### Other PHP Hardening

| Setting | Value | Purpose |
|---------|-------|---------|
| `expose_php` | `Off` | Hide PHP version |
| `display_errors` | `Off` | Don't show errors to visitors |
| `allow_url_include` | `Off` | Prevent remote code inclusion |
| `session.cookie_secure` | `1` | HTTPS-only session cookies |
| `session.cookie_httponly` | `1` | No JavaScript cookie access |
| `session.cookie_samesite` | `Lax` | CSRF protection |
| `session.use_strict_mode` | `1` | Prevent session fixation |

## Fail2ban (Intrusion Prevention)

Fail2ban monitors Nginx access logs and bans IPs showing malicious behavior.

### Active Jails

| Jail | Trigger | Ban Duration | Max Retries |
|------|---------|-------------|-------------|
| `wordpress-login` | Failed login POST | 1 hour | 5 in 5 min |
| `wordpress-xmlrpc` | XMLRPC requests | 2 hours | 3 in 5 min |
| `nginx-botsearch` | Scanner patterns | 1 hour | 5 in 10 min |
| `nginx-4xx` | Excessive 403/404 | 30 min | 20 in 10 min |

### Managing Bans

```bash
# View banned IPs
docker compose exec fail2ban fail2ban-client status wordpress-login

# Unban an IP
docker compose exec fail2ban fail2ban-client set wordpress-login unbanip 1.2.3.4
```

## Credentials Management

### Environment Variables

All credentials are stored in `.env` (never committed to git):

```bash
# Generate strong passwords
openssl rand -base64 32  # Database passwords
openssl rand -hex 16     # Table prefix
```

### Docker Secrets (Production)

For production environments, consider Docker secrets instead of environment variables:

```yaml
secrets:
  db_password:
    external: true
```

## Security Checklist

### Before Deployment
- [ ] All default passwords changed in `.env`
- [ ] `WP_TABLE_PREFIX` randomized
- [ ] Admin username changed from `admin`
- [ ] Server firewall configured (ufw/iptables)
- [ ] SSH key-only authentication enabled
- [ ] Root SSH login disabled

### After Deployment
- [ ] SSL certificate obtained and working
- [ ] Security headers verified (use securityheaders.com)
- [ ] WordPress admin accessible only via HTTPS
- [ ] xmlrpc.php rate-limited or blocked
- [ ] File permissions correct (755 dirs, 644 files)
- [ ] Fail2ban active and monitoring
- [ ] Backup schedule configured

### Ongoing
- [ ] Monitor Fail2ban logs for attack patterns
- [ ] Review MariaDB slow query log for SQL injection attempts
- [ ] Keep WordPress core, plugins, and themes updated
- [ ] Renew SSL certificates (automatic via Certbot)
- [ ] Review and rotate credentials periodically
- [ ] Test backup restoration procedure

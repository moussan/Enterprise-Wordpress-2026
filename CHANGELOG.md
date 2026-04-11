# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-04-11

### Added

- **Docker Compose Stack**: Full production-grade deployment with Nginx, PHP 8.3 FPM, MariaDB 11.4, Redis 7.4, Certbot, and Fail2ban
- **Development Override**: `docker-compose.override.yml` for local development (HTTP only, debug enabled, reduced resources)
- **Nginx Configuration**: Optimized reverse proxy with FastCGI cache, HTTP/2, security headers, rate limiting, and static file caching
- **PHP-FPM Configuration**: Dynamic process pool tuned for WordPress with OPcache (256MB bytecode cache)
- **MariaDB Configuration**: InnoDB tuned with 1GB buffer pool, slow query logging, binary logging
- **Redis Configuration**: 256MB LRU cache with dangerous command protection, no persistence (cache-only mode)
- **WordPress Extras**: Redis object cache integration, security constants, performance tuning
- **Fail2ban**: WordPress login brute force, XMLRPC abuse, bot scanner, and 4xx flood protection
- **Deploy Script**: One-command deployment with prerequisite checks, environment setup, and WordPress installation
- **Backup Script**: Database + wp-content backups with configurable retention policy
- **Restore Script**: Point-in-time restore from any backup with safety pre-backup
- **Update Script**: Safe updates with automatic pre-update backup and rolling restart
- **Health Check Script**: Comprehensive service health monitoring for all stack components
- **WP-CLI Wrapper**: Convenient wrapper script for WordPress CLI operations
- **SSL Script**: Let's Encrypt certificate management (init, renew, status, staging)
- **Makefile**: 20+ targets for common operations (up, down, logs, backup, restore, etc.)
- **CI Pipeline**: Docker Compose validation, ShellCheck, secrets scanning, Nginx config testing, Terraform validation
- **CD Pipeline**: SSH-based deployment with GitHub Actions, environment support, deployment status tracking
- **Environment Template**: Comprehensive `.env.example` with all variables documented
- **Security Hardening**: Network isolation, TLS 1.2+, HSTS, CSP, rate limiting, file access control, PHP function restrictions
- **Documentation Suite**: Architecture guide, security guide, performance tuning guide, troubleshooting guide, contributing guide

### Changed

- **README.md**: Complete rewrite with architecture diagram, quick start, comprehensive reference tables, production checklist
- **.gitignore**: Extended to cover Docker, WordPress, backups, logs, SSL, IDE, and Node files

### Retained

- **Terraform modules**: All existing AWS infrastructure code (networking, security, database, storage, ALB, compute, CDN)
- **Architecture Decision Records**: ADR-001 (Fargate), ADR-002 (EFS)
- **Security documentation**: Threat model, compliance mapping
- **Operational docs**: Disaster recovery plan, runbooks, scaling strategy
- **GitHub Actions**: Terraform plan/apply workflows, security scanning

## [1.0.0] - 2026-04-01

### Added

- Initial Terraform-based AWS infrastructure
- ECS Fargate compute modules
- RDS MySQL database module
- VPC networking with multi-AZ subnets
- WAF and security groups
- CloudFront CDN integration
- S3 media storage
- EFS shared storage
- GitHub Actions for Terraform plan/apply
- Security scanning with tfsec and Checkov
- Architecture Decision Records
- Threat model and compliance mapping
- Disaster recovery documentation
- Operational runbooks

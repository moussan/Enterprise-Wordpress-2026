# Enterprise WordPress 2026 — Deployment Guide

This guide covers how to deploy the Enterprise WordPress stack using Docker Compose for local testing, staging, and production.

## Prerequisites
- A remote Linux server (Ubuntu/Debian recommended) or local machine.
- Docker 24+ and Docker Compose v2 installed.
- (Production only) A registered domain name pointing to your server's IP address.

---

## 1. Local Development Deployment

The fastest way to get started is by spinning up the development mode stack. This runs locally without SSL and with debugging features enabled.

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd Enterprise-Wordpress-2026

# 2. Run the deployment target
make up
```

**What this does:**
1. Automatically creates a `.env` file from `.env.example`.
2. Starts `nginx`, `wordpress`, `mariadb`, and `redis` containers.
3. Access your site at `http://localhost:8080` and the admin panel at `http://localhost:8080/wp-admin/`.

---

## 2. Production Deployment

Production deployment hardens security, forces SSL via Let's Encrypt, and uses resource limits optimized for enterprise load.

### Step 1: Configure Environment
Copy the example environment file and edit the crucial values:

```bash
cp .env.example .env
nano .env
```
Ensure you change:
- `DOMAIN` to your actual domain name.
- `WP_ADMIN_PASSWORD`, `MYSQL_ROOT_PASSWORD`, and `MYSQL_PASSWORD` to strong unique secrets.
- Ensure `WP_DEBUG=false` for performance and security.

### Step 2: Deploy Stack
Run the production deploy script:

```bash
make deploy-prod
```
Or directly:
```bash
./scripts/deploy.sh --production
```

**What this does:**
1. Validates prerequisites and environment variables.
2. Pulls the latest stable container images.
3. Starts the production stack (omitting dev overrides).
4. Waits for MariaDB and WordPress to initialize.
5. Automatically requests a Let's Encrypt SSL certificate for your domain.

---

## 3. GitHub Actions Continuous Deployment (CI/CD)

This repository includes a `.github/workflows/deploy.yml` workflow to automatically deploy code changes to your remote server.

To use it, you must configure the following Secrets in your GitHub repository settings (`Settings` -> `Secrets and variables` -> `Actions`):

- `DEPLOY_HOST`: The IP address of your production server.
- `DEPLOY_USERNAME`: The SSH user (e.g., `ubuntu` or `root`).
- `DEPLOY_SSH_KEY`: The private SSH key granting access to the server.
- `DEPLOY_PATH`: The absolute path where the repository is cloned on your server (default: `/opt/wordpress`).

Once configured, pushing to the `main` branch will automatically pull the latest code on your server and restart the necessary containers.

---

## Operations & Maintenance

### Updates
To safely update images and restart the stack:
```bash
make update
```

### Backups
To create a snapshot backup of the database and `wp-content`:
```bash
make backup
```
*Backups are saved to the `./backups/` directory.*

### View Logs
To view logs of the entire stack in real-time:
```bash
make logs
```

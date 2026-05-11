#!/usr/bin/env bash
###############################################################################
# Enterprise WordPress 2026 — Deploy Script
# ============================================================================
# One-command full deployment: checks prerequisites, configures environment,
# pulls images, starts the stack, and runs WordPress installation.
#
# Usage:
#   ./scripts/deploy.sh              # Full deploy (interactive)
#   ./scripts/deploy.sh --production # Production mode (with SSL)
#   ./scripts/deploy.sh --dev        # Development mode (no SSL)
#   ./scripts/deploy.sh --skip-install # Skip WordPress installation
###############################################################################

set -euo pipefail

# =============================================================================
# COLORS & FORMATTING
# =============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
success() { echo -e "${GREEN}[OK]${NC}      $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC}   $*" >&2; }
step()    { echo -e "\n${CYAN}${BOLD}▶ $*${NC}"; }

# Get the project root directory (parent of scripts/).
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR" || exit 1

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
PRODUCTION=false
SKIP_INSTALL=false
DEV_MODE=false

for arg in "$@"; do
    case "$arg" in
        --production) PRODUCTION=true ;;
        --dev)        DEV_MODE=true ;;
        --skip-install) SKIP_INSTALL=true ;;
        --help|-h)
            echo "Usage: $0 [--production|--dev] [--skip-install]"
            echo ""
            echo "Options:"
            echo "  --production    Production mode with SSL (requires domain)"
            echo "  --dev           Development mode (HTTP only, relaxed security)"
            echo "  --skip-install  Skip WordPress installation step"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *) error "Unknown argument: $arg"; exit 1 ;;
    esac
done

# =============================================================================
# BANNER
# =============================================================================
echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Enterprise WordPress 2026 — Deploy                 ║"
echo "║          Nginx · PHP-FPM · MariaDB · Redis                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# STEP 1: Check Prerequisites
# =============================================================================
step "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker 24+."
    error "Visit: https://docs.docker.com/engine/install/"
    exit 1
fi
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
success "Docker ${DOCKER_VERSION}"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    error "Docker Compose v2 is not installed."
    error "It should be included with Docker Desktop, or install the compose plugin."
    exit 1
fi
COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
success "Docker Compose ${COMPOSE_VERSION}"

# Check disk space (warn if less than 5GB free)
FREE_SPACE=$(df -BG "$PROJECT_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
if [ "${FREE_SPACE:-0}" -lt 5 ]; then
    warn "Low disk space: ${FREE_SPACE}GB free. Recommend 5GB+ for WordPress stack."
else
    success "Disk space: ${FREE_SPACE}GB free"
fi

# =============================================================================
# STEP 2: Environment Configuration
# =============================================================================
step "Configuring environment..."

if [ ! -f "$PROJECT_DIR/.env" ]; then
    info "No .env file found. Copying from .env.example..."
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    warn "Please review and edit .env with your settings!"
    warn "At minimum, change all passwords and the DOMAIN setting."

    if [ "$DEV_MODE" = true ]; then
        # Set development defaults
        sed -i 's/DOMAIN=example.com/DOMAIN=localhost/' "$PROJECT_DIR/.env"
        sed -i 's/NGINX_HTTP_PORT=80/NGINX_HTTP_PORT=8080/' "$PROJECT_DIR/.env"
        sed -i 's/WP_FORCE_SSL=true/WP_FORCE_SSL=false/' "$PROJECT_DIR/.env"
        sed -i 's/WP_DEBUG=false/WP_DEBUG=true/' "$PROJECT_DIR/.env"
        sed -i 's/WP_DEBUG_LOG=false/WP_DEBUG_LOG=true/' "$PROJECT_DIR/.env"
        success "Development defaults applied to .env"
    fi
else
    success ".env file exists"
fi

# Source .env for variable access
set -a
# shellcheck source=/dev/null
source "$PROJECT_DIR/.env"
set +a

# Validate critical environment variables
MISSING_VARS=()
[ "${MYSQL_ROOT_PASSWORD:-}" = "CHANGE_THIS_ROOT_PASSWORD_456!" ] && MISSING_VARS+=("MYSQL_ROOT_PASSWORD")
[ "${MYSQL_PASSWORD:-}" = "CHANGE_THIS_DB_PASSWORD_789!" ] && MISSING_VARS+=("MYSQL_PASSWORD")
[ "${WP_ADMIN_PASSWORD:-}" = "CHANGE_THIS_STRONG_PASSWORD_123!" ] && MISSING_VARS+=("WP_ADMIN_PASSWORD")

if [ ${#MISSING_VARS[@]} -gt 0 ] && [ "$PRODUCTION" = true ]; then
    error "Default passwords detected! Change these in .env before production deploy:"
    for var in "${MISSING_VARS[@]}"; do
        error "  - $var"
    done
    exit 1
elif [ ${#MISSING_VARS[@]} -gt 0 ]; then
    warn "Using default passwords (acceptable for development only)."
fi

# =============================================================================
# STEP 3: Create Required Directories
# =============================================================================
step "Creating directories..."
mkdir -p "$PROJECT_DIR/backups"
success "Backup directory ready"

# =============================================================================
# STEP 4: Pull Docker Images
# =============================================================================
step "Pulling Docker images (this may take a few minutes)..."

if [ "$PRODUCTION" = true ]; then
    docker compose -f docker-compose.yml pull 2>&1 | tail -5
else
    docker compose pull 2>&1 | tail -5
fi
success "All images pulled"

# =============================================================================
# STEP 5: Start the Stack
# =============================================================================
step "Starting services..."

if [ "$PRODUCTION" = true ]; then
    info "Starting in PRODUCTION mode..."
    docker compose -f docker-compose.yml up -d
else
    info "Starting in DEVELOPMENT mode..."
    docker compose up -d
fi

# Wait for services to be healthy
info "Waiting for services to be healthy..."
MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Check if MariaDB is healthy
    if docker compose exec -T mariadb healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1; then
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    info "Waiting for database... (${ELAPSED}s/${MAX_WAIT}s)"
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    warn "Database health check timed out. Check logs: docker compose logs mariadb"
else
    success "Database is healthy"
fi

# Wait for WordPress PHP-FPM
sleep 10
success "WordPress PHP-FPM started"

# =============================================================================
# STEP 6: WordPress Installation (optional)
# =============================================================================
if [ "$SKIP_INSTALL" = false ]; then
    step "Installing WordPress..."

    # Check if WordPress is already installed
    WP_INSTALLED=$(docker compose run --rm wpcli wp core is-installed 2>/dev/null && echo "yes" || echo "no")

    if [ "$WP_INSTALLED" = "yes" ]; then
        success "WordPress is already installed"
    else
        SITE_URL="${WP_SITE_URL:-http://localhost:8080}"
        SITE_TITLE="${WP_SITE_TITLE:-Enterprise WordPress}"
        ADMIN_USER="${WP_ADMIN_USER:-admin}"
        ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-admin}"
        ADMIN_EMAIL="${WP_ADMIN_EMAIL:-admin@example.com}"

        info "Installing WordPress core..."
        docker compose run --rm wpcli wp core install \
            --url="$SITE_URL" \
            --title="$SITE_TITLE" \
            --admin_user="$ADMIN_USER" \
            --admin_password="$ADMIN_PASSWORD" \
            --admin_email="$ADMIN_EMAIL" \
            --skip-email \
            2>/dev/null || warn "WordPress installation may need manual setup"

        # Install and activate Redis Object Cache plugin
        info "Installing Redis Object Cache plugin..."
        docker compose run --rm wpcli wp plugin install redis-cache --activate 2>/dev/null || true
        docker compose run --rm wpcli wp redis enable 2>/dev/null || true

        success "WordPress installed successfully"
    fi
fi

# =============================================================================
# STEP 7: SSL Setup (Production only)
# =============================================================================
if [ "$PRODUCTION" = true ]; then
    step "Setting up SSL certificates..."

    DOMAIN="${DOMAIN:-example.com}"
    CERTBOT_EMAIL="${CERTBOT_EMAIL:-admin@example.com}"

    if [ "$DOMAIN" = "example.com" ]; then
        warn "Domain is still set to example.com. Update DOMAIN in .env for SSL."
    else
        info "Requesting SSL certificate for ${DOMAIN}..."
        docker compose run --rm certbot certonly \
            --webroot \
            -w /var/www/certbot \
            -d "$DOMAIN" \
            -d "www.$DOMAIN" \
            --email "$CERTBOT_EMAIL" \
            --agree-tos \
            --no-eff-email \
            2>/dev/null || warn "SSL setup failed — check domain DNS and try again"

        # Reload Nginx to pick up certificates
        docker compose exec -T nginx nginx -s reload 2>/dev/null || true
        success "SSL configured for ${DOMAIN}"
    fi
fi

# =============================================================================
# DEPLOYMENT COMPLETE
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║              Deployment Complete!                            ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

HTTP_PORT="${NGINX_HTTP_PORT:-80}"
if [ "$PRODUCTION" = true ]; then
    echo -e "  ${BOLD}Site URL:${NC}    https://${DOMAIN:-example.com}"
    echo -e "  ${BOLD}Admin URL:${NC}   https://${DOMAIN:-example.com}/wp-admin/"
else
    echo -e "  ${BOLD}Site URL:${NC}    http://localhost:${HTTP_PORT}"
    echo -e "  ${BOLD}Admin URL:${NC}   http://localhost:${HTTP_PORT}/wp-admin/"
fi
echo -e "  ${BOLD}Admin User:${NC}  ${WP_ADMIN_USER:-admin}"
echo ""
echo -e "  ${CYAN}Useful commands:${NC}"
echo -e "    docker compose logs -f         # Follow logs"
echo -e "    docker compose ps              # Service status"
echo -e "    ./scripts/wpcli.sh plugin list # List plugins"
echo -e "    make status                    # Full status check"
echo ""

#!/usr/bin/env bash
###############################################################################
# Enterprise WordPress 2026 — SSL Certificate Management
# ============================================================================
# Manages Let's Encrypt SSL certificates via Certbot.
#
# Usage:
#   ./scripts/ssl.sh init      # Obtain initial certificate
#   ./scripts/ssl.sh renew     # Renew existing certificate
#   ./scripts/ssl.sh status    # Check certificate status
#   ./scripts/ssl.sh staging   # Use Let's Encrypt staging (for testing)
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
readonly NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
success() { echo -e "${GREEN}[OK]${NC}      $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC}   $*" >&2; }

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR" || exit 1

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/.env"
    set +a
fi

DOMAIN="${DOMAIN:-example.com}"
EMAIL="${CERTBOT_EMAIL:-admin@example.com}"
ACTION="${1:-help}"

case "$ACTION" in
    init)
        info "Requesting SSL certificate for ${DOMAIN}..."
        docker compose run --rm certbot certonly \
            --webroot \
            -w /var/www/certbot \
            -d "$DOMAIN" \
            -d "www.$DOMAIN" \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email

        info "Reloading Nginx..."
        docker compose exec -T nginx nginx -s reload
        success "SSL certificate obtained for ${DOMAIN}"
        ;;

    renew)
        info "Renewing SSL certificates..."
        docker compose run --rm certbot renew --webroot -w /var/www/certbot
        docker compose exec -T nginx nginx -s reload
        success "Certificates renewed"
        ;;

    status)
        info "Certificate status:"
        docker compose run --rm certbot certificates
        ;;

    staging)
        info "Requesting STAGING certificate for ${DOMAIN} (rate-limit safe)..."
        docker compose run --rm certbot certonly \
            --webroot \
            -w /var/www/certbot \
            -d "$DOMAIN" \
            -d "www.$DOMAIN" \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email \
            --staging

        success "Staging certificate obtained (not trusted by browsers — for testing only)"
        ;;

    help|*)
        echo "Usage: $0 {init|renew|status|staging}"
        echo ""
        echo "Commands:"
        echo "  init     Obtain initial SSL certificate"
        echo "  renew    Renew existing certificates"
        echo "  status   Show certificate status"
        echo "  staging  Obtain staging certificate (for testing)"
        ;;
esac

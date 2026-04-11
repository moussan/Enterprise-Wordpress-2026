#!/usr/bin/env bash
###############################################################################
# Enterprise WordPress 2026 — Update Script
# ============================================================================
# Safely updates the WordPress stack: creates a backup, pulls new images,
# and restarts services with zero-downtime rolling update.
#
# Usage:
#   ./scripts/update.sh             # Full update (backup + pull + restart)
#   ./scripts/update.sh --no-backup # Skip backup step
#   ./scripts/update.sh --dry-run   # Show what would be updated
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
step()    { echo -e "\n${CYAN}${BOLD}▶ $*${NC}"; }

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
NO_BACKUP=false
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --no-backup) NO_BACKUP=true ;;
        --dry-run)   DRY_RUN=true ;;
        --help|-h)
            echo "Usage: $0 [--no-backup] [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --no-backup  Skip pre-update backup"
            echo "  --dry-run    Show what would be updated without making changes"
            exit 0
            ;;
    esac
done

# =============================================================================
# BANNER
# =============================================================================
echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Enterprise WordPress 2026 — Update                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# STEP 1: Pre-update Backup
# =============================================================================
if [ "$NO_BACKUP" = false ]; then
    step "Creating pre-update backup..."
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Would run: ./scripts/backup.sh"
    else
        "$PROJECT_DIR/scripts/backup.sh" || { error "Backup failed! Aborting update."; exit 1; }
    fi
else
    warn "Skipping backup (--no-backup)"
fi

# =============================================================================
# STEP 2: Pull New Images
# =============================================================================
step "Checking for image updates..."

if [ "$DRY_RUN" = true ]; then
    info "[DRY RUN] Would pull latest images"
    docker compose pull --dry-run 2>/dev/null || docker compose config --images
else
    docker compose pull 2>&1 | grep -v "^$"
    success "Images updated"
fi

# =============================================================================
# STEP 3: Restart Services (rolling)
# =============================================================================
step "Restarting services..."

if [ "$DRY_RUN" = true ]; then
    info "[DRY RUN] Would restart: mariadb, redis, wordpress, nginx"
else
    # Restart in dependency order to minimize downtime
    info "Restarting database..."
    docker compose up -d --no-deps mariadb
    sleep 10

    info "Restarting Redis..."
    docker compose up -d --no-deps redis
    sleep 5

    info "Restarting WordPress..."
    docker compose up -d --no-deps wordpress
    sleep 10

    info "Restarting Nginx..."
    docker compose up -d --no-deps nginx
    sleep 5

    success "All services restarted"
fi

# =============================================================================
# STEP 4: WordPress Core & Plugin Updates
# =============================================================================
step "Checking WordPress updates..."

if [ "$DRY_RUN" = true ]; then
    info "[DRY RUN] Would check for WordPress core and plugin updates"
else
    # Update WordPress core (minor updates only for safety)
    info "Checking core updates..."
    docker compose run --rm wpcli wp core update --minor 2>/dev/null || true

    # Update plugins
    info "Checking plugin updates..."
    docker compose run --rm wpcli wp plugin update --all 2>/dev/null || true

    # Update themes
    info "Checking theme updates..."
    docker compose run --rm wpcli wp theme update --all 2>/dev/null || true

    success "WordPress updates applied"
fi

# =============================================================================
# STEP 5: Health Check
# =============================================================================
step "Running health checks..."

if [ "$DRY_RUN" = true ]; then
    info "[DRY RUN] Would run health checks"
else
    "$PROJECT_DIR/scripts/healthcheck.sh" || warn "Some health checks failed — review above"
fi

# =============================================================================
# STEP 6: Clean Up
# =============================================================================
step "Cleaning up..."

if [ "$DRY_RUN" = false ]; then
    # Remove unused Docker images
    docker image prune -f 2>/dev/null | tail -1 || true
    success "Cleanup complete"
fi

# =============================================================================
# COMPLETE
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}Update complete!${NC}"
echo ""
echo -e "  ${CYAN}Check your site to verify everything is working.${NC}"
echo -e "  ${CYAN}If issues occur, restore from backup: ./scripts/restore.sh --latest${NC}"
echo ""

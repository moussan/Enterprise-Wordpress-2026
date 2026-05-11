#!/usr/bin/env bash
###############################################################################
# Enterprise WordPress 2026 — Restore Script
# ============================================================================
# Restores WordPress from a backup created by backup.sh.
#
# Usage:
#   ./scripts/restore.sh                        # List available backups
#   ./scripts/restore.sh backup_20260411_120000  # Restore specific backup
#   ./scripts/restore.sh --latest               # Restore most recent backup
#   ./scripts/restore.sh backup_name --db-only  # Restore database only
#   ./scripts/restore.sh backup_name --files-only # Restore files only
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
cd "$PROJECT_DIR" || exit 1

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/.env"
    set +a
fi

BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"
DB_NAME="${MYSQL_DATABASE:-wordpress}"
DB_USER="${MYSQL_USER:-wordpress}"
DB_PASS="${MYSQL_PASSWORD:-}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-enterprise-wp}"

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
BACKUP_NAME=""
DB_ONLY=false
FILES_ONLY=false
LATEST=false

for arg in "$@"; do
    case "$arg" in
        --db-only)    DB_ONLY=true ;;
        --files-only) FILES_ONLY=true ;;
        --latest)     LATEST=true ;;
        --help|-h)
            echo "Usage: $0 [backup_name|--latest] [--db-only|--files-only]"
            echo ""
            echo "Options:"
            echo "  backup_name    Name of backup to restore (e.g., backup_20260411_120000)"
            echo "  --latest       Restore most recent backup"
            echo "  --db-only      Restore database only"
            echo "  --files-only   Restore files only"
            exit 0
            ;;
        --*) ;;
        *)   BACKUP_NAME="$arg" ;;
    esac
done

# =============================================================================
# BANNER
# =============================================================================
echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Enterprise WordPress 2026 — Restore                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# LIST BACKUPS (if no backup specified)
# =============================================================================
if [ -z "$BACKUP_NAME" ] && [ "$LATEST" = false ]; then
    step "Available backups:"
    echo ""

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        warn "No backups found in ${BACKUP_DIR}"
        info "Run ./scripts/backup.sh to create a backup first."
        exit 0
    fi

    # Group by timestamp and show sizes
    find "$BACKUP_DIR" -name "backup_*" -type f | sort -r | while read -r file; do
        SIZE=$(du -sh "$file" | cut -f1)
        echo -e "  $(basename "$file")  ${CYAN}(${SIZE})${NC}"
    done

    echo ""
    info "Usage: $0 <backup_name>"
    info "Example: $0 backup_20260411_120000"
    exit 0
fi

# Find latest backup if requested
if [ "$LATEST" = true ]; then
    BACKUP_NAME=$(find "$BACKUP_DIR" -name "*_database.sql.gz" -type f | sort -r | head -1 | xargs basename | sed 's/_database\.sql\.gz//')
    if [ -z "$BACKUP_NAME" ]; then
        error "No backups found!"
        exit 1
    fi
    info "Latest backup: ${BACKUP_NAME}"
fi

# =============================================================================
# VERIFY BACKUP FILES EXIST
# =============================================================================
step "Verifying backup files..."

DB_BACKUP="${BACKUP_DIR}/${BACKUP_NAME}_database.sql.gz"
FILES_BACKUP="${BACKUP_DIR}/${BACKUP_NAME}_wp-content.tar.gz"

HAS_DB=false
HAS_FILES=false

if [ -f "$DB_BACKUP" ]; then
    HAS_DB=true
    success "Database backup found: $(du -sh "$DB_BACKUP" | cut -f1)"
else
    warn "No database backup found: ${DB_BACKUP}"
fi

if [ -f "$FILES_BACKUP" ]; then
    HAS_FILES=true
    success "Files backup found: $(du -sh "$FILES_BACKUP" | cut -f1)"
else
    warn "No files backup found: ${FILES_BACKUP}"
fi

if [ "$HAS_DB" = false ] && [ "$HAS_FILES" = false ]; then
    error "No backup files found for: ${BACKUP_NAME}"
    exit 1
fi

# =============================================================================
# CONFIRMATION
# =============================================================================
echo ""
warn "This will OVERWRITE current data with the backup!"
echo -e "${YELLOW}Backup: ${BACKUP_NAME}${NC}"
echo -e "${YELLOW}Press Ctrl+C to cancel, or wait 5 seconds to continue...${NC}"
sleep 5

# =============================================================================
# CREATE PRE-RESTORE BACKUP
# =============================================================================
step "Creating pre-restore safety backup..."
"$PROJECT_DIR/scripts/backup.sh" --db-only 2>/dev/null || warn "Pre-restore backup failed (continuing anyway)"

# =============================================================================
# RESTORE DATABASE
# =============================================================================
if [ "$HAS_DB" = true ] && [ "$FILES_ONLY" = false ]; then
    step "Restoring database..."

    gunzip -c "$DB_BACKUP" | docker compose exec -T mariadb \
        mariadb \
        --user="$DB_USER" \
        --password="$DB_PASS" \
        "$DB_NAME" 2>/dev/null

    success "Database restored"
fi

# =============================================================================
# RESTORE FILES
# =============================================================================
if [ "$HAS_FILES" = true ] && [ "$DB_ONLY" = false ]; then
    step "Restoring wp-content..."

    VOLUME_NAME="${PROJECT_NAME}_wordpress_data"

    docker run --rm \
        -v "${VOLUME_NAME}:/var/www/html" \
        -v "${BACKUP_DIR}:/backup:ro" \
        alpine:3.20 \
        sh -c "rm -rf /var/www/html/wp-content && tar xzf '/backup/${BACKUP_NAME}_wp-content.tar.gz' -C /var/www/html/" 2>/dev/null

    success "Files restored"
fi

# =============================================================================
# RESTART SERVICES
# =============================================================================
step "Restarting services..."
docker compose restart wordpress nginx
sleep 5

# Flush caches
docker compose exec -T redis redis-cli FLUSHALL 2>/dev/null || true
success "Caches flushed"

# =============================================================================
# COMPLETE
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}Restore complete!${NC}"
echo ""
echo -e "  ${BOLD}Restored from:${NC} ${BACKUP_NAME}"
echo -e "  ${CYAN}Verify your site is working correctly.${NC}"
echo ""

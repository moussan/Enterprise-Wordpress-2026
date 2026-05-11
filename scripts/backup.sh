#!/usr/bin/env bash
###############################################################################
# Enterprise WordPress 2026 — Backup Script
# ============================================================================
# Creates timestamped backups of the database and wp-content directory.
# Implements retention policy (default: keep last 7 backups).
#
# Usage:
#   ./scripts/backup.sh              # Full backup (DB + files)
#   ./scripts/backup.sh --db-only    # Database only
#   ./scripts/backup.sh --files-only # wp-content only
#   ./scripts/backup.sh --retention 14  # Keep 14 backups
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

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
DB_ONLY=false
FILES_ONLY=false
RETENTION="${BACKUP_RETENTION:-7}"

for arg in "$@"; do
    case "$arg" in
        --db-only)    DB_ONLY=true ;;
        --files-only) FILES_ONLY=true ;;
        --retention)  shift; RETENTION="${1:-7}" ;;
        --help|-h)
            echo "Usage: $0 [--db-only|--files-only] [--retention N]"
            echo ""
            echo "Options:"
            echo "  --db-only      Backup database only"
            echo "  --files-only   Backup wp-content only"
            echo "  --retention N  Keep last N backups (default: 7)"
            exit 0
            ;;
    esac
done

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/.env"
    set +a
fi

# =============================================================================
# CONFIGURATION
# =============================================================================
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"
BACKUP_NAME="backup_${TIMESTAMP}"
DB_NAME="${MYSQL_DATABASE:-wordpress}"
DB_USER="${MYSQL_USER:-wordpress}"
DB_PASS="${MYSQL_PASSWORD:-}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-enterprise-wp}"

mkdir -p "$BACKUP_DIR"

# =============================================================================
# BANNER
# =============================================================================
echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Enterprise WordPress 2026 — Backup                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
info "Timestamp: ${TIMESTAMP}"
info "Backup dir: ${BACKUP_DIR}"

# =============================================================================
# DATABASE BACKUP
# =============================================================================
if [ "$FILES_ONLY" = false ]; then
    step "Backing up database..."

    DB_BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}_database.sql.gz"

    docker compose exec -T mariadb mariadb-dump \
        --user="$DB_USER" \
        --password="$DB_PASS" \
        --single-transaction \
        --routines \
        --triggers \
        --add-drop-table \
        "$DB_NAME" 2>/dev/null \
        | gzip > "$DB_BACKUP_FILE"

    DB_SIZE=$(du -sh "$DB_BACKUP_FILE" | cut -f1)
    success "Database backup: ${DB_BACKUP_FILE} (${DB_SIZE})"
fi

# =============================================================================
# FILES BACKUP (wp-content)
# =============================================================================
if [ "$DB_ONLY" = false ]; then
    step "Backing up wp-content..."

    FILES_BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}_wp-content.tar.gz"

    # Get the WordPress volume name
    VOLUME_NAME="${PROJECT_NAME}_wordpress_data"

    # Create a temporary container to tar the wp-content directory
    docker run --rm \
        -v "${VOLUME_NAME}:/var/www/html:ro" \
        -v "${BACKUP_DIR}:/backup" \
        alpine:3.20 \
        tar czf "/backup/${BACKUP_NAME}_wp-content.tar.gz" \
        -C /var/www/html \
        wp-content/ 2>/dev/null || warn "wp-content backup may be incomplete"

    if [ -f "$FILES_BACKUP_FILE" ]; then
        FILES_SIZE=$(du -sh "$FILES_BACKUP_FILE" | cut -f1)
        success "Files backup: ${FILES_BACKUP_FILE} (${FILES_SIZE})"
    fi
fi

# =============================================================================
# RETENTION POLICY — Remove old backups
# =============================================================================
step "Applying retention policy (keep last ${RETENTION})..."

# Count and remove old database backups
DB_BACKUPS=$(find "$BACKUP_DIR" -name "*_database.sql.gz" -type f | sort -r)
DB_COUNT=$(echo "$DB_BACKUPS" | grep -c . || true)
if [ "$DB_COUNT" -gt "$RETENTION" ]; then
    echo "$DB_BACKUPS" | tail -n +$((RETENTION + 1)) | while read -r old_backup; do
        rm -f "$old_backup"
        info "Removed old backup: $(basename "$old_backup")"
    done
fi

# Count and remove old file backups
FILE_BACKUPS=$(find "$BACKUP_DIR" -name "*_wp-content.tar.gz" -type f | sort -r)
FILE_COUNT=$(echo "$FILE_BACKUPS" | grep -c . || true)
if [ "$FILE_COUNT" -gt "$RETENTION" ]; then
    echo "$FILE_BACKUPS" | tail -n +$((RETENTION + 1)) | while read -r old_backup; do
        rm -f "$old_backup"
        info "Removed old backup: $(basename "$old_backup")"
    done
fi

success "Retention policy applied"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}Backup complete!${NC}"
echo ""
echo -e "  ${BOLD}Location:${NC}  ${BACKUP_DIR}"
echo -e "  ${BOLD}Backups:${NC}"
ls -lh "$BACKUP_DIR"/"${BACKUP_NAME}"_* 2>/dev/null | awk '{print "    " $NF " (" $5 ")"}'
echo ""
echo -e "  ${CYAN}To restore: ./scripts/restore.sh ${BACKUP_NAME}${NC}"
echo ""

#!/usr/bin/env bash
###############################################################################
# Enterprise WordPress 2026 — Health Check Script
# ============================================================================
# Checks the status and health of all services in the WordPress stack.
# Returns exit code 0 if all checks pass, 1 if any fail.
#
# Usage:
#   ./scripts/healthcheck.sh          # Full health check
#   ./scripts/healthcheck.sh --quiet  # Exit code only (for monitoring)
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

QUIET=false
FAILURES=0

for arg in "$@"; do
    case "$arg" in
        --quiet|-q) QUIET=true ;;
        --help|-h)
            echo "Usage: $0 [--quiet]"
            echo ""
            echo "Options:"
            echo "  --quiet  Suppress output, exit code only (0=healthy, 1=unhealthy)"
            exit 0
            ;;
    esac
done

check_pass() {
    [ "$QUIET" = false ] && echo -e "  ${GREEN}✓${NC} $*"
}

check_fail() {
    [ "$QUIET" = false ] && echo -e "  ${RED}✗${NC} $*"
    FAILURES=$((FAILURES + 1))
}

check_warn() {
    [ "$QUIET" = false ] && echo -e "  ${YELLOW}!${NC} $*"
}

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR" || exit 1

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/.env"
    set +a
fi

if [ "$QUIET" = false ]; then
    echo -e "${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          Enterprise WordPress 2026 — Health Check           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
fi

# =============================================================================
# DOCKER SERVICES
# =============================================================================
[ "$QUIET" = false ] && echo -e "${CYAN}Docker Services:${NC}"

SERVICES=("nginx" "wordpress" "mariadb" "redis")
for svc in "${SERVICES[@]}"; do
    STATUS=$(docker compose ps --format "{{.Status}}" "$svc" 2>/dev/null || echo "not found")
    if echo "$STATUS" | grep -qi "up"; then
        if echo "$STATUS" | grep -qi "healthy"; then
            check_pass "$svc: running (healthy)"
        elif echo "$STATUS" | grep -qi "unhealthy"; then
            check_fail "$svc: running (unhealthy)"
        else
            check_pass "$svc: running"
        fi
    else
        check_fail "$svc: $STATUS"
    fi
done

# Check optional services
for svc in "certbot" "fail2ban"; do
    STATUS=$(docker compose ps --format "{{.Status}}" "$svc" 2>/dev/null || echo "not running")
    if echo "$STATUS" | grep -qi "up\|exit 0"; then
        check_pass "$svc: active"
    else
        check_warn "$svc: not running (optional)"
    fi
done

# =============================================================================
# DATABASE CONNECTION
# =============================================================================
[ "$QUIET" = false ] && echo -e "\n${CYAN}Database:${NC}"

DB_USER="${MYSQL_USER:-wordpress}"
DB_PASS="${MYSQL_PASSWORD:-}"
DB_NAME="${MYSQL_DATABASE:-wordpress}"

if docker compose exec -T mariadb mariadb -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1" "$DB_NAME" &>/dev/null; then
    check_pass "MariaDB connection: OK"
else
    check_fail "MariaDB connection: FAILED"
fi

# Check database size
DB_SIZE=$(docker compose exec -T mariadb mariadb -u"$DB_USER" -p"$DB_PASS" -e \
    "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema='$DB_NAME';" \
    --skip-column-names 2>/dev/null || echo "unknown")
[ "$QUIET" = false ] && check_pass "Database size: ${DB_SIZE}MB"

# =============================================================================
# REDIS
# =============================================================================
[ "$QUIET" = false ] && echo -e "\n${CYAN}Redis:${NC}"

REDIS_PING=$(docker compose exec -T redis redis-cli ping 2>/dev/null || echo "FAILED")
if [ "$REDIS_PING" = "PONG" ]; then
    check_pass "Redis ping: PONG"
else
    check_fail "Redis ping: $REDIS_PING"
fi

REDIS_MEMORY=$(docker compose exec -T redis redis-cli info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '[:space:]' || echo "unknown")
[ "$QUIET" = false ] && check_pass "Redis memory: ${REDIS_MEMORY}"

REDIS_KEYS=$(docker compose exec -T redis redis-cli dbsize 2>/dev/null | grep -o '[0-9]*' || echo "unknown")
[ "$QUIET" = false ] && check_pass "Redis keys: ${REDIS_KEYS}"

# =============================================================================
# NGINX
# =============================================================================
[ "$QUIET" = false ] && echo -e "\n${CYAN}Nginx:${NC}"

if docker compose exec -T nginx nginx -t &>/dev/null; then
    check_pass "Nginx config: valid"
else
    check_fail "Nginx config: INVALID"
fi

# =============================================================================
# WORDPRESS
# =============================================================================
[ "$QUIET" = false ] && echo -e "\n${CYAN}WordPress:${NC}"

HTTP_PORT="${NGINX_HTTP_PORT:-80}"
HTTP_CODE=$(docker compose exec -T nginx wget --spider -S "http://127.0.0.1:80/" 2>&1 | grep "HTTP/" | tail -1 | awk '{print $2}' || echo "000")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    check_pass "WordPress HTTP response: ${HTTP_CODE}"
else
    check_fail "WordPress HTTP response: ${HTTP_CODE}"
fi

# Check WordPress version via WP-CLI
WP_VERSION=$(docker compose run --rm wpcli wp core version 2>/dev/null || echo "unknown")
[ "$QUIET" = false ] && check_pass "WordPress version: ${WP_VERSION}"

# Check active plugins
PLUGIN_COUNT=$(docker compose run --rm wpcli wp plugin list --status=active --format=count 2>/dev/null || echo "unknown")
[ "$QUIET" = false ] && check_pass "Active plugins: ${PLUGIN_COUNT}"

# =============================================================================
# DISK USAGE
# =============================================================================
[ "$QUIET" = false ] && echo -e "\n${CYAN}Disk Usage:${NC}"

DISK_FREE=$(df -h "$PROJECT_DIR" | awk 'NR==2 {print $4}')
DISK_PERCENT=$(df -h "$PROJECT_DIR" | awk 'NR==2 {print $5}' | tr -d '%')
if [ "${DISK_PERCENT:-0}" -gt 90 ]; then
    check_fail "Disk space: ${DISK_FREE} free (${DISK_PERCENT}% used) — CRITICAL"
elif [ "${DISK_PERCENT:-0}" -gt 80 ]; then
    check_warn "Disk space: ${DISK_FREE} free (${DISK_PERCENT}% used) — WARNING"
else
    check_pass "Disk space: ${DISK_FREE} free (${DISK_PERCENT}% used)"
fi

# Docker disk usage
DOCKER_DISK=$(docker system df --format "{{.Size}}" 2>/dev/null | head -1 || echo "unknown")
[ "$QUIET" = false ] && check_pass "Docker disk usage: ${DOCKER_DISK}"

# =============================================================================
# SUMMARY
# =============================================================================
if [ "$QUIET" = false ]; then
    echo ""
    if [ $FAILURES -eq 0 ]; then
        echo -e "${GREEN}${BOLD}All health checks passed!${NC}"
    else
        echo -e "${RED}${BOLD}${FAILURES} health check(s) failed!${NC}"
    fi
    echo ""
fi

exit $FAILURES

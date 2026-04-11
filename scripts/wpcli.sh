#!/usr/bin/env bash
###############################################################################
# Enterprise WordPress 2026 — WP-CLI Wrapper
# ============================================================================
# Convenient wrapper to run WP-CLI commands against the WordPress container.
#
# Usage:
#   ./scripts/wpcli.sh plugin list
#   ./scripts/wpcli.sh core version
#   ./scripts/wpcli.sh user list
#   ./scripts/wpcli.sh search-replace 'old.com' 'new.com'
#   ./scripts/wpcli.sh db export - > backup.sql
#   ./scripts/wpcli.sh shell  # Interactive PHP shell
###############################################################################

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [ $# -eq 0 ]; then
    echo "Enterprise WordPress 2026 — WP-CLI Wrapper"
    echo ""
    echo "Usage: $0 <wp-cli-command> [arguments...]"
    echo ""
    echo "Examples:"
    echo "  $0 plugin list              # List all plugins"
    echo "  $0 plugin install redis-cache --activate"
    echo "  $0 core version             # WordPress version"
    echo "  $0 user list                # List users"
    echo "  $0 option get siteurl       # Get site URL"
    echo "  $0 cache flush              # Flush object cache"
    echo "  $0 db optimize              # Optimize database tables"
    echo "  $0 search-replace 'http://old.com' 'https://new.com'"
    echo "  $0 cron event list           # List scheduled events"
    echo ""
    echo "Full WP-CLI docs: https://developer.wordpress.org/cli/commands/"
    exit 0
fi

# Run WP-CLI via the dedicated container
docker compose run --rm wpcli wp "$@"

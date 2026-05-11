#!/usr/bin/env bash
###############################################################################
# Enterprise WordPress 2026 — S3 Backup Sync
# ============================================================================
# Syncs the local backups directory to an Amazon S3 bucket.
# Uses the official aws-cli docker image to avoid host dependencies.
#
# Usage:
#   ./scripts/s3-sync.sh
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
# CONFIGURATION
# =============================================================================
# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$PROJECT_DIR/.env"
    set +a
else
    error ".env file not found. Please create one from .env.example."
    exit 1
fi

S3_BUCKET="${AWS_S3_BUCKET:-}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"

if [ -z "$S3_BUCKET" ]; then
    error "AWS_S3_BUCKET is not set in .env"
    exit 1
fi

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    warn "AWS credentials not found in .env. Assuming IAM role is used (e.g. EC2 instance profile)."
fi

# =============================================================================
# BANNER
# =============================================================================
echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Enterprise WordPress 2026 — S3 Sync                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
info "Target Bucket: s3://${S3_BUCKET}"
info "Source Dir: ${BACKUP_DIR}"

# =============================================================================
# SYNC TO S3
# =============================================================================
step "Syncing backups to S3..."

# Build docker command arguments
DOCKER_ARGS=(
    "run" "--rm"
    "-v" "${BACKUP_DIR}:/aws-backups:ro"
    "-e" "AWS_DEFAULT_REGION=${AWS_REGION}"
)

# Pass credentials if they exist
if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    DOCKER_ARGS+=("-e" "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}")
    DOCKER_ARGS+=("-e" "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}")
fi

DOCKER_ARGS+=("amazon/aws-cli" "s3" "sync" "/aws-backups/" "s3://${S3_BUCKET}/" "--exact-timestamps" "--delete")

info "Running aws s3 sync..."
docker "${DOCKER_ARGS[@]}"

success "S3 sync complete!"
echo -e "  ${CYAN}You can verify your backups in the AWS Console or using:${NC}"
echo -e "  docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY amazon/aws-cli s3 ls s3://${S3_BUCKET}/"
echo ""

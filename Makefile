###############################################################################
# Enterprise WordPress 2026 — Makefile
# ============================================================================
# Convenient shortcuts for common operations.
#
# Usage: make <target>
# Run 'make help' to see all available targets.
###############################################################################

# Default shell
SHELL := /bin/bash

# Project settings
COMPOSE_FILE := docker-compose.yml
PROJECT_NAME := enterprise-wp

# Colors
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BOLD := \033[1m
NC := \033[0m

.DEFAULT_GOAL := help

# =============================================================================
# LIFECYCLE — Start, stop, restart the stack
# =============================================================================

.PHONY: env-check
env-check:
	@if [ ! -f .env ]; then \
		echo -e "$(YELLOW)No .env file found. Creating one from .env.example...$(NC)"; \
		cp .env.example .env; \
		echo -e "$(YELLOW)Please review and edit .env before proceeding for production use!$(NC)"; \
	fi

.PHONY: up
up: env-check ## Start all services (development mode)
	@echo -e "$(CYAN)Starting services...$(NC)"
	docker compose up -d
	@echo -e "$(GREEN)Stack is running!$(NC)"
	@make --no-print-directory _show-url

.PHONY: up-prod
up-prod: env-check ## Start all services (production mode, no dev override)
	@echo -e "$(CYAN)Starting services in production mode...$(NC)"
	docker compose -f $(COMPOSE_FILE) up -d
	@echo -e "$(GREEN)Production stack is running!$(NC)"

.PHONY: up-monitoring
up-monitoring: env-check ## Start stack with monitoring (Prometheus + Grafana)
	@echo -e "$(CYAN)Starting services with monitoring...$(NC)"
	docker compose -f $(COMPOSE_FILE) -f docker-compose.monitoring.yml up -d
	@echo -e "$(GREEN)Monitoring stack is running! Access Grafana at http://localhost:3000$(NC)"

.PHONY: down
down: ## Stop all services and remove containers
	@echo -e "$(YELLOW)Stopping services...$(NC)"
	docker compose down
	@echo -e "$(GREEN)All services stopped.$(NC)"

.PHONY: down-volumes
down-volumes: ## Stop services and remove ALL data (volumes)
	@echo -e "$(YELLOW)WARNING: This will delete all data!$(NC)"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	docker compose down -v
	@echo -e "$(GREEN)All services and data removed.$(NC)"

.PHONY: restart
restart: ## Restart all services
	@echo -e "$(CYAN)Restarting services...$(NC)"
	docker compose restart
	@echo -e "$(GREEN)Services restarted.$(NC)"

.PHONY: pull
pull: ## Pull latest Docker images
	docker compose pull

# =============================================================================
# LOGS — View service output
# =============================================================================

.PHONY: logs
logs: ## Follow all service logs
	docker compose logs -f --tail=100

.PHONY: logs-wp
logs-wp: ## Follow WordPress logs
	docker compose logs -f --tail=100 wordpress

.PHONY: logs-nginx
logs-nginx: ## Follow Nginx logs
	docker compose logs -f --tail=100 nginx

.PHONY: logs-db
logs-db: ## Follow MariaDB logs
	docker compose logs -f --tail=100 mariadb

# =============================================================================
# DEPLOYMENT & OPERATIONS
# =============================================================================

.PHONY: deploy
deploy: env-check ## Run full deployment script
	./scripts/deploy.sh

.PHONY: deploy-prod
deploy-prod: env-check ## Run production deployment
	./scripts/deploy.sh --production

.PHONY: backup
backup: ## Create full backup (database + files)
	./scripts/backup.sh

.PHONY: restore
restore: ## Restore from latest backup
	./scripts/restore.sh --latest

.PHONY: update
update: ## Safe update: backup, pull, restart
	./scripts/update.sh

.PHONY: status
status: ## Run health checks on all services
	./scripts/healthcheck.sh

# =============================================================================
# SSL CERTIFICATES
# =============================================================================

.PHONY: ssl
ssl: ## Initialize SSL certificates
	./scripts/ssl.sh init

.PHONY: ssl-renew
ssl-renew: ## Renew SSL certificates
	./scripts/ssl.sh renew

.PHONY: ssl-status
ssl-status: ## Check SSL certificate status
	./scripts/ssl.sh status

# =============================================================================
# WP-CLI — WordPress management commands
# =============================================================================

.PHONY: wpcli
wpcli: ## Run WP-CLI command (usage: make wpcli CMD="plugin list")
	@if [ -z "$(CMD)" ]; then \
		echo "Usage: make wpcli CMD=\"<command>\""; \
		echo "Example: make wpcli CMD=\"plugin list\""; \
	else \
		./scripts/wpcli.sh $(CMD); \
	fi

.PHONY: wp-install-plugins
wp-install-plugins: ## Install recommended plugins
	./scripts/wpcli.sh plugin install redis-cache --activate
	./scripts/wpcli.sh redis enable
	@echo -e "$(GREEN)Plugins installed.$(NC)"

# =============================================================================
# SHELL ACCESS — Interactive containers
# =============================================================================

.PHONY: shell-wp
shell-wp: ## Open shell in WordPress container
	docker compose exec wordpress sh

.PHONY: shell-db
shell-db: ## Open MariaDB CLI
	docker compose exec mariadb mariadb -u$${MYSQL_USER:-wordpress} -p$${MYSQL_PASSWORD:-wordpress} $${MYSQL_DATABASE:-wordpress}

.PHONY: shell-nginx
shell-nginx: ## Open shell in Nginx container
	docker compose exec nginx sh

.PHONY: shell-redis
shell-redis: ## Open Redis CLI
	docker compose exec redis redis-cli

# =============================================================================
# CLEANUP — Remove unused resources
# =============================================================================

.PHONY: clean
clean: ## Remove unused Docker images and build cache
	docker image prune -f
	docker builder prune -f
	@echo -e "$(GREEN)Cleanup complete.$(NC)"

.PHONY: clean-all
clean-all: down-volumes clean ## Stop everything and remove all data + images

# =============================================================================
# VALIDATION — Check configs and code
# =============================================================================

.PHONY: validate
validate: ## Validate all configuration files
	@echo -e "$(CYAN)Validating Docker Compose...$(NC)"
	docker compose -f $(COMPOSE_FILE) config --quiet && echo -e "  $(GREEN)✓ docker-compose.yml$(NC)"
	docker compose config --quiet && echo -e "  $(GREEN)✓ docker-compose.override.yml$(NC)"
	@echo -e "$(CYAN)Validating Nginx config...$(NC)"
	docker run --rm \
		-v $(PWD)/config/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
		-v $(PWD)/config/nginx/wordpress-dev.conf:/etc/nginx/conf.d/default.conf:ro \
		nginx:1.27-alpine nginx -t && echo -e "  $(GREEN)✓ Nginx config$(NC)"
	@echo -e "$(CYAN)Running ShellCheck...$(NC)"
	@which shellcheck > /dev/null 2>&1 && \
		shellcheck scripts/*.sh && echo -e "  $(GREEN)✓ All scripts pass$(NC)" || \
		echo -e "  $(YELLOW)! shellcheck not installed (skipping)$(NC)"
	@echo -e "$(GREEN)All validations passed!$(NC)"

# =============================================================================
# HELP
# =============================================================================

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo -e "$(BOLD)Enterprise WordPress 2026 — Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

# =============================================================================
# INTERNAL HELPERS
# =============================================================================

.PHONY: _show-url
_show-url:
	@echo ""
	@echo -e "  $(BOLD)Site:$(NC)  http://localhost:$${NGINX_HTTP_PORT:-8080}"
	@echo -e "  $(BOLD)Admin:$(NC) http://localhost:$${NGINX_HTTP_PORT:-8080}/wp-admin/"
	@echo ""

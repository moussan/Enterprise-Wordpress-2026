<?php
/**
 * Enterprise WordPress 2026 — Extra wp-config.php Settings
 * ============================================================================
 * This file is mounted into the WordPress container and provides additional
 * configuration beyond what the Docker environment variables handle.
 *
 * The main wp-config.php is managed by the WordPress Docker image.
 * Use WORDPRESS_CONFIG_EXTRA in docker-compose.yml for most settings.
 * This file is for reference and can be sourced via a custom entrypoint.
 *
 * @see https://developer.wordpress.org/advanced-administration/wordpress/wp-config/
 */

// ============================================================================
// REDIS OBJECT CACHE
// ============================================================================
// Requires the "Redis Object Cache" plugin by Till Krüss.
// Install: wp plugin install redis-cache --activate
//
// These constants tell the plugin how to connect to Redis.
// The actual connection values should match docker-compose.yml redis service.

if (!defined('WP_REDIS_HOST'))      define('WP_REDIS_HOST', 'redis');
if (!defined('WP_REDIS_PORT'))      define('WP_REDIS_PORT', 6379);
if (!defined('WP_REDIS_DATABASE'))  define('WP_REDIS_DATABASE', 0);
if (!defined('WP_REDIS_TIMEOUT'))   define('WP_REDIS_TIMEOUT', 1);
if (!defined('WP_REDIS_READ_TIMEOUT')) define('WP_REDIS_READ_TIMEOUT', 1);

// Optional: prefix cache keys (useful for multisite or shared Redis).
// if (!defined('WP_REDIS_PREFIX')) define('WP_REDIS_PREFIX', 'wp_');

// ============================================================================
// SECURITY CONSTANTS
// ============================================================================

// Disable the theme/plugin editor in wp-admin (prevents code injection via admin).
if (!defined('DISALLOW_FILE_EDIT')) define('DISALLOW_FILE_EDIT', true);

// Disable all file modifications (themes, plugins, core updates via admin).
// Set to true in locked-down production environments.
// if (!defined('DISALLOW_FILE_MODS')) define('DISALLOW_FILE_MODS', true);

// Force SSL for admin panel (requires valid SSL certificate).
if (!defined('FORCE_SSL_ADMIN')) define('FORCE_SSL_ADMIN', true);

// Only allow minor core auto-updates (security patches only).
if (!defined('WP_AUTO_UPDATE_CORE')) define('WP_AUTO_UPDATE_CORE', 'minor');

// Block external HTTP requests (uncomment for maximum security).
// Note: This breaks plugins that need external API access.
// if (!defined('WP_HTTP_BLOCK_EXTERNAL')) define('WP_HTTP_BLOCK_EXTERNAL', true);
// if (!defined('WP_ACCESSIBLE_HOSTS')) define('WP_ACCESSIBLE_HOSTS', 'api.wordpress.org,downloads.wordpress.org');

// ============================================================================
// PERFORMANCE CONSTANTS
// ============================================================================

// Memory limit for WordPress operations.
if (!defined('WP_MEMORY_LIMIT'))     define('WP_MEMORY_LIMIT', '512M');
if (!defined('WP_MAX_MEMORY_LIMIT')) define('WP_MAX_MEMORY_LIMIT', '512M');

// Limit post revisions (saves database space).
if (!defined('WP_POST_REVISIONS')) define('WP_POST_REVISIONS', 10);

// Autosave interval in seconds (reduce database writes).
if (!defined('AUTOSAVE_INTERVAL')) define('AUTOSAVE_INTERVAL', 120);

// Empty trash after 14 days.
if (!defined('EMPTY_TRASH_DAYS')) define('EMPTY_TRASH_DAYS', 14);

// ============================================================================
// CRON CONFIGURATION
// ============================================================================

// Disable WP-Cron (use system cron instead for reliability).
// When true, add a system cron: */5 * * * * curl -s https://yourdomain.com/wp-cron.php
// if (!defined('DISABLE_WP_CRON')) define('DISABLE_WP_CRON', true);
// if (!defined('ALTERNATE_WP_CRON')) define('ALTERNATE_WP_CRON', false);

// ============================================================================
// TABLE PREFIX NOTE
// ============================================================================
// The default table prefix is 'wp_'. For additional security, change it to
// a random prefix in your .env file (WP_TABLE_PREFIX=wp_a8f3_).
// This makes SQL injection attacks harder by obscuring table names.

// ============================================================================
// MULTISITE (uncomment to enable)
// ============================================================================
// if (!defined('WP_ALLOW_MULTISITE')) define('WP_ALLOW_MULTISITE', true);
// if (!defined('MULTISITE'))          define('MULTISITE', true);
// if (!defined('SUBDOMAIN_INSTALL'))  define('SUBDOMAIN_INSTALL', false);

// ============================================================================
// RECOMMENDED PLUGINS
// ============================================================================
// Install via WP-CLI after deployment:
//
// # Object cache (connects to Redis):
// wp plugin install redis-cache --activate
//
// # Security:
// wp plugin install wordfence --activate          # Firewall + malware scanner
// wp plugin install two-factor --activate         # 2FA for admin accounts
// wp plugin install sucuri-scanner --activate     # Security auditing
//
// # Performance:
// wp plugin install autoptimize --activate        # CSS/JS optimization
// wp plugin install webp-express --activate       # WebP image conversion
//
// # SEO:
// wp plugin install wordpress-seo --activate      # Yoast SEO
//
// # Backup:
// wp plugin install updraftplus --activate        # Scheduled backups
//
// # Monitoring:
// wp plugin install query-monitor --activate      # Dev: query/hook debugging

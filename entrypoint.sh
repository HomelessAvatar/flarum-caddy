#!/bin/bash
set -e

echo "[flarum-caddy] ==================================================="
echo "[flarum-caddy] Starting Flarum (Caddy Web Server + PHP 8.4-FPM)   "
echo "[flarum-caddy] ==================================================="

# Ensure persistent directories exist in /data
mkdir -p /data/assets /data/storage /data/extensions /data/extensions/.cache

# If persistent /data/assets is empty, seed it with default assets from /opt/flarum/public/assets
if [ -z "$(ls -A /data/assets 2>/dev/null)" ]; then
    echo "[flarum-caddy] Seeding default assets to /data/assets..."
    cp -Rf /opt/flarum/public/assets/* /data/assets/ 2>/dev/null || true
fi

# Ensure symlinks for assets and storage
rm -rf /opt/flarum/public/assets /opt/flarum/storage
ln -sfn /data/assets /opt/flarum/public/assets
ln -sfn /data/storage /opt/flarum/storage

# Fix permissions for www-data
chown -h www-data:www-data /opt/flarum/public/assets /opt/flarum/storage
chown -R www-data:www-data /data /opt/flarum/storage /opt/flarum/public/assets
chmod -R 775 /data/storage /data/assets

# Wait for MariaDB / MySQL using PHP socket
DB_HOST_NAME="${DB_HOST:-mariadb}"
DB_PORT_NUM="${DB_PORT:-3306}"
echo "[flarum-caddy] Waiting for database connection at ${DB_HOST_NAME}:${DB_PORT_NUM}..."
php -r "
for (\$i = 0; \$i < 40; \$i++) {
    \$fp = @fsockopen('${DB_HOST_NAME}', (int)'${DB_PORT_NUM}', \$errno, \$errstr, 2);
    if (\$fp) {
        fclose(\$fp);
        echo \"[flarum-caddy] Database is reachable and accepting connections.\n\";
        exit(0);
    }
    sleep(1);
}
echo \"[flarum-caddy] ERROR: Database could not be reached after 40 seconds.\n\";
exit(1);
"

# Generate or update /opt/flarum/config.php
echo "[flarum-caddy] Configuring /opt/flarum/config.php..."
cat <<EOF > /opt/flarum/config.php
<?php return array (
  'debug' => filter_var(getenv('FLARUM_DEBUG') ?: 'false', FILTER_VALIDATE_BOOLEAN),
  'database' => 
  array (
    'driver' => 'mysql',
    'host' => getenv('DB_HOST') ?: 'mariadb',
    'port' => (int)(getenv('DB_PORT') ?: 3306),
    'database' => getenv('DB_NAME') ?: 'flarum',
    'username' => getenv('DB_USER') ?: 'flarum',
    'password' => getenv('DB_PASS') ?: (getenv('DB_PASSWORD') ?: ''),
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_unicode_ci',
    'prefix' => getenv('DB_PREF') ?: (getenv('DB_PREFIX') ?: 'fl_'),
    'strict' => false,
    'engine' => 'InnoDB',
    'prefix_indexes' => true,
  ),
  'url' => getenv('FORUM_URL') ?: (getenv('FLARUM_BASE_URL') ?: 'http://localhost:8000'),
  'paths' => 
  array (
    'api' => 'api',
    'admin' => 'admin',
  ),
  'headers' => 
  array (
    'poweredByHeader' => true,
    'referrerPolicy' => 'same-origin',
  ),
);
EOF

chown www-data:www-data /opt/flarum/config.php
chmod 640 /opt/flarum/config.php

# Optional: Install extra extensions if defined in /data/extensions/list
if [ -s "/data/extensions/list" ]; then
    echo "[flarum-caddy] Installing custom extensions from /data/extensions/list..."
    extensions=()
    while IFS= read -r ext; do
        ext="\$(echo "\$ext" | xargs)"
        [ -z "\$ext" ] && continue
        [[ "\$ext" == \#* ]] && continue
        extensions+=("\$ext")
    done < /data/extensions/list

    if [ "\${#extensions[@]}" -gt 0 ]; then
        echo "[flarum-caddy] Running composer require for: \${extensions[*]}"
        COMPOSER_CACHE_DIR="/data/extensions/.cache" su-exec www-data composer require --working-dir=/opt/flarum "\${extensions[@]}" --no-interaction
    fi
fi

# Run database migrations
echo "[flarum-caddy] Running database migrations..."
su-exec www-data php /opt/flarum/flarum migrate

# Clear cache
echo "[flarum-caddy] Clearing and warming Flarum cache..."
su-exec www-data php /opt/flarum/flarum cache:clear

# Start PHP-FPM daemon
echo "[flarum-caddy] Starting PHP-FPM 8.4..."
php-fpm -D

# Start Caddy in foreground
echo "[flarum-caddy] Starting Caddy on :8000..."
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile

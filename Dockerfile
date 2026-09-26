ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm-alpine

ARG FLARUM_VERSION=v1.8.20

LABEL org.opencontainers.image.title="flarum-caddy" \
      org.opencontainers.image.description="Ultra-lightweight Flarum Docker image powered by Caddy and PHP 8.4 (Zero Nginx)" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/HomelessAvatar/flarum-caddy"

# Set environment defaults
ENV TZ=UTC \
    FLARUM_DEBUG=false \
    DB_HOST=mariadb \
    DB_PORT=3306 \
    DB_NAME=flarum \
    DB_USER=flarum \
    DB_PREFIX=fl_

# Install system dependencies, Caddy web server, and utilities
RUN apk add --no-cache \
    bash \
    caddy \
    curl \
    git \
    icu-data-full \
    mariadb-client \
    su-exec \
    tzdata

# Install official PHP extension installer
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Install required PHP extensions for Flarum
RUN install-php-extensions \
    bcmath \
    curl \
    exif \
    gd \
    gmp \
    intl \
    opcache \
    pdo_mysql \
    zip

# Install Composer 2
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Configure PHP runtime optimizations
RUN { \
    echo 'memory_limit = 256M'; \
    echo 'upload_max_filesize = 16M'; \
    echo 'post_max_size = 16M'; \
    echo 'max_execution_time = 300'; \
    echo 'error_reporting = E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED'; \
    echo 'display_errors = Off'; \
    echo 'opcache.enable = 1'; \
    echo 'opcache.memory_consumption = 128'; \
    echo 'opcache.interned_strings_buffer = 16'; \
    echo 'opcache.max_accelerated_files = 10000'; \
} > /usr/local/etc/php/conf.d/flarum.ini

# Initialize Flarum skeleton and bundled extensions
WORKDIR /opt/flarum
RUN COMPOSER_CACHE_DIR=/tmp composer create-project flarum/flarum:${FLARUM_VERSION} /opt/flarum --no-install \
 && COMPOSER_CACHE_DIR=/tmp composer require flarum/core:${FLARUM_VERSION} -W --no-interaction \
 && composer clear-cache \
 && chown -R www-data:www-data /opt/flarum \
 && rm -rf /root/.composer /tmp/*

# Copy Caddyfile and entrypoint script
COPY Caddyfile /etc/caddy/Caddyfile
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000
VOLUME ["/data"]

ENTRYPOINT ["/entrypoint.sh"]

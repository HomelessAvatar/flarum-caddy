# syntax=docker/dockerfile:1
ARG PHP_VERSION=8.4

# Step 1: Extract official Caddy binary
FROM caddy:2-alpine AS caddy-bin

# Step 2: Build Flarum Caddy image
FROM php:${PHP_VERSION}-fpm-alpine

ARG FLARUM_VERSION=v1.8.20
ARG FLARUM_SKELETON=^1.8
ENV FLARUM_VERSION=${FLARUM_VERSION}

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

# Install system dependencies and utilities
RUN apk add --no-cache \
    bash \
    curl \
    git \
    icu-data-full \
    jq \
    mariadb-client \
    su-exec \
    tzdata

# Copy official Caddy v2 binary
COPY --from=caddy-bin /usr/bin/caddy /usr/bin/caddy

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

# Initialize clean Flarum skeleton and record baseline extensions
WORKDIR /opt/flarum
RUN COMPOSER_CACHE_DIR=/tmp composer create-project flarum/flarum:${FLARUM_SKELETON} /opt/flarum --no-install \
 && COMPOSER_CACHE_DIR=/tmp composer require flarum/core:${FLARUM_VERSION} -W --no-interaction \
 && php -r '$c = json_decode(file_get_contents("/opt/flarum/composer.json"), true); file_put_contents("/opt/flarum/.flarum-base-extensions", implode(PHP_EOL, array_keys($c["require"] ?? [])) . PHP_EOL);' \
 && composer clear-cache \
 && chown -R www-data:www-data /opt/flarum \
 && rm -rf /root/.composer /tmp/*

# Copy Caddyfile, entrypoint script, and extension CLI helper
COPY Caddyfile /etc/caddy/Caddyfile
COPY entrypoint.sh /entrypoint.sh
COPY extension /usr/local/bin/extension
RUN chmod +x /entrypoint.sh /usr/local/bin/extension

EXPOSE 8000
VOLUME ["/data"]

ENTRYPOINT ["/entrypoint.sh"]

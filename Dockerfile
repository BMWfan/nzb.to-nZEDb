FROM composer:1.9.3 as vendor


WORKDIR /tmp/

COPY nZEDb/composer.json composer.json
#COPY composer.lock composer.lock


RUN composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist

#ADD libs/smarty/configs/smarty.conf /tmp/vendor/smarty/smarty/libs/configs/smarty.conf


ARG ALPINE_VERSION=3.16
FROM alpine:3.16
LABEL Maintainer="Tim de Pater <code@trafex.nl>"
LABEL Description="Lightweight container with Nginx 1.22 & PHP 8.1 based on Alpine Linux."
# Setup document root
WORKDIR /var/www/httpdocs

# Install packages and remove default server definition
RUN apk add --no-cache \
  curl \
  nginx \
  php8-simplexml \
  php8 \
  php8-ctype \
  php8-curl \
  php8-dom \
  php8-fpm \
  php8-gd \
  php8-intl \
  php8-mbstring \
  php8-mysqli \
  php8-opcache \
  php8-openssl \
  php8-phar \
  php8-session \
  php8-xml \
  php8-xmlreader \
  php8-zlib \
  supervisor

# Create symlink so programs depending on `php` still function
#RUN ln -s /usr/bin/php8 /usr/bin/php

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php8/php-fpm.d/www.conf
COPY config/php.ini /etc/php8/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create Folder for WebApplication
RUN mkdir /var/www/cache
RUN mkdir /var/www/cookies
RUN mkdir /var/www/logs
RUN mkdir /var/www/nzbs

# Copy WebServer content 
COPY ./nZEDb/httpdocs /var/www/httpdocs/. 

# Copy libs out of vendor image
COPY --chown=nobody --from=vendor /tmp/vendor/smarty/smarty/libs /var/www/httpdocs/libs/smarty/
COPY --chown=nobody --from=vendor /tmp/vendor/ /var/www/httpdocs/inc/vendor/



# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody:nobody /var/www /run /var/lib/nginx /var/log/nginx

# Switch to use a non-root user from here on
USER nobody

# Add application
#COPY --chown=nobody src/ /var/www/

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
#CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping

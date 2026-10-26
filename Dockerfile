# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# app: PHP-FPM with Drupal 11, CiviCRM, Drush, cv and Git.
# ---------------------------------------------------------------------------
FROM ubuntu:24.04 AS app

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git mariadb-client patch unzip \
      php8.3-fpm php8.3-cli php8.3-bcmath php8.3-curl php8.3-gd php8.3-intl \
      php8.3-mbstring php8.3-mysql php8.3-opcache php8.3-soap php8.3-xml php8.3-zip \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/php \
 && git config --system --add safe.directory /var/www/html

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# cv: the CiviCRM command line tool (used to install CiviCRM).
ARG CV_URL=https://download.civicrm.org/cv/cv.phar
RUN curl -fsSL "$CV_URL" -o /usr/local/bin/cv && chmod 755 /usr/local/bin/cv

COPY docker/php/php.ini  /etc/php/8.3/fpm/conf.d/90-dgdcn.ini
COPY docker/php/php.ini  /etc/php/8.3/cli/conf.d/90-dgdcn.ini
COPY docker/php/www.conf /etc/php/8.3/fpm/pool.d/www.conf
RUN sed -i 's#^error_log = .*#error_log = /proc/self/fd/2#' /etc/php/8.3/fpm/php-fpm.conf

# Everything under /var/www belongs to www-data, the user Drush, Git and
# Composer are meant to run as (its home directory is /var/www).
RUN mkdir -p /var/www/html /var/www/private \
 && chown -R www-data:www-data /var/www
WORKDIR /var/www/html
USER www-data

COPY --chown=www-data:www-data composer.json composer.lock ./
COPY --chown=www-data:www-data patches/ patches/
RUN composer install --no-dev --no-interaction --no-progress --optimize-autoloader \
 && composer clear-cache \
 && mkdir -p web/sites/default/files web/extensions

COPY --chown=www-data:www-data docker/drupal/settings.php docker/drupal/civicrm.settings.php web/sites/default/

USER root
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
ENV PATH=/var/www/html/vendor/bin:$PATH

EXPOSE 9000
ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm8.3", "--nodaemonize"]

# ---------------------------------------------------------------------------
# web: Nginx serving the static files of the same build.
# ---------------------------------------------------------------------------
FROM nginx:1.28-alpine AS web

COPY --from=app /var/www/html/web /var/www/html/web
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf

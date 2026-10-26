# dgdcn: Drush, Git, Drupal, CiviCRM, Nginx

A Docker Compose stack for Drupal 11 with CiviCRM 6, set up so that:

1. **Drush** is installed (`vendor/bin/drush`, Drush 13) and runs as `www-data`.
2. **Git** is installed and runs as `www-data` (`/var/www/html` is a safe directory).
3. **Drupal** has a private files folder (`/var/www/private/drupal`), outside the web root and on its own volume. It is the default download method.
4. **CiviCRM extensions** live in `web/extensions/` on a persistent volume, writable by PHP and served (static assets only) by Nginx. The paths are pinned in `civicrm.settings.php`.
5. **Nginx is locked down for CiviCRM.** PHP runs only through Drupal's front controllers. CiviCRM's logs, compiled templates, uploads and custom files are kept out of the web root, and their old public paths are denied. Uploaded `.php` files, hidden files and source files are never served.
6. **Views can query CiviCRM.** CiviCRM has its own `civicrm` database. Drupal declares it as the `civicrm` connection, the Drupal DB user gets read-only access to it, and `civicrm_entity` exposes CiviCRM entities (contacts, events and so on) to Views.

| Service | Image | Role |
|---|---|---|
| `web` | `nginx:1.28-alpine` + the site's static files | HTTP on port 8080 |
| `app` | Ubuntu 24.04, PHP 8.3-FPM, Composer, Drush, cv, Git | Drupal + CiviCRM |
| `db` | `mariadb:11.4` | `drupal` and `civicrm` databases |

## Run it

```sh
cp .env.example .env     # then set every "change-me" value
docker compose up -d --build
docker compose logs -f app   # first start installs Drupal and CiviCRM (~1 min)
```

Open http://localhost:8080 and log in as `DRUPAL_ADMIN_USER` / `DRUPAL_ADMIN_PASSWORD`. CiviCRM is at `/civicrm`.

Set `AUTO_INSTALL=0` in `.env` to skip the first-run install, e.g. when restoring an existing site.

## Day to day

Always run tools as `www-data`:

```sh
docker compose exec -u www-data app drush status
docker compose exec -u www-data app drush uli
docker compose exec -u www-data app cv --cwd=web api4 Contact.get +l 5
docker compose exec -u www-data app git status
```

To update Drupal or CiviCRM, run `composer update` (or edit `composer.json`), commit `composer.lock`, then run `docker compose up -d --build` followed by `drush updatedb`.

## Layout

```
compose.yaml, Dockerfile        stack and images (app + web targets)
composer.json / composer.lock   Drupal, CiviCRM, Drush, civicrm_entity
patches/                        local patches applied by Composer
docker/drupal/settings.php      env-driven Drupal settings (both DB connections)
docker/drupal/civicrm.settings.php  stub that loads the generated CiviCRM settings
docker/entrypoint.sh            first-run install (drush site:install, cv core:install)
docker/nginx/default.conf       hardened Nginx config
docker/mariadb/10-civicrm.sh    creates the civicrm DB/user and the read-only grant
```

Volumes: `db`, `files` (public files), `private` (Drupal private files, CiviCRM settings, logs, uploads and compiled templates) and `extensions`.

## Notes

- `drupal/civicrm_entity` is pulled from its maintainer's GitHub repository (branch `4.0.x`). `patches/civicrm_entity-drupal-11.4-signature.patch` makes it work on Drupal 11.4. Remove the patch once a fixed release is out.
- The `GD library` warning on the status report means Ubuntu's PHP GD can't encode AVIF. It doesn't affect anything else.
- History: this repo began in 2016 as a single Ubuntu 16.04 / PHP 7.0 / Drupal 7 container under supervisord. That version never built and was replaced with this stack in 2026.

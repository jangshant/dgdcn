#!/bin/bash
# Prepares writable directories and, on first start, installs Drupal and
# CiviCRM. Drush, cv and Git always run as www-data, never as root.
set -euo pipefail

as_www() { runuser -u www-data -- "$@"; }

WEB=/var/www/html/web
PRIVATE=/var/www/private
BASE_URL=${BASE_URL:-http://localhost:8080}

mkdir -p "$WEB/sites/default/files" "$WEB/extensions" \
         "$PRIVATE/drupal" "$PRIVATE/civicrm" "$PRIVATE/config/sync"
chown www-data:www-data "$WEB/sites/default/files" "$WEB/extensions" \
      "$PRIVATE" "$PRIVATE/drupal" "$PRIVATE/civicrm" "$PRIVATE/config" "$PRIVATE/config/sync"

echo "Waiting for the database..."
until mariadb-admin ping -h "${DB_HOST:-db}" -u "$DRUPAL_DB_USER" -p"$DRUPAL_DB_PASSWORD" --skip-ssl --silent; do
  sleep 2
done

if [ "${AUTO_INSTALL:-1}" = 1 ]; then
  if ! as_www drush status --field=bootstrap 2>/dev/null | grep -q Successful; then
    echo "Installing Drupal..."
    as_www drush site:install standard --yes \
      --site-name="${SITE_NAME:-dgdcn}" \
      --account-name="${DRUPAL_ADMIN_USER:-admin}" \
      --account-pass="${DRUPAL_ADMIN_PASSWORD:?DRUPAL_ADMIN_PASSWORD is required}"
    # Make "private" the default download method for new file fields.
    as_www drush config:set system.file default_scheme private --yes
  fi

  if [ ! -f "$PRIVATE/civicrm/civicrm.settings.php" ]; then
    echo "Installing CiviCRM..."
    as_www cv core:install --cwd="$WEB" --no-interaction \
      --url="$BASE_URL" \
      --db="mysql://$CIVICRM_DB_USER:$CIVICRM_DB_PASSWORD@${DB_HOST:-db}:${DB_PORT:-3306}/${CIVICRM_DB_NAME:-civicrm}" \
      -m settingsPath="$PRIVATE/civicrm/civicrm.settings.php" \
      -m "mandatorySettings.uploadDir=[civicrm.private]/upload/" \
      -m "mandatorySettings.customFileUploadDir=[civicrm.private]/custom/" \
      -m "mandatorySettings.extensionsDir=[cms.root]/extensions/" \
      -m "mandatorySettings.extensionsURL=[cms.root]/extensions/"
    as_www cv --cwd="$WEB" api4 Setting.set +v debug_enabled=0 > /dev/null
  fi

  # Exposes CiviCRM entities (contacts, events, ...) to Drupal Views.
  if ! as_www drush pm:list --status=enabled --field=name | grep -qx civicrm_entity; then
    as_www drush pm:install civicrm_entity --yes
    as_www drush cache:rebuild
  fi
fi

exec "$@"

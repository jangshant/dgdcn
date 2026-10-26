# Sourced (not executed, so keep it non-executable) by the MariaDB entrypoint
# once, when the volume is first initialised. The image itself creates the
# Drupal database and user from MARIADB_DATABASE/MARIADB_USER.
#
# CiviCRM gets its own database and user. The Drupal user may only read it,
# which is all Views needs.
docker_process_sql <<-EOSQL
	CREATE DATABASE IF NOT EXISTS \`${CIVICRM_DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
	CREATE USER IF NOT EXISTS '${CIVICRM_DB_USER}'@'%' IDENTIFIED BY '${CIVICRM_DB_PASSWORD}';
	GRANT ALL PRIVILEGES ON \`${CIVICRM_DB_NAME}\`.* TO '${CIVICRM_DB_USER}'@'%';
	GRANT SELECT ON \`${CIVICRM_DB_NAME}\`.* TO '${MARIADB_USER}'@'%';
	FLUSH PRIVILEGES;
EOSQL

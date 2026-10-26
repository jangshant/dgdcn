<?php

/**
 * @file
 * Drupal settings, configured from the container environment.
 */

$env = static fn(string $name, ?string $default = NULL): ?string => getenv($name) !== FALSE ? getenv($name) : $default;

$databases['default']['default'] = [
  'driver' => 'mysql',
  'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
  'autoload' => 'core/modules/mysql/src/Driver/Database/mysql/',
  'host' => $env('DB_HOST', 'db'),
  'port' => $env('DB_PORT', '3306'),
  'database' => $env('DRUPAL_DB_NAME', 'drupal'),
  'username' => $env('DRUPAL_DB_USER', 'drupal'),
  'password' => $env('DRUPAL_DB_PASSWORD', ''),
  'prefix' => '',
  'collation' => 'utf8mb4_general_ci',
  'isolation_level' => 'READ COMMITTED',
];

// CiviCRM lives in its own database. Declaring it as the "civicrm"
// connection lets Views (through the civicrm_entity module) query CiviCRM
// tables with fully-qualified names, e.g. `civicrm`.`civicrm_contact`.
// The Drupal DB user has read-only access to it; see docker/mariadb/.
$databases['civicrm']['default'] = [
  'database' => $env('CIVICRM_DB_NAME', 'civicrm'),
] + $databases['default']['default'];

$settings['hash_salt'] = $env('DRUPAL_HASH_SALT', '');
$settings['update_free_access'] = FALSE;
// Matches Drupal 13 behaviour; server-side validation still applies.
$settings['enable_html5_validation'] = FALSE;

// Private files live outside the web root, on their own volume.
$settings['file_private_path'] = '/var/www/private/drupal';
$settings['file_temp_path'] = '/tmp';
$settings['config_sync_directory'] = '/var/www/private/config/sync';

$settings['trusted_host_patterns'] = array_filter(explode(',', $env('DRUPAL_TRUSTED_HOSTS', '^localhost$,^127\.0\.0\.1$')));
$settings['reverse_proxy'] = (bool) $env('DRUPAL_REVERSE_PROXY', '');

$settings['file_scan_ignore_directories'] = ['node_modules', 'bower_components'];
$settings['entity_update_batch_size'] = 50;
$settings['entity_update_backup'] = TRUE;
$settings['migrate_node_migrate_type_classic'] = FALSE;

if (file_exists($app_root . '/' . $site_path . '/settings.local.php')) {
  include $app_root . '/' . $site_path . '/settings.local.php';
}

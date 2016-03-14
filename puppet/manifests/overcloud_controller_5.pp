
$keystone_enable_db_purge = hiera('keystone_enable_db_purge', true)
$nova_enable_db_purge = hiera('nova_enable_db_purge', true)
$cinder_enable_db_purge = hiera('cinder_enable_db_purge', true)
$heat_enable_db_purge = hiera('heat_enable_db_purge', true)

if $keystone_enable_db_purge {
  include ::keystone::cron::token_flush
}
if $nova_enable_db_purge {
  include ::nova::cron::archive_deleted_rows
}
if $cinder_enable_db_purge {
  include ::cinder::cron::db_purge
}
if $heat_enable_db_purge {
  include ::heat::cron::purge_deleted
}

if downcase(hiera('bootstrap_nodeid')) == $::hostname {
  include ::keystone::roles::admin
  # Class ::heat::keystone::domain has to run on bootstrap node
  # because it creates DB entities via API calls.
  include ::heat::keystone::domain

  Class['::keystone::roles::admin'] -> Class['::heat::keystone::domain']
} else {
  # On non-bootstrap node we don't need to create Keystone resources again
  class { '::heat::keystone::domain':
    manage_domain => false,
    manage_user   => false,
    manage_role   => false,
  }
}




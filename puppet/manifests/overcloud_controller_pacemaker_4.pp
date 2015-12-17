# Step 4

class { '::keystone':
  sync_db        => $sync_db,
  manage_service => false,
  enabled        => false,
}

#TODO: need a cleanup-keystone-tokens.sh solution here
keystone_config {
  'ec2/driver': value => 'keystone.contrib.ec2.backends.sql.Ec2';
}
file { [ '/etc/keystone/ssl', '/etc/keystone/ssl/certs', '/etc/keystone/ssl/private' ]:
  ensure  => 'directory',
  owner   => 'keystone',
  group   => 'keystone',
  require => Package['keystone'],
}
file { '/etc/keystone/ssl/certs/signing_cert.pem':
  content => hiera('keystone_signing_certificate'),
  owner   => 'keystone',
  group   => 'keystone',
  notify  => Service['keystone'],
  require => File['/etc/keystone/ssl/certs'],
}
file { '/etc/keystone/ssl/private/signing_key.pem':
  content => hiera('keystone_signing_key'),
  owner   => 'keystone',
  group   => 'keystone',
  notify  => Service['keystone'],
  require => File['/etc/keystone/ssl/private'],
}
file { '/etc/keystone/ssl/certs/ca.pem':
  content => hiera('keystone_ca_certificate'),
  owner   => 'keystone',
  group   => 'keystone',
  notify  => Service['keystone'],
  require => File['/etc/keystone/ssl/certs'],
}

$glance_backend = downcase(hiera('glance_backend', 'swift'))
case $glance_backend {
    'swift': { $backend_store = 'glance.store.swift.Store' }
    'file': { $backend_store = 'glance.store.filesystem.Store' }
    'rbd': { $backend_store = 'glance.store.rbd.Store' }
    default: { fail('Unrecognized glance_backend parameter.') }
}
$http_store = ['glance.store.http.Store']
$glance_store = concat($http_store, $backend_store)

if $glance_backend == 'file' and hiera('glance_file_pcmk_manage', false) {
  $secontext = 'context="system_u:object_r:glance_var_lib_t:s0"'
  pacemaker::resource::filesystem { 'glance-fs':
    device       => hiera('glance_file_pcmk_device'),
    directory    => hiera('glance_file_pcmk_directory'),
    fstype       => hiera('glance_file_pcmk_fstype'),
    fsoptions    => join([$secontext, hiera('glance_file_pcmk_options', '')],','),
    clone_params => '',
  }
}

# TODO: notifications, scrubber, etc.
include ::glance
class { '::glance::api':
  known_stores   => $glance_store,
  manage_service => false,
  enabled        => false,
}
class { '::glance::registry' :
  sync_db        => $sync_db,
  manage_service => false,
  enabled        => false,
}
include join(['::glance::backend::', $glance_backend])

class { '::nova' :
  memcached_servers => suffix(hiera('memcache_node_ips'), ':11211'),
}

include ::nova::config

class { '::nova::api' :
  sync_db        => $sync_db,
  manage_service => false,
  enabled        => false,
}
class { '::nova::cert' :
  manage_service => false,
  enabled        => false,
}
class { '::nova::conductor' :
  manage_service => false,
  enabled        => false,
}
class { '::nova::consoleauth' :
  manage_service => false,
  enabled        => false,
}
class { '::nova::vncproxy' :
  manage_service => false,
  enabled        => false,
}
include ::nova::scheduler::filter
class { '::nova::scheduler' :
  manage_service => false,
  enabled        => false,
}
include ::nova::network::neutron

# Neutron class definitions
include ::neutron
class { '::neutron::server' :
  sync_db        => $sync_db,
  manage_service => false,
  enabled        => false,
}
include ::neutron::server::notifications
if  hiera('neutron::core_plugin') == 'neutron.plugins.nuage.plugin.NuagePlugin' {
  include ::neutron::plugins::nuage
}
if hiera('neutron::enable_dhcp_agent',true) {
  class { '::neutron::agents::dhcp' :
    manage_service => false,
    enabled        => false,
  }
  file { '/etc/neutron/dnsmasq-neutron.conf':
    content => hiera('neutron_dnsmasq_options'),
    owner   => 'neutron',
    group   => 'neutron',
    notify  => Service['neutron-dhcp-service'],
    require => Package['neutron'],
  }
}
if hiera('neutron::enable_l3_agent',true) {
  class { '::neutron::agents::l3' :
    manage_service => false,
    enabled        => false,
  }
}
if hiera('neutron::enable_metadata_agent',true) {
  class { '::neutron::agents::metadata':
    manage_service => false,
    enabled        => false,
  }
}
include ::neutron::plugins::ml2
class { '::neutron::agents::ml2::ovs':
  manage_service => false,
  enabled        => false,
}

if 'cisco_ucsm' in hiera('neutron::plugins::ml2::mechanism_drivers') {
  include ::neutron::plugins::ml2::cisco::ucsm
}
if 'cisco_nexus' in hiera('neutron::plugins::ml2::mechanism_drivers') {
  include ::neutron::plugins::ml2::cisco::nexus
  include ::neutron::plugins::ml2::cisco::type_nexus_vxlan
}
if 'cisco_n1kv' in hiera('neutron::plugins::ml2::mechanism_drivers') {
  include ::neutron::plugins::ml2::cisco::nexus1000v

  class { '::neutron::agents::n1kv_vem':
    n1kv_source  => hiera('n1kv_vem_source', undef),
    n1kv_version => hiera('n1kv_vem_version', undef),
  }

  class { '::n1k_vsm':
    n1kv_source  => hiera('n1kv_vsm_source', undef),
    n1kv_version => hiera('n1kv_vsm_version', undef),
  }
}

if hiera('neutron_enable_bigswitch_ml2', false) {
  include ::neutron::plugins::ml2::bigswitch::restproxy
}
neutron_l3_agent_config {
  'DEFAULT/ovs_use_veth': value => hiera('neutron_ovs_use_veth', false);
}
neutron_dhcp_agent_config {
  'DEFAULT/ovs_use_veth': value => hiera('neutron_ovs_use_veth', false);
}

include ::cinder
class { '::cinder::api':
  sync_db        => $sync_db,
  manage_service => false,
  enabled        => false,
}
class { '::cinder::scheduler' :
  manage_service => false,
  enabled        => false,
}
class { '::cinder::volume' :
  manage_service => false,
  enabled        => false,
}
include ::cinder::glance
class { '::cinder::setup_test_volume':
  size => join([hiera('cinder_lvm_loop_device_size'), 'M']),
}

$cinder_enable_iscsi = hiera('cinder_enable_iscsi_backend', true)
if $cinder_enable_iscsi {
  $cinder_iscsi_backend = 'tripleo_iscsi'

  cinder::backend::iscsi { $cinder_iscsi_backend :
    iscsi_ip_address => hiera('cinder_iscsi_ip_address'),
    iscsi_helper     => hiera('cinder_iscsi_helper'),
  }
}

if $enable_ceph {

  $ceph_pools = hiera('ceph_pools')
  ceph::pool { $ceph_pools :
    pg_num  => hiera('ceph::profile::params::osd_pool_default_pg_num'),
    pgp_num => hiera('ceph::profile::params::osd_pool_default_pgp_num'),
    size    => hiera('ceph::profile::params::osd_pool_default_size'),
  }

  $cinder_pool_requires = [Ceph::Pool[hiera('cinder_rbd_pool_name')]]

} else {
  $cinder_pool_requires = []
}

if hiera('cinder_enable_rbd_backend', false) {
  $cinder_rbd_backend = 'tripleo_ceph'

  cinder::backend::rbd { $cinder_rbd_backend :
    rbd_pool        => hiera('cinder_rbd_pool_name'),
    rbd_user        => hiera('ceph_client_user_name'),
    rbd_secret_uuid => hiera('ceph::profile::params::fsid'),
    require         => $cinder_pool_requires,
  }
}

if hiera('cinder_enable_netapp_backend', false) {
  $cinder_netapp_backend = hiera('cinder::backend::netapp::title')

  cinder_config {
    "${cinder_netapp_backend}/host": value => 'hostgroup';
  }

  if hiera('cinder::backend::netapp::nfs_shares', undef) {
    $cinder_netapp_nfs_shares = split(hiera('cinder::backend::netapp::nfs_shares', undef), ',')
  }

  cinder::backend::netapp { $cinder_netapp_backend :
    netapp_login                 => hiera('cinder::backend::netapp::netapp_login', undef),
    netapp_password              => hiera('cinder::backend::netapp::netapp_password', undef),
    netapp_server_hostname       => hiera('cinder::backend::netapp::netapp_server_hostname', undef),
    netapp_server_port           => hiera('cinder::backend::netapp::netapp_server_port', undef),
    netapp_size_multiplier       => hiera('cinder::backend::netapp::netapp_size_multiplier', undef),
    netapp_storage_family        => hiera('cinder::backend::netapp::netapp_storage_family', undef),
    netapp_storage_protocol      => hiera('cinder::backend::netapp::netapp_storage_protocol', undef),
    netapp_transport_type        => hiera('cinder::backend::netapp::netapp_transport_type', undef),
    netapp_vfiler                => hiera('cinder::backend::netapp::netapp_vfiler', undef),
    netapp_volume_list           => hiera('cinder::backend::netapp::netapp_volume_list', undef),
    netapp_vserver               => hiera('cinder::backend::netapp::netapp_vserver', undef),
    netapp_partner_backend_name  => hiera('cinder::backend::netapp::netapp_partner_backend_name', undef),
    nfs_shares                   => $cinder_netapp_nfs_shares,
    nfs_shares_config            => hiera('cinder::backend::netapp::nfs_shares_config', undef),
    netapp_copyoffload_tool_path => hiera('cinder::backend::netapp::netapp_copyoffload_tool_path', undef),
    netapp_controller_ips        => hiera('cinder::backend::netapp::netapp_controller_ips', undef),
    netapp_sa_password           => hiera('cinder::backend::netapp::netapp_sa_password', undef),
    netapp_storage_pools         => hiera('cinder::backend::netapp::netapp_storage_pools', undef),
    netapp_eseries_host_type     => hiera('cinder::backend::netapp::netapp_eseries_host_type', undef),
    netapp_webservice_path       => hiera('cinder::backend::netapp::netapp_webservice_path', undef),
  }
}

if hiera('cinder_enable_nfs_backend', false) {
  $cinder_nfs_backend = 'tripleo_nfs'

  if str2bool($::selinux) {
    selboolean { 'virt_use_nfs':
      value      => on,
      persistent => true,
    } -> Package['nfs-utils']
  }

  package { 'nfs-utils': } ->
  cinder::backend::nfs { $cinder_nfs_backend:
    nfs_servers       => hiera('cinder_nfs_servers'),
    nfs_mount_options => hiera('cinder_nfs_mount_options',''),
    nfs_shares_config => '/etc/cinder/shares-nfs.conf',
  }
}

$cinder_enabled_backends = delete_undef_values([$cinder_iscsi_backend, $cinder_rbd_backend, $cinder_netapp_backend, $cinder_nfs_backend])
class { '::cinder::backends' :
  enabled_backends => $cinder_enabled_backends,
}

# swift proxy
class { '::swift::proxy' :
  manage_service => $non_pcmk_start,
  enabled        => $non_pcmk_start,
}
include ::swift::proxy::proxy_logging
include ::swift::proxy::healthcheck
include ::swift::proxy::cache
include ::swift::proxy::keystone
include ::swift::proxy::authtoken
include ::swift::proxy::staticweb
include ::swift::proxy::ratelimit
include ::swift::proxy::catch_errors
include ::swift::proxy::tempurl
include ::swift::proxy::formpost

# swift storage
if str2bool(hiera('enable_swift_storage', true)) {
  class {'::swift::storage::all':
    mount_check => str2bool(hiera('swift_mount_check')),
  }
  class {'::swift::storage::account':
    manage_service => $non_pcmk_start,
    enabled        => $non_pcmk_start,
  }
  class {'::swift::storage::container':
    manage_service => $non_pcmk_start,
    enabled        => $non_pcmk_start,
  }
  class {'::swift::storage::object':
    manage_service => $non_pcmk_start,
    enabled        => $non_pcmk_start,
  }
  if(!defined(File['/srv/node'])) {
    file { '/srv/node':
      ensure  => directory,
      owner   => 'swift',
      group   => 'swift',
      require => Package['openstack-swift'],
    }
  }
  $swift_components = ['account', 'container', 'object']
  swift::storage::filter::recon { $swift_components : }
  swift::storage::filter::healthcheck { $swift_components : }
}

# Ceilometer
case downcase(hiera('ceilometer_backend')) {
  /mysql/: {
    $ceilometer_database_connection = hiera('ceilometer_mysql_conn_string')
  }
  default: {
    $mongo_node_string = join($mongo_node_ips_with_port, ',')
    $ceilometer_database_connection = "mongodb://${mongo_node_string}/ceilometer?replicaSet=${mongodb_replset}"
  }
}
include ::ceilometer
include ::ceilometer::config
class { '::ceilometer::api' :
  manage_service => false,
  enabled        => false,
}
class { '::ceilometer::agent::notification' :
  manage_service => false,
  enabled        => false,
}
class { '::ceilometer::agent::central' :
  manage_service => false,
  enabled        => false,
}
class { '::ceilometer::collector' :
  manage_service => false,
  enabled        => false,
}
include ::ceilometer::expirer
class { '::ceilometer::db' :
  database_connection => $ceilometer_database_connection,
  sync_db             => $sync_db,
}
include ::ceilometer::agent::auth

Cron <| title == 'ceilometer-expirer' |> { command => "sleep $((\$(od -A n -t d -N 3 /dev/urandom) % 86400)) && ${::ceilometer::params::expirer_command}" }

# Heat
class { '::heat' :
  sync_db => $sync_db,
}
class { '::heat::api' :
  manage_service => false,
  enabled        => false,
}
class { '::heat::api_cfn' :
  manage_service => false,
  enabled        => false,
}
class { '::heat::api_cloudwatch' :
  manage_service => false,
  enabled        => false,
}
class { '::heat::engine' :
  manage_service => false,
  enabled        => false,
}

# httpd/apache and horizon
# NOTE(gfidente): server-status can be consumed by the pacemaker resource agent
class { '::apache' :
  service_enable => false,
  # service_manage => false, # <-- not supported with horizon&apache mod_wsgi?
}
include ::apache::mod::status
if 'cisco_n1kv' in hiera('neutron::plugins::ml2::mechanism_drivers') {
  $_profile_support = 'cisco'
} else {
  $_profile_support = 'None'
}
$neutron_options   = {'profile_support' => $_profile_support }
class { '::horizon':
  cache_server_ip => hiera('memcache_node_ips', '127.0.0.1'),
  neutron_options => $neutron_options,
}

$snmpd_user = hiera('snmpd_readonly_user_name')
snmp::snmpv3_user { $snmpd_user:
  authtype => 'MD5',
  authpass => hiera('snmpd_readonly_user_password'),
}
class { '::snmp':
  agentaddress => ['udp:161','udp6:[::1]:161'],
  snmpd_config => [ join(['rouser ', hiera('snmpd_readonly_user_name')]), 'proc  cron', 'includeAllDisks  10%', 'master agentx', 'trapsink localhost public', 'iquerySecName internalUser', 'rouser internalUser', 'defaultMonitors yes', 'linkUpDownNotifications yes' ],
}

hiera_include('controller_classes')

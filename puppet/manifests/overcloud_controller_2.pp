if count(hiera('ntp::servers')) > 0 {
  include ::ntp
}

# MongoDB
if downcase(hiera('ceilometer_backend')) == 'mongodb' {
  include ::mongodb::globals

  include ::mongodb::server
  $mongo_node_ips_with_port = suffix(hiera('mongo_node_ips'), ':27017')
  $mongo_node_string = join($mongo_node_ips_with_port, ',')

  $mongodb_replset = hiera('mongodb::server::replset')
  $ceilometer_mongodb_conn_string = "mongodb://${mongo_node_string}/ceilometer?replicaSet=${mongodb_replset}"
  if downcase(hiera('bootstrap_nodeid')) == $::hostname {
    mongodb_replset { $mongodb_replset :
      members => $mongo_node_ips_with_port,
    }
  }
}

# Redis
$redis_node_ips = hiera('redis_node_ips')
$redis_master_hostname = downcase(hiera('bootstrap_nodeid'))

if $redis_master_hostname == $::hostname {
  $slaveof = undef
} else {
  $slaveof = "${redis_master_hostname} 6379"
}
class {'::redis' :
  slaveof => $slaveof,
}

if count($redis_node_ips) > 1 {
  Class['::tripleo::redis_notification'] -> Service['redis-sentinel']
  include ::redis::sentinel
  include ::tripleo::redis_notification
}

if str2bool(hiera('enable_galera', true)) {
  $mysql_config_file = '/etc/my.cnf.d/galera.cnf'
} else {
  $mysql_config_file = '/etc/my.cnf.d/server.cnf'
}
# TODO Galara
class { '::mysql::server':
  config_file             => $mysql_config_file,
  override_options        => {
    'mysqld' => {
      'bind-address'     => hiera('mysql_bind_host'),
      'max_connections'  => hiera('mysql_max_connections'),
      'open_files_limit' => '-1',
    },
  },
  remove_default_accounts => true,
}

# FIXME: this should only occur on the bootstrap host (ditto for db syncs)
# Create all the database schemas
include ::keystone::db::mysql
include ::glance::db::mysql
include ::nova::db::mysql
include ::neutron::db::mysql
include ::cinder::db::mysql
include ::heat::db::mysql
if downcase(hiera('ceilometer_backend')) == 'mysql' {
  include ::ceilometer::db::mysql
}

$rabbit_nodes = hiera('rabbit_node_ips')
if count($rabbit_nodes) > 1 {
  class { '::rabbitmq':
    config_cluster          => true,
    cluster_nodes           => $rabbit_nodes,
    tcp_keepalive           => false,
    config_kernel_variables => hiera('rabbitmq_kernel_variables'),
    config_variables        => hiera('rabbitmq_config_variables'),
    environment_variables   => hiera('rabbitmq_environment'),
  }
  rabbitmq_policy { 'ha-all@/':
    pattern    => '^(?!amq\.).*',
    definition => {
      'ha-mode' => 'all',
    },
  }
} else {
  include ::rabbitmq
}

# pre-install swift here so we can build rings
include ::swift

$enable_ceph = hiera('ceph_storage_count', 0) > 0

if $enable_ceph {
  class { '::ceph::profile::params':
    mon_initial_members => downcase(hiera('ceph_mon_initial_members')),
  }
  include ::ceph::profile::mon
}

if str2bool(hiera('enable_ceph_storage', false)) {
  if str2bool(hiera('ceph_osd_selinux_permissive', true)) {
    exec { 'set selinux to permissive on boot':
      command => "sed -ie 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config",
      onlyif  => "test -f /etc/selinux/config && ! grep '^SELINUX=permissive' /etc/selinux/config",
      path    => ['/usr/bin', '/usr/sbin'],
    }

    exec { 'set selinux to permissive':
      command => 'setenforce 0',
      onlyif  => "which setenforce && getenforce | grep -i 'enforcing'",
      path    => ['/usr/bin', '/usr/sbin'],
    } -> Class['ceph::profile::osd']
  }

  include ::ceph::profile::osd
}

if str2bool(hiera('enable_external_ceph', false)) {
  include ::ceph::profile::client
}

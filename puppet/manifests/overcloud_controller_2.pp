

if count(hiera('ntp::servers')) > 0 {
  include ::ntp
}

include ::timezone

# MongoDB
if downcase(hiera('ceilometer_backend')) == 'mongodb' {
  include ::mongodb::globals
  include ::mongodb::client
  include ::mongodb::server
  # NOTE(gfidente): We need to pass the list of IPv6 addresses *with* port and
  # without the brackets as 'members' argument for the 'mongodb_replset'
  # resource.
  if str2bool(hiera('mongodb::server::ipv6', false)) {
    $mongo_node_ips_with_port_prefixed = prefix(hiera('mongo_node_ips'), '[')
    $mongo_node_ips_with_port = suffix($mongo_node_ips_with_port_prefixed, ']:27017')
    $mongo_node_ips_with_port_nobr = suffix(hiera('mongo_node_ips'), ':27017')
  } else {
    $mongo_node_ips_with_port = suffix(hiera('mongo_node_ips'), ':27017')
    $mongo_node_ips_with_port_nobr = suffix(hiera('mongo_node_ips'), ':27017')
  }
  $mongo_node_string = join($mongo_node_ips_with_port, ',')

  $mongodb_replset = hiera('mongodb::server::replset')
  $ceilometer_mongodb_conn_string = "mongodb://${mongo_node_string}/ceilometer?replicaSet=${mongodb_replset}"
  if downcase(hiera('bootstrap_nodeid')) == $::hostname {
    mongodb_replset { $mongodb_replset :
      members => $mongo_node_ips_with_port_nobr,
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
# FIXME: due to https://bugzilla.redhat.com/show_bug.cgi?id=1298671 we
# set bind-address to a hostname instead of an ip address; to move Mysql
# from internal_api on another network we'll have to customize both
# MysqlNetwork and ControllerHostnameResolveNetwork in ServiceNetMap
class { '::mysql::server':
  config_file             => $mysql_config_file,
  override_options        => {
    'mysqld' => {
      'bind-address'     => $::hostname,
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
include ::nova::db::mysql_api
include ::neutron::db::mysql
include ::cinder::db::mysql
include ::heat::db::mysql
include ::sahara::db::mysql
if downcase(hiera('ceilometer_backend')) == 'mysql' {
  include ::ceilometer::db::mysql
}

$rabbit_nodes = hiera('rabbit_node_ips')
if count($rabbit_nodes) > 1 {

  $rabbit_ipv6 = str2bool(hiera('rabbit_ipv6', false))
  if $rabbit_ipv6 {
    $rabbit_env = merge(hiera('rabbitmq_environment'), {
      'RABBITMQ_SERVER_START_ARGS' => '"-proto_dist inet6_tcp"'
    })
  } else {
    $rabbit_env = hiera('rabbitmq_environment')
  }

  class { '::rabbitmq':
    config_cluster          => true,
    cluster_nodes           => $rabbit_nodes,
    tcp_keepalive           => false,
    config_kernel_variables => hiera('rabbitmq_kernel_variables'),
    config_variables        => hiera('rabbitmq_config_variables'),
    environment_variables   => $rabbit_env,
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

$enable_ceph = hiera('ceph_storage_count', 0) > 0 or hiera('enable_ceph_storage', false)

if $enable_ceph {
  $mon_initial_members = downcase(hiera('ceph_mon_initial_members'))
  if str2bool(hiera('ceph_ipv6', false)) {
    $mon_host = hiera('ceph_mon_host_v6')
  } else {
    $mon_host = hiera('ceph_mon_host')
  }
  class { '::ceph::profile::params':
    mon_initial_members => $mon_initial_members,
    mon_host            => $mon_host,
  }
  include ::ceph::conf
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

  include ::ceph::conf
  include ::ceph::profile::osd
}

if str2bool(hiera('enable_external_ceph', false)) {
  if str2bool(hiera('ceph_ipv6', false)) {
    $mon_host = hiera('ceph_mon_host_v6')
  } else {
    $mon_host = hiera('ceph_mon_host')
  }
  class { '::ceph::profile::params':
    mon_host            => $mon_host,
  }
  include ::ceph::conf
  include ::ceph::profile::client
}




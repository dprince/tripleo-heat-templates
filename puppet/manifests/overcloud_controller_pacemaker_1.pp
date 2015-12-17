# Step 1
create_resources(sysctl::value, hiera('sysctl_settings'), {})

if count(hiera('ntp::servers')) > 0 {
  include ::ntp
}

$controller_node_ips = split(hiera('controller_node_ips'), ',')
$controller_node_names = split(downcase(hiera('controller_node_names')), ',')
if $enable_load_balancer {
  class { '::tripleo::loadbalancer' :
    controller_hosts       => $controller_node_ips,
    controller_hosts_names => $controller_node_names,
    manage_vip             => false,
    mysql_clustercheck     => true,
    haproxy_service_manage => false,
  }
}

$pacemaker_cluster_members = downcase(regsubst(hiera('controller_node_names'), ',', ' ', 'G'))
user { 'hacluster':
  ensure => present,
} ->
class { '::pacemaker':
  hacluster_pwd => hiera('hacluster_pwd'),
} ->
class { '::pacemaker::corosync':
  cluster_members => $pacemaker_cluster_members,
  setup_cluster   => $pacemaker_master,
}
class { '::pacemaker::stonith':
  disable => !$enable_fencing,
}
if $enable_fencing {
  include ::tripleo::fencing

  # enable stonith after all fencing devices have been created
  Class['tripleo::fencing'] -> Class['pacemaker::stonith']
}

# FIXME(gfidente): sets 100secs as default start timeout op
# param; until we can use pcmk global defaults we'll still
# need to add it to every resource which redefines op params
Pacemaker::Resource::Service {
  op_params => 'start timeout=100s stop timeout=100s',
}

# Only configure RabbitMQ in this step, don't start it yet to
# avoid races where non-master nodes attempt to start without
# config (eg. binding on 0.0.0.0)
# The module ignores erlang_cookie if cluster_config is false
class { '::rabbitmq':
  service_manage          => false,
  tcp_keepalive           => false,
  config_kernel_variables => hiera('rabbitmq_kernel_variables'),
  config_variables        => hiera('rabbitmq_config_variables'),
  environment_variables   => hiera('rabbitmq_environment'),
} ->
file { '/var/lib/rabbitmq/.erlang.cookie':
  ensure  => file,
  owner   => 'rabbitmq',
  group   => 'rabbitmq',
  mode    => '0400',
  content => hiera('rabbitmq::erlang_cookie'),
  replace => true,
}

if downcase(hiera('ceilometer_backend')) == 'mongodb' {
  include ::mongodb::globals
  class { '::mongodb::server' :
    service_manage => false,
  }
}

# Memcached
class {'::memcached' :
  service_manage => false,
}

# Redis
class { '::redis' :
  service_manage => false,
  notify_service => false,
}

# Galera
if str2bool(hiera('enable_galera', true)) {
  $mysql_config_file = '/etc/my.cnf.d/galera.cnf'
} else {
  $mysql_config_file = '/etc/my.cnf.d/server.cnf'
}
$galera_nodes = downcase(hiera('galera_node_names', $::hostname))
$galera_nodes_count = count(split($galera_nodes, ','))

$mysqld_options = {
  'mysqld' => {
    'skip-name-resolve'             => '1',
    'binlog_format'                 => 'ROW',
    'default-storage-engine'        => 'innodb',
    'innodb_autoinc_lock_mode'      => '2',
    'innodb_locks_unsafe_for_binlog'=> '1',
    'query_cache_size'              => '0',
    'query_cache_type'              => '0',
    'bind-address'                  => hiera('mysql_bind_host'),
    'max_connections'               => hiera('mysql_max_connections'),
    'open_files_limit'              => '-1',
    'wsrep_provider'                => '/usr/lib64/galera/libgalera_smm.so',
    'wsrep_cluster_name'            => 'galera_cluster',
    'wsrep_slave_threads'           => '1',
    'wsrep_certify_nonPK'           => '1',
    'wsrep_max_ws_rows'             => '131072',
    'wsrep_max_ws_size'             => '1073741824',
    'wsrep_debug'                   => '0',
    'wsrep_convert_LOCK_to_trx'     => '0',
    'wsrep_retry_autocommit'        => '1',
    'wsrep_auto_increment_control'  => '1',
    'wsrep_drupal_282555_workaround'=> '0',
    'wsrep_causal_reads'            => '0',
    'wsrep_notify_cmd'              => '',
    'wsrep_sst_method'              => 'rsync',
  },
}

class { '::mysql::server':
  create_root_user        => false,
  create_root_my_cnf      => false,
  config_file             => $mysql_config_file,
  override_options        => $mysqld_options,
  remove_default_accounts => $pacemaker_master,
  service_manage          => false,
  service_enabled         => false,
}

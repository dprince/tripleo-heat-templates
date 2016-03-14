

# NOTE(gfidente): the following vars are needed on all nodes so they
# need to stay out of pacemaker_master conditional.
# The addresses mangling will hopefully go away when we'll be able to
# configure the connection string via hostnames, until then, we need to pass
# the list of IPv6 addresses *with* port and without the brackets as 'members'
# argument for the 'mongodb_replset' resource.
if str2bool(hiera('mongodb::server::ipv6', false)) {
  $mongo_node_ips_with_port_prefixed = prefix(hiera('mongo_node_ips'), '[')
  $mongo_node_ips_with_port = suffix($mongo_node_ips_with_port_prefixed, ']:27017')
  $mongo_node_ips_with_port_nobr = suffix(hiera('mongo_node_ips'), ':27017')
} else {
  $mongo_node_ips_with_port = suffix(hiera('mongo_node_ips'), ':27017')
  $mongo_node_ips_with_port_nobr = suffix(hiera('mongo_node_ips'), ':27017')
}
$mongodb_replset = hiera('mongodb::server::replset')

if $pacemaker_master {

  if $enable_load_balancer {

    include ::pacemaker::resource_defaults

    # Create an openstack-core dummy resource. See RHBZ 1290121
    pacemaker::resource::ocf { 'openstack-core':
      ocf_agent_name => 'heartbeat:Dummy',
      clone_params   => true,
    }
    # FIXME: we should not have to access tripleo::loadbalancer class
    # parameters here to configure pacemaker VIPs. The configuration
    # of pacemaker VIPs could move into puppet-tripleo or we should
    # make use of less specific hiera parameters here for the settings.
    pacemaker::resource::service { 'haproxy':
      clone_params => true,
    }

    $control_vip = hiera('tripleo::loadbalancer::controller_virtual_ip')
    if is_ipv6_address($control_vip) {
      $control_vip_netmask = '64'
    } else {
      $control_vip_netmask = '32'
    }
    pacemaker::resource::ip { 'control_vip':
      ip_address   => $control_vip,
      cidr_netmask => $control_vip_netmask,
    }
    pacemaker::constraint::base { 'control_vip-then-haproxy':
      constraint_type   => 'order',
      first_resource    => "ip-${control_vip}",
      second_resource   => 'haproxy-clone',
      first_action      => 'start',
      second_action     => 'start',
      constraint_params => 'kind=Optional',
      require           => [Pacemaker::Resource::Service['haproxy'],
                            Pacemaker::Resource::Ip['control_vip']],
    }
    pacemaker::constraint::colocation { 'control_vip-with-haproxy':
      source  => "ip-${control_vip}",
      target  => 'haproxy-clone',
      score   => 'INFINITY',
      require => [Pacemaker::Resource::Service['haproxy'],
                  Pacemaker::Resource::Ip['control_vip']],
    }

    $public_vip = hiera('tripleo::loadbalancer::public_virtual_ip')
    if is_ipv6_address($public_vip) {
      $public_vip_netmask = '64'
    } else {
      $public_vip_netmask = '32'
    }
    if $public_vip and $public_vip != $control_vip {
      pacemaker::resource::ip { 'public_vip':
        ip_address   => $public_vip,
        cidr_netmask => $public_vip_netmask,
      }
      pacemaker::constraint::base { 'public_vip-then-haproxy':
        constraint_type   => 'order',
        first_resource    => "ip-${public_vip}",
        second_resource   => 'haproxy-clone',
        first_action      => 'start',
        second_action     => 'start',
        constraint_params => 'kind=Optional',
        require           => [Pacemaker::Resource::Service['haproxy'],
                              Pacemaker::Resource::Ip['public_vip']],
      }
      pacemaker::constraint::colocation { 'public_vip-with-haproxy':
        source  => "ip-${public_vip}",
        target  => 'haproxy-clone',
        score   => 'INFINITY',
        require => [Pacemaker::Resource::Service['haproxy'],
                    Pacemaker::Resource::Ip['public_vip']],
      }
    }

    $redis_vip = hiera('redis_vip')
    if is_ipv6_address($redis_vip) {
      $redis_vip_netmask = '64'
    } else {
      $redis_vip_netmask = '32'
    }
    if $redis_vip and $redis_vip != $control_vip {
      pacemaker::resource::ip { 'redis_vip':
        ip_address   => $redis_vip,
        cidr_netmask => $redis_vip_netmask,
      }
      pacemaker::constraint::base { 'redis_vip-then-haproxy':
        constraint_type   => 'order',
        first_resource    => "ip-${redis_vip}",
        second_resource   => 'haproxy-clone',
        first_action      => 'start',
        second_action     => 'start',
        constraint_params => 'kind=Optional',
        require           => [Pacemaker::Resource::Service['haproxy'],
                              Pacemaker::Resource::Ip['redis_vip']],
      }
      pacemaker::constraint::colocation { 'redis_vip-with-haproxy':
        source  => "ip-${redis_vip}",
        target  => 'haproxy-clone',
        score   => 'INFINITY',
        require => [Pacemaker::Resource::Service['haproxy'],
                    Pacemaker::Resource::Ip['redis_vip']],
      }
    }

    $internal_api_vip = hiera('tripleo::loadbalancer::internal_api_virtual_ip')
    if is_ipv6_address($internal_api_vip) {
      $internal_api_vip_netmask = '64'
    } else {
      $internal_api_vip_netmask = '32'
    }
    if $internal_api_vip and $internal_api_vip != $control_vip {
      pacemaker::resource::ip { 'internal_api_vip':
        ip_address   => $internal_api_vip,
        cidr_netmask => $internal_api_vip_netmask,
      }
      pacemaker::constraint::base { 'internal_api_vip-then-haproxy':
        constraint_type   => 'order',
        first_resource    => "ip-${internal_api_vip}",
        second_resource   => 'haproxy-clone',
        first_action      => 'start',
        second_action     => 'start',
        constraint_params => 'kind=Optional',
        require           => [Pacemaker::Resource::Service['haproxy'],
                              Pacemaker::Resource::Ip['internal_api_vip']],
      }
      pacemaker::constraint::colocation { 'internal_api_vip-with-haproxy':
        source  => "ip-${internal_api_vip}",
        target  => 'haproxy-clone',
        score   => 'INFINITY',
        require => [Pacemaker::Resource::Service['haproxy'],
                    Pacemaker::Resource::Ip['internal_api_vip']],
      }
    }

    $storage_vip = hiera('tripleo::loadbalancer::storage_virtual_ip')
    if is_ipv6_address($storage_vip) {
      $storage_vip_netmask = '64'
    } else {
      $storage_vip_netmask = '32'
    }
    if $storage_vip and $storage_vip != $control_vip {
      pacemaker::resource::ip { 'storage_vip':
        ip_address   => $storage_vip,
        cidr_netmask => $storage_vip_netmask,
      }
      pacemaker::constraint::base { 'storage_vip-then-haproxy':
        constraint_type   => 'order',
        first_resource    => "ip-${storage_vip}",
        second_resource   => 'haproxy-clone',
        first_action      => 'start',
        second_action     => 'start',
        constraint_params => 'kind=Optional',
        require           => [Pacemaker::Resource::Service['haproxy'],
                              Pacemaker::Resource::Ip['storage_vip']],
      }
      pacemaker::constraint::colocation { 'storage_vip-with-haproxy':
        source  => "ip-${storage_vip}",
        target  => 'haproxy-clone',
        score   => 'INFINITY',
        require => [Pacemaker::Resource::Service['haproxy'],
                    Pacemaker::Resource::Ip['storage_vip']],
      }
    }

    $storage_mgmt_vip = hiera('tripleo::loadbalancer::storage_mgmt_virtual_ip')
    if is_ipv6_address($storage_mgmt_vip) {
      $storage_mgmt_vip_netmask = '64'
    } else {
      $storage_mgmt_vip_netmask = '32'
    }
    if $storage_mgmt_vip and $storage_mgmt_vip != $control_vip {
      pacemaker::resource::ip { 'storage_mgmt_vip':
        ip_address   => $storage_mgmt_vip,
        cidr_netmask => $storage_mgmt_vip_netmask,
      }
      pacemaker::constraint::base { 'storage_mgmt_vip-then-haproxy':
        constraint_type   => 'order',
        first_resource    => "ip-${storage_mgmt_vip}",
        second_resource   => 'haproxy-clone',
        first_action      => 'start',
        second_action     => 'start',
        constraint_params => 'kind=Optional',
        require           => [Pacemaker::Resource::Service['haproxy'],
                              Pacemaker::Resource::Ip['storage_mgmt_vip']],
      }
      pacemaker::constraint::colocation { 'storage_mgmt_vip-with-haproxy':
        source  => "ip-${storage_mgmt_vip}",
        target  => 'haproxy-clone',
        score   => 'INFINITY',
        require => [Pacemaker::Resource::Service['haproxy'],
                    Pacemaker::Resource::Ip['storage_mgmt_vip']],
      }
    }

  }

  pacemaker::resource::service { $::memcached::params::service_name :
    clone_params => 'interleave=true',
    require      => Class['::memcached'],
  }

  pacemaker::resource::ocf { 'rabbitmq':
    ocf_agent_name  => 'heartbeat:rabbitmq-cluster',
    resource_params => 'set_policy=\'ha-all ^(?!amq\.).* {"ha-mode":"all"}\'',
    clone_params    => 'ordered=true interleave=true',
    meta_params     => 'notify=true',
    require         => Class['::rabbitmq'],
  }

  if downcase(hiera('ceilometer_backend')) == 'mongodb' {
    pacemaker::resource::service { $::mongodb::params::service_name :
      op_params    => 'start timeout=370s stop timeout=200s',
      clone_params => true,
      require      => Class['::mongodb::server'],
    }
    # NOTE (spredzy) : The replset can only be run
    # once all the nodes have joined the cluster.
    mongodb_conn_validator { $mongo_node_ips_with_port :
      timeout => '600',
      require => Pacemaker::Resource::Service[$::mongodb::params::service_name],
      before  => Mongodb_replset[$mongodb_replset],
    }
    mongodb_replset { $mongodb_replset :
      members => $mongo_node_ips_with_port_nobr,
    }
  }

  pacemaker::resource::ocf { 'galera' :
    ocf_agent_name  => 'heartbeat:galera',
    op_params       => 'promote timeout=300s on-fail=block',
    master_params   => '',
    meta_params     => "master-max=${galera_nodes_count} ordered=true",
    resource_params => "additional_parameters='--open-files-limit=16384' enable_creation=true wsrep_cluster_address='gcomm://${galera_nodes}'",
    require         => Class['::mysql::server'],
    before          => Exec['galera-ready'],
  }

  pacemaker::resource::ocf { 'redis':
    ocf_agent_name  => 'heartbeat:redis',
    master_params   => '',
    meta_params     => 'notify=true ordered=true interleave=true',
    resource_params => 'wait_last_known_master=true',
    require         => Class['::redis'],
  }

}

exec { 'galera-ready' :
  command     => '/usr/bin/clustercheck >/dev/null',
  timeout     => 30,
  tries       => 180,
  try_sleep   => 10,
  environment => ['AVAILABLE_WHEN_READONLY=0'],
  require     => File['/etc/sysconfig/clustercheck'],
}

file { '/etc/sysconfig/clustercheck' :
  ensure  => file,
  content => "MYSQL_USERNAME=root\n
MYSQL_PASSWORD=''\n
MYSQL_HOST=localhost\n",
}

xinetd::service { 'galera-monitor' :
  port           => '9200',
  server         => '/usr/bin/clustercheck',
  per_source     => 'UNLIMITED',
  log_on_success => '',
  log_on_failure => 'HOST',
  flags          => 'REUSE',
  service_type   => 'UNLISTED',
  user           => 'root',
  group          => 'root',
  require        => File['/etc/sysconfig/clustercheck'],
}

# Create all the database schemas
if $sync_db {
  class { '::keystone::db::mysql':
    require => Exec['galera-ready'],
  }
  class { '::glance::db::mysql':
    require => Exec['galera-ready'],
  }
  class { '::nova::db::mysql':
    require => Exec['galera-ready'],
  }
  class { '::nova::db::mysql_api':
    require => Exec['galera-ready'],
  }
  class { '::neutron::db::mysql':
    require => Exec['galera-ready'],
  }
  class { '::cinder::db::mysql':
    require => Exec['galera-ready'],
  }
  class { '::heat::db::mysql':
    require => Exec['galera-ready'],
  }

  if downcase(hiera('ceilometer_backend')) == 'mysql' {
    class { '::ceilometer::db::mysql':
      require => Exec['galera-ready'],
    }
  }

  class { '::sahara::db::mysql':
    require       => Exec['galera-ready'],
  }
}

# pre-install swift here so we can build rings
include ::swift

# Ceph
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





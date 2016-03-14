
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

if $pacemaker_master {

  if $enable_load_balancer {
    pacemaker::constraint::base { 'haproxy-then-keystone-constraint':
      constraint_type => 'order',
      first_resource  => 'haproxy-clone',
      second_resource => 'openstack-core-clone',
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Service['haproxy'],
                          Pacemaker::Resource::Ocf['openstack-core']],
    }
  }

  pacemaker::constraint::base { 'openstack-core-then-httpd-constraint':
    constraint_type => 'order',
    first_resource  => 'openstack-core-clone',
    second_resource => "${::apache::params::service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::apache::params::service_name],
                        Pacemaker::Resource::Ocf['openstack-core']],
  }
  pacemaker::constraint::base { 'rabbitmq-then-keystone-constraint':
    constraint_type => 'order',
    first_resource  => 'rabbitmq-clone',
    second_resource => 'openstack-core-clone',
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Ocf['rabbitmq'],
                        Pacemaker::Resource::Ocf['openstack-core']],
  }
  pacemaker::constraint::base { 'memcached-then-openstack-core-constraint':
    constraint_type => 'order',
    first_resource  => 'memcached-clone',
    second_resource => 'openstack-core-clone',
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service['memcached'],
                        Pacemaker::Resource::Ocf['openstack-core']],
  }
  pacemaker::constraint::base { 'galera-then-openstack-core-constraint':
    constraint_type => 'order',
    first_resource  => 'galera-master',
    second_resource => 'openstack-core-clone',
    first_action    => 'promote',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Ocf['galera'],
                        Pacemaker::Resource::Ocf['openstack-core']],
  }

  # Cinder
  pacemaker::resource::service { $::cinder::params::api_service :
    clone_params => 'interleave=true',
    require      => Pacemaker::Resource::Ocf['openstack-core'],
  }
  pacemaker::resource::service { $::cinder::params::scheduler_service :
    clone_params => 'interleave=true',
  }
  pacemaker::resource::service { $::cinder::params::volume_service : }

  pacemaker::constraint::base { 'keystone-then-cinder-api-constraint':
    constraint_type => 'order',
    first_resource  => 'openstack-core-clone',
    second_resource => "${::cinder::params::api_service}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Ocf['openstack-core'],
                        Pacemaker::Resource::Service[$::cinder::params::api_service]],
  }
  pacemaker::constraint::base { 'cinder-api-then-cinder-scheduler-constraint':
    constraint_type => 'order',
    first_resource  => "${::cinder::params::api_service}-clone",
    second_resource => "${::cinder::params::scheduler_service}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::cinder::params::api_service],
                        Pacemaker::Resource::Service[$::cinder::params::scheduler_service]],
  }
  pacemaker::constraint::colocation { 'cinder-scheduler-with-cinder-api-colocation':
    source  => "${::cinder::params::scheduler_service}-clone",
    target  => "${::cinder::params::api_service}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::cinder::params::api_service],
                Pacemaker::Resource::Service[$::cinder::params::scheduler_service]],
  }
  pacemaker::constraint::base { 'cinder-scheduler-then-cinder-volume-constraint':
    constraint_type => 'order',
    first_resource  => "${::cinder::params::scheduler_service}-clone",
    second_resource => $::cinder::params::volume_service,
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::cinder::params::scheduler_service],
                        Pacemaker::Resource::Service[$::cinder::params::volume_service]],
  }
  pacemaker::constraint::colocation { 'cinder-volume-with-cinder-scheduler-colocation':
    source  => $::cinder::params::volume_service,
    target  => "${::cinder::params::scheduler_service}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::cinder::params::scheduler_service],
                Pacemaker::Resource::Service[$::cinder::params::volume_service]],
  }

  # Sahara
  pacemaker::resource::service { $::sahara::params::api_service_name :
    clone_params => 'interleave=true',
    require      => Pacemaker::Resource::Ocf['openstack-core'],
  }
  pacemaker::resource::service { $::sahara::params::engine_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::constraint::base { 'keystone-then-sahara-api-constraint':
    constraint_type => 'order',
    first_resource  => 'openstack-core-clone',
    second_resource => "${::sahara::params::api_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::sahara::params::api_service_name],
                        Pacemaker::Resource::Ocf['openstack-core']],
  }

  # Glance
  pacemaker::resource::service { $::glance::params::registry_service_name :
    clone_params => 'interleave=true',
    require      => Pacemaker::Resource::Ocf['openstack-core'],
  }
  pacemaker::resource::service { $::glance::params::api_service_name :
    clone_params => 'interleave=true',
  }

  pacemaker::constraint::base { 'keystone-then-glance-registry-constraint':
    constraint_type => 'order',
    first_resource  => 'openstack-core-clone',
    second_resource => "${::glance::params::registry_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::glance::params::registry_service_name],
                        Pacemaker::Resource::Ocf['openstack-core']],
  }
  pacemaker::constraint::base { 'glance-registry-then-glance-api-constraint':
    constraint_type => 'order',
    first_resource  => "${::glance::params::registry_service_name}-clone",
    second_resource => "${::glance::params::api_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::glance::params::registry_service_name],
                        Pacemaker::Resource::Service[$::glance::params::api_service_name]],
  }
  pacemaker::constraint::colocation { 'glance-api-with-glance-registry-colocation':
    source  => "${::glance::params::api_service_name}-clone",
    target  => "${::glance::params::registry_service_name}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::glance::params::registry_service_name],
                Pacemaker::Resource::Service[$::glance::params::api_service_name]],
  }

  if hiera('step') == 5 {
    # Neutron
    # NOTE(gfidente): Neutron will try to populate the database with some data
    # as soon as neutron-server is started; to avoid races we want to make this
    # happen only on one node, before normal Pacemaker initialization
    # https://bugzilla.redhat.com/show_bug.cgi?id=1233061
    # NOTE(emilien): we need to run this Exec only at Step 4 otherwise this exec
    # will try to start the service while it's already started by Pacemaker
    # It would result to a deployment failure since systemd would return 1 to Puppet
    # and the overcloud would fail to deploy (6 would be returned).
    # This conditional prevents from a race condition during the deployment.
    # https://bugzilla.redhat.com/show_bug.cgi?id=1290582
    exec { 'neutron-server-systemd-start-sleep' :
      command => 'systemctl start neutron-server && /usr/bin/sleep 5',
      path    => '/usr/bin',
      unless  => '/sbin/pcs resource show neutron-server',
    } ->
    pacemaker::resource::service { $::neutron::params::server_service:
      clone_params => 'interleave=true',
      require      => Pacemaker::Resource::Ocf['openstack-core']
    }
  } else {
    pacemaker::resource::service { $::neutron::params::server_service:
      clone_params => 'interleave=true',
      require      => Pacemaker::Resource::Ocf['openstack-core']
    }
  }
  if hiera('neutron::enable_l3_agent', true) {
    pacemaker::resource::service { $::neutron::params::l3_agent_service:
      clone_params => 'interleave=true',
    }
  }
  if hiera('neutron::enable_dhcp_agent', true) {
    pacemaker::resource::service { $::neutron::params::dhcp_agent_service:
      clone_params => 'interleave=true',
    }
  }
  if hiera('neutron::enable_ovs_agent', true) {
    pacemaker::resource::service { $::neutron::params::ovs_agent_service:
      clone_params => 'interleave=true',
    }
  }
  if hiera('neutron::core_plugin') == 'midonet.neutron.plugin_v1.MidonetPluginV2' {
    pacemaker::resource::service {'tomcat':
      clone_params => 'interleave=true',
    }
  }
  if hiera('neutron::enable_metadata_agent', true) {
    pacemaker::resource::service { $::neutron::params::metadata_agent_service:
      clone_params => 'interleave=true',
    }
  }
  if hiera('neutron::enable_ovs_agent', true) {
    pacemaker::resource::ocf { $::neutron::params::ovs_cleanup_service:
      ocf_agent_name => 'neutron:OVSCleanup',
      clone_params   => 'interleave=true',
    }
    pacemaker::resource::ocf { 'neutron-netns-cleanup':
      ocf_agent_name => 'neutron:NetnsCleanup',
      clone_params   => 'interleave=true',
    }

    # neutron - one chain ovs-cleanup-->netns-cleanup-->ovs-agent
    pacemaker::constraint::base { 'neutron-ovs-cleanup-to-netns-cleanup-constraint':
      constraint_type => 'order',
      first_resource  => "${::neutron::params::ovs_cleanup_service}-clone",
      second_resource => 'neutron-netns-cleanup-clone',
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Ocf[$::neutron::params::ovs_cleanup_service],
                          Pacemaker::Resource::Ocf['neutron-netns-cleanup']],
    }
    pacemaker::constraint::colocation { 'neutron-ovs-cleanup-to-netns-cleanup-colocation':
      source  => 'neutron-netns-cleanup-clone',
      target  => "${::neutron::params::ovs_cleanup_service}-clone",
      score   => 'INFINITY',
      require => [Pacemaker::Resource::Ocf[$::neutron::params::ovs_cleanup_service],
                  Pacemaker::Resource::Ocf['neutron-netns-cleanup']],
    }
    pacemaker::constraint::base { 'neutron-netns-cleanup-to-openvswitch-agent-constraint':
      constraint_type => 'order',
      first_resource  => 'neutron-netns-cleanup-clone',
      second_resource => "${::neutron::params::ovs_agent_service}-clone",
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Ocf['neutron-netns-cleanup'],
                          Pacemaker::Resource::Service[$::neutron::params::ovs_agent_service]],
    }
    pacemaker::constraint::colocation { 'neutron-netns-cleanup-to-openvswitch-agent-colocation':
      source  => "${::neutron::params::ovs_agent_service}-clone",
      target  => 'neutron-netns-cleanup-clone',
      score   => 'INFINITY',
      require => [Pacemaker::Resource::Ocf['neutron-netns-cleanup'],
                  Pacemaker::Resource::Service[$::neutron::params::ovs_agent_service]],
    }
  }
  pacemaker::constraint::base { 'keystone-to-neutron-server-constraint':
    constraint_type => 'order',
    first_resource  => 'openstack-core-clone',
    second_resource => "${::neutron::params::server_service}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Ocf['openstack-core'],
                        Pacemaker::Resource::Service[$::neutron::params::server_service]],
  }
  if hiera('neutron::enable_ovs_agent',true) {
    pacemaker::constraint::base { 'neutron-openvswitch-agent-to-dhcp-agent-constraint':
      constraint_type => 'order',
      first_resource  => "${::neutron::params::ovs_agent_service}-clone",
      second_resource => "${::neutron::params::dhcp_agent_service}-clone",
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Service[$::neutron::params::ovs_agent_service],
                          Pacemaker::Resource::Service[$::neutron::params::dhcp_agent_service]],
    }
  }
  if hiera('neutron::enable_dhcp_agent',true) and hiera('neutron::enable_ovs_agent',true) {
    pacemaker::constraint::base { 'neutron-server-to-openvswitch-agent-constraint':
      constraint_type => 'order',
      first_resource  => "${::neutron::params::server_service}-clone",
      second_resource => "${::neutron::params::ovs_agent_service}-clone",
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Service[$::neutron::params::server_service],
                          Pacemaker::Resource::Service[$::neutron::params::ovs_agent_service]],
  }

    pacemaker::constraint::colocation { 'neutron-openvswitch-agent-to-dhcp-agent-colocation':
      source  => "${::neutron::params::dhcp_agent_service}-clone",
      target  => "${::neutron::params::ovs_agent_service}-clone",
      score   => 'INFINITY',
      require => [Pacemaker::Resource::Service[$::neutron::params::ovs_agent_service],
                  Pacemaker::Resource::Service[$::neutron::params::dhcp_agent_service]],
    }
  }
  if hiera('neutron::enable_dhcp_agent',true) and hiera('l3_agent_service',true) {
    pacemaker::constraint::base { 'neutron-dhcp-agent-to-l3-agent-constraint':
      constraint_type => 'order',
      first_resource  => "${::neutron::params::dhcp_agent_service}-clone",
      second_resource => "${::neutron::params::l3_agent_service}-clone",
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Service[$::neutron::params::dhcp_agent_service],
                          Pacemaker::Resource::Service[$::neutron::params::l3_agent_service]]
    }
    pacemaker::constraint::colocation { 'neutron-dhcp-agent-to-l3-agent-colocation':
      source  => "${::neutron::params::l3_agent_service}-clone",
      target  => "${::neutron::params::dhcp_agent_service}-clone",
      score   => 'INFINITY',
      require => [Pacemaker::Resource::Service[$::neutron::params::dhcp_agent_service],
                  Pacemaker::Resource::Service[$::neutron::params::l3_agent_service]]
    }
  }
  if hiera('neutron::enable_l3_agent',true) and hiera('neutron::enable_metadata_agent',true) {
    pacemaker::constraint::base { 'neutron-l3-agent-to-metadata-agent-constraint':
      constraint_type => 'order',
      first_resource  => "${::neutron::params::l3_agent_service}-clone",
      second_resource => "${::neutron::params::metadata_agent_service}-clone",
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Service[$::neutron::params::l3_agent_service],
                          Pacemaker::Resource::Service[$::neutron::params::metadata_agent_service]]
    }
    pacemaker::constraint::colocation { 'neutron-l3-agent-to-metadata-agent-colocation':
      source  => "${::neutron::params::metadata_agent_service}-clone",
      target  => "${::neutron::params::l3_agent_service}-clone",
      score   => 'INFINITY',
      require => [Pacemaker::Resource::Service[$::neutron::params::l3_agent_service],
                  Pacemaker::Resource::Service[$::neutron::params::metadata_agent_service]]
    }
  }
  if hiera('neutron::core_plugin') == 'midonet.neutron.plugin_v1.MidonetPluginV2' {
    #midonet-chain chain keystone-->neutron-server-->dhcp-->metadata->tomcat
    pacemaker::constraint::base { 'neutron-server-to-dhcp-agent-constraint':
      constraint_type => 'order',
      first_resource  => "${::neutron::params::server_service}-clone",
      second_resource => "${::neutron::params::dhcp_agent_service}-clone",
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Service[$::neutron::params::server_service],
                          Pacemaker::Resource::Service[$::neutron::params::dhcp_agent_service]],
    }
    pacemaker::constraint::base { 'neutron-dhcp-agent-to-metadata-agent-constraint':
      constraint_type => 'order',
      first_resource  => "${::neutron::params::dhcp_agent_service}-clone",
      second_resource => "${::neutron::params::metadata_agent_service}-clone",
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Service[$::neutron::params::dhcp_agent_service],
                          Pacemaker::Resource::Service[$::neutron::params::metadata_agent_service]],
    }
    pacemaker::constraint::base { 'neutron-metadata-agent-to-tomcat-constraint':
      constraint_type => 'order',
      first_resource  => "${::neutron::params::metadata_agent_service}-clone",
      second_resource => 'tomcat-clone',
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Service[$::neutron::params::metadata_agent_service],
                          Pacemaker::Resource::Service['tomcat']],
    }
    pacemaker::constraint::colocation { 'neutron-dhcp-agent-to-metadata-agent-colocation':
      source  => "${::neutron::params::metadata_agent_service}-clone",
      target  => "${::neutron::params::dhcp_agent_service}-clone",
      score   => 'INFINITY',
      require => [Pacemaker::Resource::Service[$::neutron::params::dhcp_agent_service],
                  Pacemaker::Resource::Service[$::neutron::params::metadata_agent_service]],
    }
  }

  # Nova
  pacemaker::resource::service { $::nova::params::api_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::resource::service { $::nova::params::conductor_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::resource::service { $::nova::params::consoleauth_service_name :
    clone_params => 'interleave=true',
    require      => Pacemaker::Resource::Ocf['openstack-core'],
  }
  pacemaker::resource::service { $::nova::params::vncproxy_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::resource::service { $::nova::params::scheduler_service_name :
    clone_params => 'interleave=true',
  }

  pacemaker::constraint::base { 'keystone-then-nova-consoleauth-constraint':
    constraint_type => 'order',
    first_resource  => 'openstack-core-clone',
    second_resource => "${::nova::params::consoleauth_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::nova::params::consoleauth_service_name],
                        Pacemaker::Resource::Ocf['openstack-core']],
  }
  pacemaker::constraint::base { 'nova-consoleauth-then-nova-vncproxy-constraint':
    constraint_type => 'order',
    first_resource  => "${::nova::params::consoleauth_service_name}-clone",
    second_resource => "${::nova::params::vncproxy_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::nova::params::consoleauth_service_name],
                        Pacemaker::Resource::Service[$::nova::params::vncproxy_service_name]],
  }
  pacemaker::constraint::colocation { 'nova-vncproxy-with-nova-consoleauth-colocation':
    source  => "${::nova::params::vncproxy_service_name}-clone",
    target  => "${::nova::params::consoleauth_service_name}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::nova::params::consoleauth_service_name],
                Pacemaker::Resource::Service[$::nova::params::vncproxy_service_name]],
  }
  pacemaker::constraint::base { 'nova-vncproxy-then-nova-api-constraint':
    constraint_type => 'order',
    first_resource  => "${::nova::params::vncproxy_service_name}-clone",
    second_resource => "${::nova::params::api_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::nova::params::vncproxy_service_name],
                        Pacemaker::Resource::Service[$::nova::params::api_service_name]],
  }
  pacemaker::constraint::colocation { 'nova-api-with-nova-vncproxy-colocation':
    source  => "${::nova::params::api_service_name}-clone",
    target  => "${::nova::params::vncproxy_service_name}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::nova::params::vncproxy_service_name],
                Pacemaker::Resource::Service[$::nova::params::api_service_name]],
  }
  pacemaker::constraint::base { 'nova-api-then-nova-scheduler-constraint':
    constraint_type => 'order',
    first_resource  => "${::nova::params::api_service_name}-clone",
    second_resource => "${::nova::params::scheduler_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::nova::params::api_service_name],
                        Pacemaker::Resource::Service[$::nova::params::scheduler_service_name]],
  }
  pacemaker::constraint::colocation { 'nova-scheduler-with-nova-api-colocation':
    source  => "${::nova::params::scheduler_service_name}-clone",
    target  => "${::nova::params::api_service_name}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::nova::params::api_service_name],
                Pacemaker::Resource::Service[$::nova::params::scheduler_service_name]],
  }
  pacemaker::constraint::base { 'nova-scheduler-then-nova-conductor-constraint':
    constraint_type => 'order',
    first_resource  => "${::nova::params::scheduler_service_name}-clone",
    second_resource => "${::nova::params::conductor_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::nova::params::scheduler_service_name],
                        Pacemaker::Resource::Service[$::nova::params::conductor_service_name]],
  }
  pacemaker::constraint::colocation { 'nova-conductor-with-nova-scheduler-colocation':
    source  => "${::nova::params::conductor_service_name}-clone",
    target  => "${::nova::params::scheduler_service_name}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::nova::params::scheduler_service_name],
                Pacemaker::Resource::Service[$::nova::params::conductor_service_name]],
  }

  # Ceilometer
  case downcase(hiera('ceilometer_backend')) {
    /mysql/: {
      pacemaker::resource::service { $::ceilometer::params::agent_central_service_name:
        clone_params => 'interleave=true',
        require      => Pacemaker::Resource::Ocf['openstack-core'],
      }
    }
    default: {
      pacemaker::resource::service { $::ceilometer::params::agent_central_service_name:
        clone_params => 'interleave=true',
        require      => [Pacemaker::Resource::Ocf['openstack-core'],
                        Pacemaker::Resource::Service[$::mongodb::params::service_name]],
      }
    }
  }
  pacemaker::resource::service { $::ceilometer::params::collector_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::resource::service { $::ceilometer::params::api_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::resource::service { $::ceilometer::params::agent_notification_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::resource::ocf { 'delay' :
    ocf_agent_name  => 'heartbeat:Delay',
    clone_params    => 'interleave=true',
    resource_params => 'startdelay=10',
  }
  # Fedora doesn't know `require-all` parameter for constraints yet
  if $::operatingsystem == 'Fedora' {
    $redis_ceilometer_constraint_params = undef
  } else {
    $redis_ceilometer_constraint_params = 'require-all=false'
  }
  pacemaker::constraint::base { 'redis-then-ceilometer-central-constraint':
    constraint_type   => 'order',
    first_resource    => 'redis-master',
    second_resource   => "${::ceilometer::params::agent_central_service_name}-clone",
    first_action      => 'promote',
    second_action     => 'start',
    constraint_params => $redis_ceilometer_constraint_params,
    require           => [Pacemaker::Resource::Ocf['redis'],
                          Pacemaker::Resource::Service[$::ceilometer::params::agent_central_service_name]],
  }
  pacemaker::constraint::base { 'keystone-then-ceilometer-central-constraint':
    constraint_type => 'order',
    first_resource  => 'openstack-core-clone',
    second_resource => "${::ceilometer::params::agent_central_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::ceilometer::params::agent_central_service_name],
                        Pacemaker::Resource::Ocf['openstack-core']],
  }
  pacemaker::constraint::base { 'ceilometer-central-then-ceilometer-collector-constraint':
    constraint_type => 'order',
    first_resource  => "${::ceilometer::params::agent_central_service_name}-clone",
    second_resource => "${::ceilometer::params::collector_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::ceilometer::params::agent_central_service_name],
                        Pacemaker::Resource::Service[$::ceilometer::params::collector_service_name]],
  }
  pacemaker::constraint::base { 'ceilometer-collector-then-ceilometer-api-constraint':
    constraint_type => 'order',
    first_resource  => "${::ceilometer::params::collector_service_name}-clone",
    second_resource => "${::ceilometer::params::api_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::ceilometer::params::collector_service_name],
                        Pacemaker::Resource::Service[$::ceilometer::params::api_service_name]],
  }
  pacemaker::constraint::colocation { 'ceilometer-api-with-ceilometer-collector-colocation':
    source  => "${::ceilometer::params::api_service_name}-clone",
    target  => "${::ceilometer::params::collector_service_name}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::ceilometer::params::api_service_name],
                Pacemaker::Resource::Service[$::ceilometer::params::collector_service_name]],
  }
  pacemaker::constraint::base { 'ceilometer-api-then-ceilometer-delay-constraint':
    constraint_type => 'order',
    first_resource  => "${::ceilometer::params::api_service_name}-clone",
    second_resource => 'delay-clone',
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::ceilometer::params::api_service_name],
                        Pacemaker::Resource::Ocf['delay']],
  }
  pacemaker::constraint::colocation { 'ceilometer-delay-with-ceilometer-api-colocation':
    source  => 'delay-clone',
    target  => "${::ceilometer::params::api_service_name}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::ceilometer::params::api_service_name],
                Pacemaker::Resource::Ocf['delay']],
  }
  if downcase(hiera('ceilometer_backend')) == 'mongodb' {
    pacemaker::constraint::base { 'mongodb-then-ceilometer-central-constraint':
      constraint_type => 'order',
      first_resource  => "${::mongodb::params::service_name}-clone",
      second_resource => "${::ceilometer::params::agent_central_service_name}-clone",
      first_action    => 'start',
      second_action   => 'start',
      require         => [Pacemaker::Resource::Service[$::ceilometer::params::agent_central_service_name],
                          Pacemaker::Resource::Service[$::mongodb::params::service_name]],
    }
  }

  # Heat
  pacemaker::resource::service { $::heat::params::api_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::resource::service { $::heat::params::api_cloudwatch_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::resource::service { $::heat::params::api_cfn_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::resource::service { $::heat::params::engine_service_name :
    clone_params => 'interleave=true',
  }
  pacemaker::constraint::base { 'keystone-then-heat-api-constraint':
    constraint_type => 'order',
    first_resource  => 'openstack-core-clone',
    second_resource => "${::heat::params::api_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::heat::params::api_service_name],
                        Pacemaker::Resource::Ocf['openstack-core']],
  }
  pacemaker::constraint::base { 'heat-api-then-heat-api-cfn-constraint':
    constraint_type => 'order',
    first_resource  => "${::heat::params::api_service_name}-clone",
    second_resource => "${::heat::params::api_cfn_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::heat::params::api_service_name],
                        Pacemaker::Resource::Service[$::heat::params::api_cfn_service_name]],
  }
  pacemaker::constraint::colocation { 'heat-api-cfn-with-heat-api-colocation':
    source  => "${::heat::params::api_cfn_service_name}-clone",
    target  => "${::heat::params::api_service_name}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::heat::params::api_cfn_service_name],
                Pacemaker::Resource::Service[$::heat::params::api_service_name]],
  }
  pacemaker::constraint::base { 'heat-api-cfn-then-heat-api-cloudwatch-constraint':
    constraint_type => 'order',
    first_resource  => "${::heat::params::api_cfn_service_name}-clone",
    second_resource => "${::heat::params::api_cloudwatch_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::heat::params::api_cloudwatch_service_name],
                        Pacemaker::Resource::Service[$::heat::params::api_cfn_service_name]],
  }
  pacemaker::constraint::colocation { 'heat-api-cloudwatch-with-heat-api-cfn-colocation':
    source  => "${::heat::params::api_cloudwatch_service_name}-clone",
    target  => "${::heat::params::api_cfn_service_name}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::heat::params::api_cfn_service_name],
                Pacemaker::Resource::Service[$::heat::params::api_cloudwatch_service_name]],
  }
  pacemaker::constraint::base { 'heat-api-cloudwatch-then-heat-engine-constraint':
    constraint_type => 'order',
    first_resource  => "${::heat::params::api_cloudwatch_service_name}-clone",
    second_resource => "${::heat::params::engine_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::heat::params::api_cloudwatch_service_name],
                        Pacemaker::Resource::Service[$::heat::params::engine_service_name]],
  }
  pacemaker::constraint::colocation { 'heat-engine-with-heat-api-cloudwatch-colocation':
    source  => "${::heat::params::engine_service_name}-clone",
    target  => "${::heat::params::api_cloudwatch_service_name}-clone",
    score   => 'INFINITY',
    require => [Pacemaker::Resource::Service[$::heat::params::api_cloudwatch_service_name],
                Pacemaker::Resource::Service[$::heat::params::engine_service_name]],
  }
  pacemaker::constraint::base { 'ceilometer-notification-then-heat-api-constraint':
    constraint_type => 'order',
    first_resource  => "${::ceilometer::params::agent_notification_service_name}-clone",
    second_resource => "${::heat::params::api_service_name}-clone",
    first_action    => 'start',
    second_action   => 'start',
    require         => [Pacemaker::Resource::Service[$::heat::params::api_service_name],
                        Pacemaker::Resource::Service[$::ceilometer::params::agent_notification_service_name]],
  }

  # Horizon and Keystone
  pacemaker::resource::service { $::apache::params::service_name:
    clone_params     => 'interleave=true',
    verify_on_create => true,
    require          => [File['/etc/keystone/ssl/certs/ca.pem'],
    File['/etc/keystone/ssl/private/signing_key.pem'],
    File['/etc/keystone/ssl/certs/signing_cert.pem']],
  }

  #VSM
  if 'cisco_n1kv' in hiera('neutron::plugins::ml2::mechanism_drivers') {
    pacemaker::resource::ocf { 'vsm-p' :
      ocf_agent_name  => 'heartbeat:VirtualDomain',
      resource_params => 'force_stop=true config=/var/spool/cisco/vsm/vsm_primary_deploy.xml',
      require         => Class['n1k_vsm'],
      meta_params     => 'resource-stickiness=INFINITY',
    }
    if str2bool(hiera('n1k_vsm::pacemaker_control', true)) {
      pacemaker::resource::ocf { 'vsm-s' :
        ocf_agent_name  => 'heartbeat:VirtualDomain',
        resource_params => 'force_stop=true config=/var/spool/cisco/vsm/vsm_secondary_deploy.xml',
        require         => Class['n1k_vsm'],
        meta_params     => 'resource-stickiness=INFINITY',
      }
      pacemaker::constraint::colocation { 'vsm-colocation-contraint':
        source  => 'vsm-p',
        target  => 'vsm-s',
        score   => '-INFINITY',
        require => [Pacemaker::Resource::Ocf['vsm-p'],
                    Pacemaker::Resource::Ocf['vsm-s']],
      }
    }
  }

}




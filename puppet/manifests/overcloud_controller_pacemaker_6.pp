

if $pacemaker_master {

  class {'::keystone::roles::admin' :
    require => Pacemaker::Resource::Service[$::apache::params::service_name],
  } ->
  class {'::keystone::endpoint' :
    require => Pacemaker::Resource::Service[$::apache::params::service_name],
  }
  include ::heat::keystone::domain
  Class['::keystone::roles::admin'] -> Class['::heat::keystone::domain']

} else {
  # On non-master controller we don't need to create Keystone resources again
  class { '::heat::keystone::domain':
    manage_domain => false,
    manage_user   => false,
    manage_role   => false,
  }
}




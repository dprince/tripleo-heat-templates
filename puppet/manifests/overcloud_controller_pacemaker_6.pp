#Step 6
if $pacemaker_master {

  class {'::keystone::roles::admin' :
    require => Pacemaker::Resource::Service[$::keystone::params::service_name],
  } ->
  class {'::keystone::endpoint' :
    require => Pacemaker::Resource::Service[$::keystone::params::service_name],
  }

}

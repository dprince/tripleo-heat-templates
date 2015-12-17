create_resources(sysctl::value, hiera('sysctl_settings'), {})

$enable_load_balancer = hiera('enable_load_balancer', true)

$controller_node_ips = split(hiera('controller_node_ips'), ',')

if $enable_load_balancer {
  class { '::tripleo::loadbalancer' :
    controller_hosts => $controller_node_ips,
    manage_vip       => true,
  }
}

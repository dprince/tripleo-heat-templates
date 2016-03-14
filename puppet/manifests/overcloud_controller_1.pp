

create_resources(kmod::load, hiera('kernel_modules'), {})
create_resources(sysctl::value, hiera('sysctl_settings'), {})
Exec <| tag == 'kmod::load' |>  -> Sysctl <| |>

$controller_node_ips = split(hiera('controller_node_ips'), ',')

if $enable_load_balancer {
  class { '::tripleo::loadbalancer' :
    controller_hosts => $controller_node_ips,
    manage_vip       => true,
  }
}




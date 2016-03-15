========
services
========

A TripleO nested stack Heat template that encapsulates generic configuration
data to configure a specific service. This generally includes everything
needed to configure the service excluding the local bind ports which
are still managed in the per-node role templates directly (controller.yaml,
compute.yaml, etc.).

Input Parameters
----------------

Each service may define its own input parameters and defaults. In
general users will use the parameter_defaults section of a Heat
environment to set per service parameters.

Config Settings
---------------

Each service may define a config_settings output variable which returns
Hiera settings to be configured.

Steps
-----

Each service may define an output variable which returns a puppet manifest
snippet that will run at each of the following steps. Earlier manifests
are re-asserted when applying latter ones.

 * config_step1: Load Balancer

 * config_step2: Core Services (Database/Rabbit/NTP/etc.)

 * config_step3: Openstack Service setup (Ringbuilder, etc.)

 * config_step4: OpenStack Services

 * config_step5: Service activation (Pacemaker)

 * config_step6: Fencing (Pacemaker)

[![Build Status](https://secure.travis-ci.org/marthag8/zone.png)](http://travis-ci.org/marthag8/zone)

Description
===========

Lightweight resource and provider to manage Solaris zones.


Solaris, OpenCSW pkgutil already installed.


Configures, installs and boots Solaris zones.

Only a limited sub-set of configuration options are supported.

If the configuration of a running zone is changed, the zone must be rebooted for the changes to take effect.

New in version 0.0.2:

* /etc/sysidcfg is now created by default from a template.  Turn this off by setting use_sysidcfg to false.
* If copy_sshd_config is true (default), /etc/ssh/sshd_config is copied from the global zone to the new zone.

New in version 0.0.4:

* You can now re-configure options after a zone is setup.
* More options are supported.

Requirements
============

Solaris, zonecfg, zoneadm.

Attributes
==========

For /etc/sysidcfg:

    node[:zone][:timeserver]  - The NTP server to use.
    node[:zone][:timezone]    - The timezone for the zone.
    node[:zone][:dns_servers] - Array of DNS servers.

For the zones:

    path              - Required.  The path of the zone's filesystem.
    clone             - If set, the name of the zone you want to clone the new zone from.  That zone must be installed and not running.
    autoboot          - "true" (default) or "false".  Must be a string, not a boolean.
    limitpriv         -  String containing set of privileges for the zone.
    iptype            - "shared" (default) or "exclusive".
    nets              - Array of network interfaces to add.  Interfaces must be in the format of "address:physical(:defrouter)
    datasets          - Array of datasets to include on this zone.
    inherits          - Array of inherit-pkg-dir directories. These cannot be changed after the zone is installed. Defaults to [ "/lib", "/platform", "/sbin", "/usr" ].
    password          - Root password for the zone, to put in /etc/sysidcfg.  Must be encyrpted with crypt.
    use_sysidcfg      - Whether or not to create a sysidcfg file. Defaults to true.
    sysidcfg_template - Template name to use for /etc/sysidcfg.  Defaults to "sysidcfg.erb"
    copy_ssd_config   - Whether or not to copy /etc/ssh/sshd_config from the global zone to the new zone when the zone is created.  Defaults to true.


Usage
=====

    zone "test" do
      action :install
      path "/opt/zones/test"
      limitpriv "default,dtrace_proc,dtrace_user"
      password "whbFxl4vH5guE"
      sysidcfg_template "my_sysidcfg.erb"
      copy_sshd_config false
      nets [ "192.168.0.2/24:e1000g0:192.168.0.1" ]
      inherits ["/lib", "/bin", "/opt"]
    end
  
    zone "test2" do
      action :start
      clone "test"
      autoboot "false"
      path "/zones/test2"
      datasets [ "zones/test/mysql_data" ]
    end
  

### Actions

:install implies :configure
:start implies :install and :configure

:delete implies :stop

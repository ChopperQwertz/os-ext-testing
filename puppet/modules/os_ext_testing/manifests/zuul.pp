class os_ext_testing::zuul(
  $vhost_name = $::fqdn,
  $gearman_server = '127.0.0.1',
  $gerrit_server = '',
  $gerrit_user = '',
  $gerrit_ssh_host_key = '',
  $gerrit_baseurl = '',
  $git_email = '',
  $git_name = '',
  $smtp_host = '',
  $job_name_in_report = false,
  $zuul_ssh_private_key = '',
  $url_pattern = '',
  $zuul_url = '',
  $status_url = 'http://status.openstack.org/zuul/',
  $swift_authurl = '',
  $swift_auth_version = '',
  $swift_user = '',
  $swift_key = '',
  $swift_tenant_name = '',
  $swift_region_name = '',
  $swift_default_container = '',
  $swift_default_logserver_prefix = '',
  $statsd_host = '',
  $project_config_repo = '',
  $layout_dir = '',
) {

  if $project_config_repo != '' {
    class { 'project_config':
      url  => $project_config_repo,
    }
  }

  class { '::zuul':
    vhost_name                     => $vhost_name,
    gearman_server                 => $gearman_server,
    gerrit_server                  => $gerrit_server,
    gerrit_user                    => $gerrit_user,
    zuul_ssh_private_key           => $zuul_ssh_private_key,
    url_pattern                    => $url_pattern,
    zuul_url                       => $zuul_url,
    job_name_in_report             => $job_name_in_report,
    status_url                     => $status_url,
    statsd_host                    => $statsd_host,
    gerrit_baseurl                 => $gerrit_baseurl,
    git_email                      => $git_email,
    git_name                       => $git_name,
    smtp_host                      => $smtp_host,
    swift_authurl                  => $swift_authurl,
    swift_auth_version             => $swift_auth_version,
    swift_user                     => $swift_user,
    swift_key                      => $swift_key,
    swift_tenant_name              => $swift_tenant_name,
    swift_region_name              => $swift_region_name,
    swift_default_container        => $swift_default_container,
    swift_default_logserver_prefix => $swift_default_logserver_prefix,
  }

  if $project_config_repo != '' {
    class { '::zuul::server':
      layout_dir => $::project_config::zuul_layout_dir,
      require    => $::project_config::config_dir,
    }
  } else {
    class { '::zuul::server':
      layout_dir  => $layout_dir,
    }
  }

  if $gerrit_ssh_host_key != '' {
    file { '/home/zuul/.ssh':
      ensure  => directory,
      owner   => 'zuul',
      group   => 'zuul',
      mode    => '0700',
      require => Class['::zuul'],
    }
    file { '/home/zuul/.ssh/known_hosts':
      ensure  => present,
      owner   => 'zuul',
      group   => 'zuul',
      mode    => '0600',
      content => $gerrit_ssh_host_key,
      replace => true,
      require => File['/home/zuul/.ssh'],
    }
  }

  file { '/etc/zuul/logging.conf':
    ensure => present,
    source => 'puppet:///modules/openstack_project/zuul/logging.conf',
    notify => Exec['zuul-check-reload'],
  }

  file { '/etc/zuul/gearman-logging.conf':
    ensure => present,
    source => 'puppet:///modules/openstack_project/zuul/gearman-logging.conf',
    notify => Exec['zuul-check-reload'],
  }

  file { '/etc/zuul/merger-logging.conf':
    ensure => present,
    source => 'puppet:///modules/openstack_project/zuul/merger-logging.conf',
  }

  #TODO: Openstack doesn't have this here. Find out why.
  file { '/etc/zuul/layout/openstack_functions.py':
    ensure => present,
    source  => 'puppet:///modules/os_ext_testing/zuul/openstack_functions.py',
    notify => Exec['zuul-check-reload'],
  }

  # We need to make sure the configuration is correct before reloading zuul,
  # Otherwise the zuul process could get into a bad state that is difficult
  # to debug
  exec { 'zuul-check-reload':
    command     => '/usr/local/bin/zuul-server -t',
    logoutput   => on_failure,
    require     => File['/etc/init.d/zuul'],
    refreshonly => true,
    notify => Exec['zuul-reload'],
  }
}

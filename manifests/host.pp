# all the things needed on the pushing host
class i2ndsitebackup::host(
  $config,
  $cron_start_time  = '0 5 * * *',
  $key_basepath = '/etc/puppet/modules/site_securefile/files'
){
  require gpg
  require duplicity
  require logrotate

  $key_path = "${$key_basepath}/i2ndsitebackup/keys/${fqdn}"
  $ssh_keys = ssh_keygen("${key_path}/duplicity")
  file{
    '/opt/2ndsite_backup':
      ensure => directory,
      owner  => root,
      group  => 0,
      mode   => '0600';
    '/opt/2ndsite_backup/2ndsite_backup':
      source => 'puppet:///modules/i2ndsitebackup/2ndsite_backup.rb',
      owner  => root,
      group  => 0,
      mode   => '0500';
    '/opt/2ndsite_backup/restore_backup':
      source => 'puppet:///modules/i2ndsitebackup/restore_backup.rb',
      owner  => root,
      group  => 0,
      mode   => '0500';
    '/opt/2ndsite_backup/options.yml':
      content => template('i2ndsitebackup/options.yml.erb'),
      owner   => root,
      group   => 0,
      mode    => '0400';
    '/opt/2ndsite_backup/soft_failing_targets.yml':
      ensure => present,
      owner  => root,
      group  => 0,
      mode   => '0400';
    '/opt/2ndsite_backup/duplicity_key':
      content => $ssh_keys[0],
      owner   => root,
      group   => 0,
      mode    => '0400';
    '/etc/cron.d/run_2ndsite_backup':
      content => "${cron_start_time} root /opt/2ndsite_backup/2ndsite_backup >> /var/log/2ndsite_backup.log\n",
      owner   => root,
      group   => 0,
      mode    => '0400';
    '/etc/logrotate.d/2ndsite_backup':
      content => "/var/log/2ndsite_backup*.log {
  weekly
  rotate 4
  missingok
  notifempty
  compress
  copytruncate
}\n",
      owner   => root,
      group   => 0,
      mode    => '0644';
    '/root/.gnupg':
      ensure => directory,
      owner  => root,
      group  => 0,
      mode   => '0600';
    "/root/.gnupg/${config['gpg_key']}.pub":
      content => file("${key_path}/${config['gpg_key']}.pub"),
      owner   => root,
      group   => 0,
      mode    => '0600';
    "/root/.gnupg/${config['gpg_key']}.priv":
      content => file("${key_path}/${config['gpg_key']}.priv"),
      owner   => root,
      group   => 0,
      mode    => '0600';
  }
  exec{
    "import_pub_${config['gpg_key']}":
      command     => "gpg --import < /root/.gnupg/${config['gpg_key']}.pub",
      refreshonly => true,
      returns     => [0,2],
      subscribe   => File["/root/.gnupg/${config['gpg_key']}.pub"];
    "import_priv_${config['gpg_key']}":
      command     => "gpg --batch --import < /root/.gnupg/${config['gpg_key']}.priv",
      refreshonly => true,
      returns     => [0,2],
      subscribe   => File["/root/.gnupg/${config['gpg_key']}.priv"];
  }
  include clamav::backup_webhosting_scan
  include ibackup::disks
  selinux::fcontext{
    "${config['archive_dir']}(/.*)?":
      setype => 'tmp_t',
  } -> disks::lv_mount{
    'duplicity_archive':
      folder  => $config['archive_dir'],
      size    => pick($config['archive_size'],'20G'),
      mode    => '0700',
      seltype => 'tmp_t',
      require => File['/data'],
  } -> file{
    "${config['archive_dir']}/tmp":
      ensure  => directory,
      owner   => root,
      group   => 0,
      mode    => '0600',
      seltype => 'tmp_t',
  }

}

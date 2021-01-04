# all the things needed on the pushing host
class i2ndsitebackup::host (
  $config,
  $cron_start_time  = '0 5 * * *',
  $key_basepath = '/etc/puppet/modules/site_securefile/files'
) {
  require gpg
  require duplicity

  $key_path = "${$key_basepath}/i2ndsitebackup/keys/${facts['networking']['fqdn']}"
  $ssh_keys = ssh_keygen("${key_path}/duplicity")
  file {
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
      ensure => file,
      owner  => root,
      group  => 0,
      mode   => '0400';
    '/opt/2ndsite_backup/duplicity_key':
      content => $ssh_keys[0],
      owner   => root,
      group   => 0,
      mode    => '0400';
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
  require systemd::mail_on_failure

  systemd::unit_file {
    'i2ndsitebackup@.service':
      content => epp('i2ndsitebackup/cron.service.epp',{ archive_dir => $config['archive_dir'] }),
  }
  $config['hosts'].keys.each |$h| {
    systemd::timer {
      "i2ndsitebackup@${h}.timer":
        timer_content => epp('i2ndsitebackup/cron.timer.epp'),
        active        => true,
        enable        => true,
    }
  }

  exec {
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
  $tmp_dirs = $config['hosts'].keys.map |$h| {
    "${config['archive_dir']}/tmp/${h}-22"
  }
  selinux::fcontext {
    "${config['archive_dir']}(/.*)?":
      setype => 'tmp_t',
  } -> disks::lv_mount {
    'duplicity_archive':
      folder  => $config['archive_dir'],
      size    => pick($config['archive_size'],'20G'),
      mode    => '0700',
      seltype => 'tmp_t',
      require => File['/data'],
  } -> file {
    default:
      ensure  => directory,
      owner   => root,
      group   => 0,
      mode    => '0600',
      seltype => 'tmp_t';
    "${config['archive_dir']}/tmp":;
    $tmp_dirs:;
  }
}

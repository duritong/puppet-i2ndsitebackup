# things to be setup on the pushing host
class i2ndsitebackup::receiver(
  Stdlib::Fqdn $source_host,
  String $user_password,
  Stdlib::Unixpath $ssh_key_basepath = '/etc/puppet/modules/site_securefile/files',
  Integer $cleanup_days = 360, # (1 + 2) * 120 = (1 + fullcount) * incremental_days
  Stdlib::Unixpath $fs_device = '/dev/storage/2ndsite_duplicity',
  String $fstype = 'xfs',
  String $fs_options = 'defaults,noexec,nodev',
){

  require rsync::client

  user::managed{
    'sndsite':
      password => $user_password,
      sshkey   => 'i2ndsitebackup::receiver::sshkeys',
  }

  group{'backup': ensure => present }

  user::groups::manage_user{'sndsite':
    group   => 'backup',
    require => [ User::Managed['sndsite'], Group['backup'] ],
  }


  file{'/srv/backup':
    ensure => directory,
    owner  => sndsite,
    group  => 0,
    mode   => '0600';
  } -> mount{'sndsite_disk':
    name    => '/srv/backup',
    device  => $fs_device,
    fstype  => $fstype,
    options => $fs_options,
  } -> file{
    '/etc/cron.monthly/backup_cleanup.sh':
      content => template('i2ndsitebackup/cleanup_receiver.sh.erb'),
      owner   => root,
      group   => 0,
      mode    => '0700',
  }
}

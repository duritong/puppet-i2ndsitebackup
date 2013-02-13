# things to be setup on the pushing host
class i2ndsitebackup::receiver(
  $user_password,
  $source_host,
  $ssh_key_basepath = '/etc/puppet/modules/site_securefile/files'
){

  require cryptsetup
  require rsync::client

  user::managed{
    'sndsite':
      password  => $user_password,
      sshkey    => 'i2ndsitebackup::receiver::sshkeys',
  }

  group{'backup': ensure => present }

  user::groups::manage_user{'sndsite':
    group   => 'backup',
    require => [ User::Managed['sndsite'], Group['backup'] ],
  }


  file{'/srv/backup':
    ensure  => directory,
    owner   => sndsite,
    group   => 0,
    mode    => '0600';
  }

  mount{'sndsite_disk':
    device  => '/dev/mapper/2ndsite_backup',
    target  => '/srv/backup',
    fstype  => 'ext4',
    options => 'defaults,noexec,nodev,noauto',
    require => File['/srv/backup'],
  }
}

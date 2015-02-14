# ssh keys for the 2ndsite host
class i2ndsitebackup::receiver::sshkeys {
  $ssh_keys = ssh_keygen("${$i2ndsitebackup::receiver::ssh_key_basepath}/i2ndsitebackup/keys/${i2ndsitebackup::receiver::source_host}/duplicity")

  sshd::authorized_key{'sndsite':
    user  => 'sndsite',
    key   => $ssh_keys[1],
  }
}

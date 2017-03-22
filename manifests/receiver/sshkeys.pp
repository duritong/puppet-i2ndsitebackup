# ssh keys for the 2ndsite host
class i2ndsitebackup::receiver::sshkeys {
  $ssh_keys = ssh_keygen("${$i2ndsitebackup::receiver::ssh_key_basepath}/i2ndsitebackup/keys/${i2ndsitebackup::receiver::source_host}/duplicity")

  $split_ssh_keys = split($ssh_keys[1],' ')
  sshd::authorized_key{'sndsite':
    user  => 'sndsite',
    key   => $split_ssh_keys[1],
  }
}

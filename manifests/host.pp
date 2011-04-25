class i2ndsitebackup::host(
  $config_content,
  $ssh_key_basepath = "/etc/puppet/modules/site-securefile/files"
){
  require gpg 
  require duplicity

  $ssh_keys = ssh_keygen("${$ssh_key_basepath}/i2ndsitebackup/keys/${fqdn}/duplicity")
  file{
    '/opt/2ndsite_backup':
      ensure => directory,
      owner => root, group => 0, mode => 0600;
    '/opt/2ndsite_backup/2ndsite_backup':
      source => 'puppet:///modules/2ndsitebackup/2ndsite_backup',
      owner => root, group => 0, mode => 0500;
    '/opt/2ndsite_backup/options.yml':
      content => $config_content,
      owner => root, group => 0, mode => 0400;
    '/opt/2ndsite_backup/duplicity_key':
      content => $ssh_keys[0],
      owner => root, group => 0, mode => 0400;
    '/etc/cron.d/run_2ndsite_backup':
      content => "0 1 * * * root /opt/2ndsite_backup/2ndsite_backup > /dev/null\n",
      owner => root, group => 0, mode => 0400;
    '/etc/cron.d/kill_2ndsite_backup':
      content => "0 8 * * * root kill -9 `ps ax | grep 2ndsite_backup | grep -v grep | awk '{ print \$1 }'`\n",
      owner => root, group => 0, mode => 0400;
  }
}

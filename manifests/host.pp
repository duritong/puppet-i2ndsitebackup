class i2ndsitebackup::host(
  $config_content,
  $ssh_key_basepath = "/etc/puppet/modules/site-securefile/files"
){
  require gpg 
  require duplicity
  require logrotate

  $ssh_keys = ssh_keygen("${$ssh_key_basepath}/i2ndsitebackup/keys/${fqdn}/duplicity")
  file{
    '/opt/2ndsite_backup':
      ensure => directory,
      owner => root, group => 0, mode => 0600;
    '/opt/2ndsite_backup/2ndsite_backup':
      source => 'puppet:///modules/i2ndsitebackup/2ndsite_backup',
      owner => root, group => 0, mode => 0500;
    '/opt/2ndsite_backup/options.yml':
      content => $config_content,
      owner => root, group => 0, mode => 0400;
    '/opt/2ndsite_backup/duplicity_key':
      content => $ssh_keys[0],
      owner => root, group => 0, mode => 0400;
    '/etc/cron.d/run_2ndsite_backup':
      content => "0 1 * * * root /opt/2ndsite_backup/2ndsite_backup >> /var/log/2ndsite_backup.log\n",
      owner => root, group => 0, mode => 0400;
    '/etc/cron.d/kill_2ndsite_backup':
      content => "0 8 * * * root pids=\$(ps ax | grep 2ndsite_backup | grep -v grep | awk '{ print \$1 }'); for pid in \$pids; do kill -9 \$pid; done >> /var/log/2ndsite_backup_kill.log\n",
      owner => root, group => 0, mode => 0400;
    '/etc/logrotate.d/2ndsite_backup':
      content => "/var/log/2ndsite_backup*.log {
  weekly
  rotate 4
  missingok
  notifempty
  compress
  nocreate
}\n",
      owner => root, group => 0, mode => 0644;
  }
}

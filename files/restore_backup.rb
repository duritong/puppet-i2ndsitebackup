#!/usr/bin/env ruby

if ARGV[0].nil? || ARGV[1].nil? || ARGV[2].nil?
  puts "USAGE: $0 backup_host backup_path restore_time"
  puts "EXAMPLE: $0 backup1 target/subtarget/another_subtarget 3D"
  exit 1
end

require 'yaml'
options = YAML.load_file('/opt/2ndsite_backup/options.yml')

host=ARGV.shift
src=ARGV.shift
time=ARGV.shift

unless options['hosts'][host]
  puts "No such host '#{host}' configured. Configured hosts: #{options['hosts'].keys.join(', ')}"
  exit 1
end

if options['archive_dir']
  target = File.join(File.join(options['archive_dir'],'restore'),File.basename(src))
  archive_dir = "--archive-dir #{options['archive_dir']} --tempdir #{File.join(options['archive_dir'],'tmp')} "
else
  target = File.join('/tmp',File.basename(src))
  archive_dir = ''
end

puts "Starting restore..."
old_value = ENV['PASSPHRASE']
begin
 ENV['PASSPHRASE'] = options['passphrase']
 ENV['GNUPGHOME'] = options['gnupghome']
 proto = options['hosts'][host]['backend'] == 'ssh' ? 'rsync' : 'sftp'
 ssh_host, ssh_port = host.split(':',2)
 system("duplicity restore #{archive_dir}--restore-time #{time} --ssh-options '-oIdentityFile=/opt/2ndsite_backup/duplicity_key -oPort=#{ssh_port}' --encrypt-key #{options['gpg_key']} --sign-key #{options['gpg_key']} #{proto}://#{options['hosts'][host]['user']}@#{ssh_host}/#{options['hosts'][host]['root']}/#{src}/ #{target}")
ensure
  ENV['PASSPHRASE'] = old_value
end
if $?.to_i > 0
  puts "A failure happened!"
else
  puts "Done! You find your restored backup in #{target}"
end
exit $?.to_i

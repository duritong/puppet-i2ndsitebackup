#!/usr/bin/env ruby

if ARGV[0].nil? || ARGV[1].nil?
  puts "USAGE: $0 backup_path restore_time"
  puts "EXAMPLE: $0 target/subtarget/another_subtarget 3D"
  exit 1
end

require 'yaml'
options = YAML.load_file('/opt/2ndsite_backup/options.yml')

src=ARGV.shift
time=ARGV.shift
target = File.join('/tmp',File.basename(src))

puts "Starting restore..."
system("PASSPHRASE='#{options['passphrase']}' duplicity restore --restore-time #{time} --ssh-options '-oIdentityFile=/opt/2ndsite_backup/duplicity_key' --encrypt-key #{options['gpg_key']} --sign-key #{options['gpg_key']} rsync://#{options['target_user']}@#{options['target_host']}/#{options['target_root']}/#{src}/ #{target}")
if $?.to_i > 0
  puts "A failure happened!"
else
  puts "Done! You find your restored backup in #{target}"
end
exit $?.to_i

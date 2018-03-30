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
if options['archive_dir']
  target = File.join(File.join(options['archive_dir'],'restore'),File.basename(src))
  archive_dir = "--archive-dir #{options['archive_dir']} "
else
  target = File.join('/tmp',File.basename(src))
  archive_dir = ''
end

puts "Starting restore..."
old_value = ENV['PASSPHRASE']
begin
 ENV['PASSPHRASE'] = options['passphrase']
 system("duplicity restore #{archive_dir}--restore-time #{time} --ssh-options '-oIdentityFile=/opt/2ndsite_backup/duplicity_key' --encrypt-key #{options['gpg_key']} --sign-key #{options['gpg_key']} rsync://#{options['target_user']}@#{options['target_host']}/#{options['target_root']}/#{src}/ #{target}")
ensure
  ENV['PASSPHRASE'] = old_value
end
if $?.to_i > 0
  puts "A failure happened!"
else
  puts "Done! You find your restored backup in #{target}"
end
exit $?.to_i

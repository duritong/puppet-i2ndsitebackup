#!/bin/env ruby

require 'singleton'
require 'yaml'

class DuplicityRunner

  include Singleton

  def run
    if File.exist?(lockfile)
      pid = File.read(lockfile).chomp
      if File.directory?("/proc/#{pid}")
        STDERR.puts "Lockfile #{lockfile} exists with pid #{pid} and this process still seems to be running"
        exit 1
      else
        puts "Removing staled lockfile #{lockfile}"
      end
    end
    begin
      File.open(lockfile,'w'){|f| f << $$ }
      run_targets
    ensure
      File.delete(lockfile)
    end
  end
  private
  def run_targets
    nt = ft = nil
    while (ft.nil? || nt != ft ) do
      ft ||= nt
      nt = next_target
      puts "#{Time.now} #{nt['subtarget']}"
      break if !system(command(target_id(nt['subtarget']))) && !soft_failing_targets.include?(nt['subtarget'])
      store_target(nt)
      break if Time.now.hour > (options['stop_hour']||23).to_i
    end
  end

  def target_id(target)
    target.sub("#{options['source_root']}/",'')
  end

  def archive_dir
    options['archive_dir'] ?  "--archive-dir #{options['archive_dir']} " : ''
  end

  def command(target)
    "ssh -i /opt/2ndsite_backup/duplicity_key #{options['target_user']}@#{options['target_host']} mkdir -p #{File.join(options['target_root'],target)};"+
    "PASSPHRASE=\"#{options['passphrase']}\" duplicity cleanup #{archive_dir}--extra-clean --force --ssh-options '-oIdentityFile=/opt/2ndsite_backup/duplicity_key' --encrypt-key #{options['gpg_key']} --sign-key #{options['gpg_key']} ssh://#{options['target_user']}@#{options['target_host']}/#{File.join(options['target_root'],target)};" +
    "PASSPHRASE=\"#{options['passphrase']}\" duplicity remove-all-but-n-full 2 #{archive_dir}--force --ssh-options '-oIdentityFile=/opt/2ndsite_backup/duplicity_key' --encrypt-key #{options['gpg_key']} --sign-key #{options['gpg_key']} ssh://#{options['target_user']}@#{options['target_host']}/#{File.join(options['target_root'],target)};" +
    "PASSPHRASE=\"#{options['passphrase']}\" duplicity #{archive_dir}--full-if-older-than 120D --ssh-options '-oIdentityFile=/opt/2ndsite_backup/duplicity_key' --encrypt-key #{options['gpg_key']} --sign-key #{options['gpg_key']} #{File.join(options['source_root'],target)} ssh://#{options['target_user']}@#{options['target_host']}/#{File.join(options['target_root'],target)}"
  end


  def options
    @options ||= YAML.load(File.read('/opt/2ndsite_backup/options.yml'))
  end

  def subtargets(target)
    (Dir[File.join(options['source_root'],target)+(1..targets[target]).inject(""){|glob,l| "#{glob}/*" }]-[File.join(options['source_root'],target,'lost+found')]).sort
  end

  def next_target
    return first_target if !File.exist?('/opt/2ndsite_backup/state.yml') || (ls = last_state)['target'].nil?
    stargets = subtargets(ls['target'])
    index = stargets.index(ls['subtarget'])
    if index && n_subtarget=stargets[index+1]
      return {'target' => ls['target'], 'subtarget' => n_subtarget }
    else
      tindex = targets.keys.index(ls['target'])
      if tindex && n_target=targets.keys[tindex+1]
        return {'target' => n_target, 'subtarget' => subtargets(n_target).first }
      else
        return first_target
      end 
    end
  end

  def first_target
    { 'target' => targets.keys.first, 'subtarget' => subtargets(targets.keys.first).first }
  end

  def last_state
    YAML.load(File.read('/opt/2ndsite_backup/state.yml'))
  end

  def store_target(target)
    File.open('/opt/2ndsite_backup/state.yml','w'){|f| f << YAML.dump(target) }
  end

  def targets
    options['targets']
  end

  def lockfile
    @lockfile ||= '/opt/2ndsite_backup/run.lock'
  end

  def soft_failing_targets
    @soft_failing_targets ||= load_soft_failing_targets
  end

  def load_soft_failing_targets
    file = '/opt/2ndsite_backup/soft_failing_targets.yml'
    (File.exists?(file) ? YAML.load_file(file) : nil) || []
  end
end

DuplicityRunner.instance.run

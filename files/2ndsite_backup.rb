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
      cleanup_archive
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
      res = true
      with_environment('PASSPHRASE' => options['passphrase']) do
        commands(target_id(nt['subtarget'])).each do |cmd|
          res = res && system(cmd)
        end
      end
      break if !res && !soft_failing_targets.include?(nt['subtarget'])
      store_target(nt)
      break if Time.now.hour >= (options['stop_hour']||23).to_i
    end
  end

  def target_id(target)
    target.sub("#{options['source_root']}/",'')
  end

  def archive_dir
    options['archive_dir'] ?  "--archive-dir #{options['archive_dir']} --tempdir #{File.join(options['archive_dir'],'tmp')} " : ''
  end
  def cleanup_archive
    if options['archive_dir']
      puts "Cleaning up archive_dir #{options['archive_dir']}"
      system("tmpwatch -m #{options['incremental_days'].to_i*options['full_count'].to_i + 1}d #{options['archive_dir']}")
    end
  end

  def commands(target)
    tu = options['target_user']
    th = options['target_host']
    ssh_host, ssh_port = th.split(':',2)
    ssh_port ||= '22'
    td = File.join(options['target_root'],target)
    tdp = File.dirname(td)
    ts = "rsync://#{tu}@#{th}/#{td}"
    du = "--ssh-options '-oIdentityFile=/opt/2ndsite_backup/duplicity_key' --encrypt-key #{options['gpg_key']} --sign-key #{options['gpg_key']} --tempdir /data/duplicity_archive/tmp"
    # we don't want to blindly create the whole tree, because this might mean the volume is not
    # ready
    [ "ssh -i /opt/2ndsite_backup/duplicity_key -p #{ssh_port} #{tu}@#{ssh_host} '(test -d #{tdp} || mkdir #{tdp}) && (test -d #{td} || mkdir #{td})'",
      "duplicity cleanup #{archive_dir}--extra-clean --force #{du} #{ts}",
      "duplicity remove-all-but-n-full #{options['full_count']} #{archive_dir}--force #{du} #{ts}",
      "duplicity #{archive_dir}--full-if-older-than #{options['incremental_days']}D #{du} #{File.join(options['source_root'],target)} #{ts}",
    ]
  end


  def options
    @options ||= YAML.load_file('/opt/2ndsite_backup/options.yml')
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
    YAML.load_file('/opt/2ndsite_backup/state.yml')
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

  def with_environment(variables={})
    if block_given?
      old_values = variables.map{ |k,v| [k,ENV[k]] }
      begin
         variables.each{ |k,v| ENV[k] = v }
         result = yield
      ensure
        old_values.each{ |k,v| ENV[k] = v }
      end
      result
    else
      variables.each{ |k,v| ENV[k] = v }
    end
  end
end

DuplicityRunner.instance.run

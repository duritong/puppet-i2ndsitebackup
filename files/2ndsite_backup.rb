#!/bin/env ruby

require 'singleton'
require 'yaml'
require 'digest/md5'

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
  # loop over all targets until done
  # or until failing
  # run each target per host
  # if a target fails retry 3 times
  # if all hosts fail 3 times abort
  def run_targets
    next_target = {}
    first_target = {}
    while (first_target.values.none? || next_target.keys.all?{|h| next_target[h] != first_target[h] } ) do
      tries = Hash.new(0)
      options['hosts'].keys.each do |host|
        next if tries[host] > 3
        first_target[host] ||= next_target[host]
        next_target[host] = get_next_target(host)
        puts "#{Time.now} #{host} #{next_target[host]['subtarget']}"
        res = true
        with_environment('PASSPHRASE' => options['passphrase']) do
          commands(host, target_id(next_target[host]['subtarget'])).each do |cmd|
            #puts cmd
            res = res && system(cmd)
          end
        end
        if res
          store_target(host,next_target[host])
        else
          tries[host] += 1
        end
      end
      # abort if all hosts have more than 3 failing tries
      break if !tries.empty? && tries.values.all?{|v| v > 3 }
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

  def commands(host,target)
    tu = options['hosts'][host]['user']
    th = host
    ssh_host, ssh_port = th.split(':',2)
    ssh_port ||= '22'
    td = File.join(options['hosts'][host]['root'],target)
    tdp = File.dirname(td)
    tdpp = File.dirname(tdp)
    du = "--ssh-options '-oIdentityFile=/opt/2ndsite_backup/duplicity_key -oPort=#{ssh_port}' --encrypt-key #{options['gpg_key']} --sign-key #{options['gpg_key']} --tempdir /data/duplicity_archive/tmp/#{ssh_host}-#{ssh_port}"
    # we don't want to blindly create the whole tree, because this might mean the volume is not
    # ready
    cmds = []
    if options['hosts'][host]['backend'] == 'ssh'
      ts = "rsync://#{tu}@#{th}/#{td}"
      cmds << "ssh -i /opt/2ndsite_backup/duplicity_key -p #{ssh_port} #{tu}@#{ssh_host} '(test -d #{tdpp} || mkdir #{tdpp}) && (test -d #{tdp} || mkdir #{tdp}) && (test -d #{td} || mkdir #{td})'"
    else
      ts = "sftp://#{tu}@#{th}/#{td}"
      sftp_cmd = "sftp -b - -oidentityfile=/opt/2ndsite_backup/duplicity_key -P #{ssh_port} #{tu}@#{ssh_host}"
      cmds << "(echo 'chdir /backup' | #{sftp_cmd}) && (echo 'chdir #{tdpp}' | #{sftp_cmd} || echo 'mkdir #{tdpp}' | #{sftp_cmd}) && (echo 'chdir #{tdp}' | #{sftp_cmd} || echo 'mkdir #{tdp} | #{sftp_cmd}) && (echo 'chdir #{td}' | #{sftp_cmd} || echo 'mkdir #{tdp} | #{sftp_cmd})"
    end
    cmds + [
      "duplicity cleanup #{archive_dir}--extra-clean --force #{du} #{ts}",
      "duplicity remove-all-but-n-full #{options['full_count']} #{archive_dir}--force #{du} #{ts}",
      "duplicity #{archive_dir}--full-if-older-than #{incremental_days(target)}D #{du} #{File.join(options['source_root'],target)} #{ts}",
    ]
  end

  # spread the next full between 20days around the configured incremental_days
  # use target as seed so we get a constant random offset. this avoids
  # to have large full repushes all on the same day - rather spread accross 20d
  def incremental_days(target)
    seed = Digest::MD5.hexdigest([target,options['incremental_days']].join(':')).hex
    options['incremental_days'].to_i + (Random.new(seed).rand(20) - 10)
  end


  def options
    @options ||= YAML.load_file('/opt/2ndsite_backup/options.yml')
  end

  def subtargets(target)
    (Dir[File.join(options['source_root'],target)+(1..targets[target]).inject(""){|glob,l| "#{glob}/*" }]-[File.join(options['source_root'],target,'lost+found')]).sort
  end

  def get_next_target(host)
    return first_target if !File.exist?('/opt/2ndsite_backup/state.yml') || (ls = last_state(host))['target'].nil?
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

  def last_state(host)
    load_last_state unless @last_state
    @last_state[host] ||= {}
  end
  def load_last_state
    @last_state = if File.readable?('/opt/2ndsite_backup/state.yml')
      YAML.load_file('/opt/2ndsite_backup/state.yml')
    else
      {}
    end
  end

  def store_target(host, target)
    load_last_state unless @last_state
    @last_state[host] = target
    File.open('/opt/2ndsite_backup/state.yml','w'){|f| f << YAML.dump(@last_state) }
  end

  def targets
    options['targets']
  end

  def lockfile
    @lockfile ||= '/opt/2ndsite_backup/run.lock'
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

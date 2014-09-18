require 'logger'
require 'tempfile'
require 'childprocess'

class MercurialOperationError < StandardError; end

class Mercurial

  def initialize(log=nil)
    @logger = log||Logger.new(STDOUT)

    @settings = {
        :basedir => '.',
        :repo_name => '',
        :default_branch => 'default',
        :executable => '/usr/local/bin/hg',
        :timeout => 300
    }
  end

  def root
    repo_name = ''
    repo_name = "#{settings[:repo_name]}" unless settings[:repo_name] == '.'
    "#{settings[:basedir]}/#{repo_name}"
  end

  def settings
    @settings
  end

  def serve(repo_dir=root())
    process = ChildProcess.build(hg, 'serve')
    StringIO.open do |io|
      io.sync
      process.cwd = repo_dir
      process.io.stdout = process.io.stderr = io
      process.start
    end
    process
  end

  def init(basedir = nil)
    cmd = [hg, 'init']
    execute_command cmd, basedir
  end

  def add_remove(basedir = nil)
    cmd = [hg, 'addremove']
    execute_command cmd, basedir
  end

  def clone_repo(repo)
    destination = settings[:repo_name]||settings[:basedir]
    cmd = [hg, 'clone', repo, destination]
    execute_command cmd, settings[:basedir]
  end

  def pull(options=nil)
    cmd = [hg, 'pull']
	  cmd += ['-b', options[:branch]] if options and options[:branch]
    execute_command cmd
  end

  def update_repo(options)
    cmd = [hg, 'update']
    cmd += ['-C', options[:branch]] if options[:branch]
    cmd.push('--check') if options[:force] and !options[:branch]
    execute_command cmd
  end

  def create_branch(branch, username, comment)
    branch_cmd = [hg, 'branch', branch]
    execute_command branch_cmd
    commit_branch_cmd = [hg, 'ci', '-m', comment, '-u', username]
    execute_command commit_branch_cmd
  end

  def current_branch
    cmd = [hg, 'branch']
    branch = execute_command cmd
    branch.strip
  end

  def switch_branch(branch)
    update_to_tip = [hg, 'update','-C', 'tip']
    execute_command update_to_tip
    pull
    update_repo(:force => true)
    update_cmd = [hg, 'update', '-C', branch]
    execute_command update_cmd
  end

  def add(file_name, basedir=nil)
    cmd = [hg, 'add', file_name]
    execute_command cmd , basedir
  end

  def remove(file_name, basedir=nil)
    cmd = [hg, 'remove', file_name]
    execute_command cmd, basedir
  end

  def commit(username, comment, timestamp, basedir=nil)
    cmd = [hg, 'commit', '-u', username, '-d', timestamp, '-m', comment]
    execute_command cmd, basedir
  end

  def push(options=nil)
    cmd = [hg, 'push']
	  cmd += ['-b', options[:branch]] if options and options[:branch]
    execute_command cmd
  end

  def config( &block)
    block.call @settings
    self
  end

  def reset_settings
    @settings = {
        :basedir => '.',
        :repo_name => '',
        :default_branch => 'default',
        :executable => '/usr/local/bin/hg',
        :timeout => 300
    }
  end

  def current_revision(file_name, basedir=nil)
    check_file(file_name)
    cmd = [hg, 'parents', file_name]
    changeset = execute_command(cmd, basedir).split("\n").grep(/changeset/) do |line|
      line.split()[1].strip
    end
    return changeset[0]
  end

  def previous_revision(file_name, current_rev, basedir=nil)
    begin
      cmd =[hg, 'parents', '-r', current_rev, file_name]
      changeset = execute_command(cmd, basedir).split("\n").grep(/changeset/) do |line|
        line.split()[1].strip
      end
      return changeset[0]
    rescue
      return 0 #we always default to 0 when there is no previous revision
    end
  end

  def last_diff(file_name, base_rev=nil, basedir=nil)
    current_rev = base_rev
    begin
      current_rev = current_revision(file_name, basedir) if current_rev.nil?
      previous_rev = previous_revision(file_name, current_rev, basedir)
      return diff(previous_rev, current_rev, file_name, basedir)
    rescue
      cmd =[hg, 'diff', '-r', '0', '-r', current_rev, file_name]
      return execute_command cmd , basedir
    end
  end

  def diff(from_rev, to_rev, file_name, basedir=nil)
    cmd = [hg, 'diff', '-r', from_rev, '-r', to_rev, file_name]
    result =  execute_command cmd, basedir
    return result.lines.to_a[1..-1].join if not result.start_with? 'diff'
    return result
  end

  def apply_patch(file_name, patch_file, basedir=nil)
    cmd = ['patch', file_name, patch_file]
    return execute_command cmd , basedir
  end

  def update(file_name, branch)
    switch_branch(branch)
  end

  def check_file(file_name, basedir=nil)
    root_dir = basedir.nil? ? root : basedir
    if not File.exists? File.join(root_dir, file_name) then
      message =  "Could not find #{file_name}. Are you sure you have set the correct basedir?"
      raise Errno::ENOENT, message
    end
  end

  def default_branch
    settings[:default_branch]
  end

  def get_file_content(file_name, revision, basedir=nil)
    cmd = [hg, 'cat', file_name, '-r', revision]
    execute_command cmd , basedir
  end

  def merge(branch_name, basedir=nil)
    cmd = [hg, 'branch', branch_name]
    execute_command cmd , basedir
  end

  def status(basedir=nil)
    cmd = [hg, 'status']
    execute_command cmd , basedir
  end

  def revert(file_name, options = [], basedir=nil)
    cmd = [hg, 'revert', '-r']
    options.each {|option| cmd.push(option.to_s)}
    cmd.push file_name
    execute_command cmd , basedir
  end

  def hg
    settings[:executable]
  end

  def execute_command(cmd, basedir = nil, timeout=nil)
    basedir = basedir.nil? ? root : basedir
    @logger.debug("Executing command #{cmd.join(' ')} | CWD: #{basedir}")
    command_timeout = timeout||settings[:timeout]
    out = Tempfile.new('hg_cmd')
    process = ChildProcess.build(*cmd)
    process.cwd = basedir
    process.io.stdout = process.io.stderr = out
    process.start
    process.poll_for_exit(command_timeout)
    out.rewind
    result = out.read
    raise MercurialOperationError, "Could not successfully execute command '#{cmd}'\n#{result} exit_code = #{process.exit_code}" if process.exit_code != 0
    result
  rescue ChildProcess::TimeoutError
    raise MercurialOperationError, "TIMEOUT[#{command_timeout}]! Could not successfully execute command '#{cmd}'"
  ensure
    out.close if out
    out.unlink if out
  end

end



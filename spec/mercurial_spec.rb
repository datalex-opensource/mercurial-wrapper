require 'rubygems'
require 'tmpdir'
require 'fileutils'
require 'logger'
require 'childprocess'
require_relative '../lib/mercurial'

describe Mercurial do

  REPO_NAME = 'test_repo'

  def prepare_hg_repo(basedir)
    logger = Logger.new(STDOUT)
    logger.level = Logger::ERROR
    Dir.mkdir File.join(basedir, REPO_NAME)
    mercurial_repo_server = Mercurial.new(logger).config do |settings|
      settings[:basedir] = basedir
      settings[:repo_name] = REPO_NAME
      settings[:executable] ='/usr/local/bin/hg'
    end
    mercurial_repo_server.init
    yield mercurial_repo_server.root if block_given?
    # @server = mercurial_repo_server.serve
    mercurial_repo_server.add_remove
    mercurial_repo_server.commit 'user1', 'initial files', '1135425600 0'
    mercurial_repo_server.create_branch 'branch1', 'test_user', 'Creating a test branch'
    mercurial_repo_server.root
  end

  def open_hg_repo(basedir)
    logger = Logger.new(STDOUT)
    logger.level = Logger::ERROR
    Mercurial.new(logger).config do |settings|
      settings[:basedir] = basedir
      settings[:repo_name] = REPO_NAME
      settings[:executable] ='/usr/local/bin/hg'
    end
  end

  before( :all) do
    dir = Dir.mktmpdir
    Dir.chdir(dir)
    @server_repo_dir = prepare_hg_repo(dir) do |basedir|
      module_dir = File.join(basedir,'module1')
      FileUtils.mkpath module_dir
      FileUtils.touch File.join(module_dir, 'File1.java')
      FileUtils.touch File.join(module_dir, 'File2.java')
    end
  end

  before(:each) do
    @basedir = Dir.mktmpdir
    @test_repo = open_hg_repo(@basedir)
  end

  it 'changes mercurial basedir config' do
    @test_repo.config do |settings|
      settings[:basedir] = 'new/basedir'
    end
    @test_repo.settings[:basedir].should eq 'new/basedir'
  end

  it 'Checks out, changes and commits and pushes a file' do
    @test_repo.clone_repo @server_repo_dir

    open(File.join(@test_repo.root,'module1/File1.java'), 'a') { |file| file << "Some extra text\n" }

    File.exists?(File.join(@test_repo.root,'module1/File1.java')).should be true
    last_line = `tail -n 1 #{File.join(@test_repo.root,'module1/File1.java')}`
    last_line.should eq "Some extra text\n"

    @test_repo.commit 'test_user', 'module1/File1.java', '2013-06-01 00:00:00'
    @test_repo.push
    FileUtils.rm_r @test_repo.root

    @test_repo.clone_repo @server_repo_dir
    last_line = `tail -n 1 #{File.join(@test_repo.root,'module1/File1.java')}`
    last_line.should eq "Some extra text\n"
  end

  it 'asserts the configured root of the scm containing the repo name' do
    @test_repo.root().should eq File.join(@basedir, REPO_NAME)
  end

  it 'asserts the configured root of the scm pointing to the root translator' do
    @test_repo.config do |settings|
      settings[:basedir] = '.'
      settings[:repo_name] = ''
    end
    @test_repo.root().should eq './'
  end

  it 'checks the current revision of a file' do
    @test_repo.clone_repo @server_repo_dir
    @test_repo.current_revision('module1/File1.java').should match /^\d+:(\w)+$/
  end

  it 'checks the previous revision of a file' do
    @test_repo.clone_repo @server_repo_dir
    rev = @test_repo.current_revision('module1/File1.java')
    matches = !!(rev =~ /^\d+:(\w)+$/)
    matches.should be true
    previous = @test_repo.previous_revision('module1/File1.java', rev)
    matches = !!(previous =~ /^\d+:(\w)+$/)
    matches.should be true
    previous.should_not eq rev
  end

  it 'adds a new file to mercurial and then removing it' do
    @test_repo.clone_repo @server_repo_dir
    FileUtils.mkpath File.join(@test_repo.root,'module1/sub_dir')
    open(File.join(@test_repo.root,'module1/sub_dir/A new file.java'), 'ab') { |file| file << "Some extra text\n" }
    @test_repo.add 'module1/sub_dir/A new file.java'
    @test_repo.commit 'fabio.neves@datalex.com', 'adding " "a new file','2013-06-01 00:00:00'
    @test_repo.push
    FileUtils.rm_rf @test_repo.root
    @test_repo.clone_repo @server_repo_dir
    File.exists?(File.join(@test_repo.root,'module1/sub_dir/A new file.java')).should be true
    @test_repo.remove 'module1/sub_dir/A new file.java'
    @test_repo.commit 'fabio.neves@datalex.com', 'Removing file with spaces','2013-06-01 00:00:00'
    @test_repo.push
    FileUtils.rm_rf @test_repo.root
    @test_repo.clone_repo @server_repo_dir
    File.exists?(File.join(@test_repo.root,'module1/sub_dir/A new file.java')).should be false
  end

  it 'checks the last diff of a file' do
    @test_repo.clone_repo @server_repo_dir
    @test_repo.last_diff('module1/File1.java').should_not eq ''
  end

  it 'switches branches' do
    @test_repo.clone_repo @server_repo_dir
    @test_repo.update_repo branch:'branch1'
    @test_repo.current_branch.should eq 'branch1'
    @test_repo.update_repo branch: 'default'
    @test_repo.current_branch.should eq 'default'
  end

  after(:each) do
    FileUtils.rm_rf @basedir
  end

  after(:all) do
    FileUtils.rm_rf @server_repo_dir
  end

end

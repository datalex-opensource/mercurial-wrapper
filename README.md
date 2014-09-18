mercurial-wrapper
=================

A simple ruby wrapper around mercurial command line tool
This gem relies heavily on childprocess, and it is compatible with MRI and JRuby runtimes.
Below you will find more information on how to install and use this gem. For more information about 
all options available please check the specs or dive into the source code 


# How to install?

```bash
gem install mercurial-wrapper
```

# How to run all the tests

```bash
rake
```

# How to build the gem
```bash
rake build
```

# Examples of usage

## Create repository
```ruby
Dir.mkdir File.join(basedir, REPO_NAME)
repo1 = Mercurial.new(logger).config do |settings|
  settings[:basedir] = basedir
  settings[:repo_name] = REPO_NAME
end
repo1.init
```

## Clone an existing repository
```ruby
repo1 = Mercurial.new(logger).config do |settings|
  settings[:basedir] = basedir
  settings[:repo_name] = REPO_NAME
end

repo1.clone 'https://github.com/datalex-opensource/mercurial-wrapper'
```

## Commit a file

```ruby
repo1.commit 'module2/File1.java', 'Commit Message', '2013-06-01 00:00:00' 
```

## Push changes

```ruby
repo1.push       
```

## Branch a repository (automatically commits)
```ruby
repo1.create_branch 'branch1', 'Commit message'
```

## Remove File
```ruby
repo1.remove 'module1/filename'
```

## Add a file
```ruby
repo1.add 'module1/filename'
```

## Current branch of a given file/module
```ruby
repo1.current_branch 'module1/filename'
```

## Current revision of a given file
```ruby
repo1.current_revision 'module1/filename'
```

## Current previous revision of a given file
```ruby
repo1.previous_revision 'module1/filename'
```

## pull changesets
```ruby
repo1.pull 
```

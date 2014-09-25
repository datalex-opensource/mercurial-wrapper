Gem::Specification.new do |s|
  s.name        = 'mercurial-wrapper'
  s.version     = '0.8.5'
  s.date        = '2014-09-11'
  s.summary     = 'Mercurial command line ruby wrapper'
  s.description = 'A simple wrapper around HG command line tool'
  s.authors     = ['Fabio Neves']
  s.email       = 'infrastructure@datalex.com'
  s.files       = %w(lib/mercurial.rb)
  s.homepage    = 'https://github.com/datalex-opensource/mercurial-wrapper'
  s.add_dependency 'childprocess', '0.5.1'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
end

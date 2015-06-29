# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'process-helper'
  s.version     = '1.0.0'
  s.date        = '2015-06-29'
  s.summary     = 'Utility for managing sub processes.'
  s.description = 'Utility for managing sub processes.'
  s.homepage    = 'https://github.com/bbc/process-helper'
  s.authors     = ['alex hutter', 'andrew wheat', 'tristan hill', 'robert shield']
  s.email       = []
  s.license     = 'Apache 2'

  s.files       = Dir['lib/**/*.rb']
  s.test_files  = Dir['spec/**/*.rb']
  s.require_paths = ['lib']

  s.add_development_dependency 'rubocop', '~> 0'
end

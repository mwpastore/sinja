# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sinja/sequel/version'

Gem::Specification.new do |spec|
  spec.name          = 'sinja-sequel'
  spec.version       = Sinja::Sequel::VERSION
  spec.authors       = ['Mike Pastore']
  spec.email         = ['mike@oobak.org']

  spec.summary       = 'Sequel-specific Helpers and DSL for Sinja'
  spec.homepage      = 'https://github.com/mwpastore/sinja/tree/master/extensions/sequel'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = %w[lib]

  spec.required_ruby_version = '>= 2.3.0'

  spec.add_dependency 'sequel', '~> 4.0'
  spec.add_dependency 'sinja', '>= 1.2.0.pre2', '< 2'

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'minitest', '~> 5.9'
  spec.add_development_dependency 'rake', '~> 12.0'
end

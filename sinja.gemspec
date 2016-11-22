# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sinja/version'

Gem::Specification.new do |spec|
  spec.name          = 'sinja'
  spec.version       = Sinja::VERSION
  spec.authors       = ['Mike Pastore']
  spec.email         = ['mike@oobak.org']

  spec.summary       = 'RESTful, JSON:API-compliant web services in Sinatra'
  spec.homepage      = 'https://github.com/mwpastore/sinja'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = %w[lib]

  spec.required_ruby_version = '>= 2.3.0'

  spec.add_dependency 'json', '>= 1.8.3'
  spec.add_dependency 'jsonapi-serializers', '~> 0.16'
  spec.add_dependency 'sinatra', '>= 2.0.0.beta2', '< 3'
  spec.add_dependency 'sinatra-contrib', '>= 2.0.0.beta2', '< 3'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 11.3'
  spec.add_development_dependency 'rspec', '~> 3.5'
  spec.add_development_dependency 'sequel', '~> 4.38'
  spec.add_development_dependency 'sqlite3', '~> 1.3'
end

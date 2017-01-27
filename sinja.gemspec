# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sinja/version'

Gem::Specification.new do |spec|
  spec.name          = 'sinja'
  spec.version       = Sinja::VERSION
  spec.authors       = ['Mike Pastore']
  spec.email         = ['mike@oobak.org']

  spec.summary       = 'RESTful, {json:api}-compliant web services in Sinatra'
  spec.description   = <<~'EOF'
    Sinja is a Sinatra extension for quickly building RESTful,
    {json:api}-compliant web services, leveraging the excellent
    JSONAPI::Serializers gem for payload serialization. It enhances Sinatra's
    DSL to enable resource-, relationship-, and role-centric API development,
    and it configures Sinatra with the proper settings, MIME-types, filters,
    conditions, and error-handling.

    There are many parsing (deserializing), rendering (serializing), and other
    "JSON API" libraries available for Ruby, but relatively few that attempt to
    correctly implement the entire {json:api} server specification, including
    routing, request header and query parameter checking, and relationship
    side-loading. Sinja lets you focus on the business logic of your
    applications without worrying about the specification, and without pulling
    in a heavy framework like Rails. It's lightweight, ORM-agnostic, and
    Ember.js-friendly!
  EOF
  spec.homepage      = 'http://sinja-rb.org'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = %w[lib]

  spec.required_ruby_version = '>= 2.3.0'

  spec.add_dependency 'activesupport', ">= #{ENV.fetch('rails', '4.2.7.1')}", '< 6'
  spec.add_dependency 'json', '>= 1.8.3', '< 3'
  spec.add_dependency 'jsonapi-serializers', '~> 0.16'
  spec.add_dependency 'mustermann', '>= 1.0.0.beta2', '< 2'
  spec.add_dependency 'sinatra', ">= #{ENV.fetch('sinatra', '1.4.7')}", '< 3'
  spec.add_dependency 'sinatra-contrib', ">= #{ENV.fetch('sinatra', '1.4.7')}", '< 3'

  spec.add_development_dependency 'bundler', '~> 1.11'
  spec.add_development_dependency 'jdbc-sqlite3', '~> 3.8' if defined?(JRUBY_VERSION)
  spec.add_development_dependency 'minitest', '~> 5.9'
  spec.add_development_dependency 'minitest-hooks', '~> 1.4'
  #spec.add_development_dependency 'munson', '~> 0.4' # in Gemfile
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'sequel', '~> 4.41'
  #spec.add_development_dependency 'sinja-sequel', '~> 0.1' # in Gemfile
  spec.add_development_dependency 'sqlite3', '~> 1.3' if !defined?(JRUBY_VERSION)
end

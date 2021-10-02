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

  spec.add_dependency 'activesupport', '>= 4.2.8', '< 6'
  spec.add_dependency 'json', '>= 1.8.3', '< 3'
  spec.add_dependency 'jsonapi-serializers', '>= 0.16.2', '< 2'
  spec.add_dependency 'sinatra', '~> 2.0'
  spec.add_dependency 'sinatra-contrib', '~> 2.0'

  spec.add_development_dependency 'jdbc-sqlite3', '~> 3.8' if defined?(JRUBY_VERSION)
  spec.add_development_dependency 'minitest', '~> 5.9'
  spec.add_development_dependency 'minitest-hooks', '~> 1.4'
  spec.add_development_dependency 'rack-test', '~> 0.7.0'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'sequel', '>= 4.49', '< 6'
  spec.add_development_dependency 'sqlite3', '~> 1.3' if !defined?(JRUBY_VERSION)
end

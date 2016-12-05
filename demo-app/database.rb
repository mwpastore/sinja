# frozen_string_literal: true
require 'logger'
require_relative 'boot'

DB = Sequel.connect ENV.fetch 'DATABASE_URL',
  defined?(JRUBY_VERSION) ? 'jdbc:sqlite::memory:' : 'sqlite:/'

DB.extension :pagination

DB.loggers << Logger.new($stderr) if Sinatra::Base.development?

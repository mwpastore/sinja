# frozen_string_literal: true
require 'logger'
require_relative 'boot'

Sequel.single_threaded = true # WEBrick is single-threaded

DB = Sequel.connect ENV.fetch 'DATABASE_URL',
  defined?(JRUBY_VERSION) ? 'jdbc:sqlite::memory:' : 'sqlite:/'

DB.extension(:freeze_datasets)
DB.extension(:pagination)

DB.loggers << Logger.new($stderr) if Sinatra::Base.development?

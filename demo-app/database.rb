# frozen_string_literal: true
require 'logger'
require_relative 'boot'

DB =
  if defined?(JRUBY_VERSION)
    Sequel.connect 'jdbc:sqlite::memory:'
  else
    Sequel.sqlite
  end

DB.extension :pagination
DB.loggers << Logger.new($stderr) if Sinatra::Base.development?

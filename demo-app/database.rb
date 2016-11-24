# frozen_string_literal: true
require 'logger'
require_relative 'boot'
DB = Sequel.sqlite
DB.loggers << Logger.new($stderr) if Sinatra::Base.development?

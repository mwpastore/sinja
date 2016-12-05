# frozen_string_literal: true
require 'bundler/setup'

Bundler.require :default
Bundler.require Sinatra::Base.environment
Bundler.require :development if Sinatra::Base.test?

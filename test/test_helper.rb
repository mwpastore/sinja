# frozen_string_literal: true
ENV['RACK_ENV'] = ENV['APP_ENV'] = 'test'

require 'bundler/setup'
require 'minitest/autorun'

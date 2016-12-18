# frozen_string_literal: true
require 'sinatra' unless defined?(Sinatra)
require 'sinja'

module Sinatra
  register JSONAPI = Sinja
end

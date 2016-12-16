# frozen_string_literal: true
require 'sinatra'
require 'sinja'

module Sinatra
  register JSONAPI = Sinja
end

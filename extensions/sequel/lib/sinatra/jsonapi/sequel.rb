# frozen_string_literal: true
require 'sinja/sequel'
require 'sinatra/jsonapi'

module Sinatra
  register JSONAPI::Sequel
end

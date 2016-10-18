# frozen_string_literal: true
module Sinatra
  module JSONAPI
    MIME_TYPE = 'application/vnd.api+json'

    SinjaError = Class.new(StandardError)
    ActionHelperError = Class.new(SinjaError)
  end
end

Sinja = Sinatra::JSONAPI

require 'sinatra/jsonapi'

# frozen_string_literal: true
require_relative '../test_helper'

require 'json'
require 'rack/test'
require 'sinja'

# It's somewhat challenging to isolate Sinatra helpers for testing. We'll
# create a "shell" application with some custom routes to get at them.

class MyAppBase < Sinatra::Base
  register Sinja

  before do
    content_type :json
  end
end

class MyAppTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    header 'Accept', Sinja::MIME_TYPE
    header 'Content-Type', Sinja::MIME_TYPE
  end

  def json
    @json ||= JSON.parse(last_response.body, :symbolize_names=>true)
  end
end

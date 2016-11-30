# frozen_string_literal: true
require_relative '../test_helper'

# It's somewhat challenging to isolate Sinatra helpers for testing. We'll
# create a "shell" application with some custom routes to get at them.

class MyAppBase < Sinatra::Base
  register Sinja

  before do
    content_type :json
  end
end

# frozen_string_literal: true
require_relative 'test_helper'

class MyWeirdApp < Sinatra::Base
  register Sinja

  get '/' do
    not_found
  end
end

class MyWeirdAppTest < Minitest::Test
  include MyAppTest
  include Rack::Test::Methods

  def app
    MyWeirdApp.new
  end

  def test_not_found
    get '/'
    assert_error 404
  end
end
